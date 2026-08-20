---
name: light-review-Full
description: Full three-stage Delphi code review pipeline: find correctness bugs, counter-analyze + apply surviving fixes, verify + compile. Say "review this Delphi code", "code review FormFoo.pas", "deep review the Lib folder".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# Delphi Review — Pipeline Orchestrator

This skill runs a three-stage review pipeline. **You (the main thread) are the orchestrator.**
You do NOT review code yourself. You launch three sub-agents in strict sequence, thread each
agent's output into the next agent's prompt, then sync the project docs and print one
consolidated summary.

The three review stages are:

1. **`light-review-step1`** — finds correctness bugs, reports them, applies the fixes it is confident about.
2. **`light-review-step2`** — counter-analyzes stage-1's findings, drops false positives, applies the fixes that survive.
3. **`light-review-step3`** — verifies stage-2's fixes hold up, reverts the bad ones, compiles the project.

After the three stages, two closing steps keep the project honest. Step 5 keeps the docs
honest: a fix that changes observable behavior can leave `CLAUDE.md` (or another MD)
describing the old code, so it runs the `light-md-DriftUpdate` skill to catch that drift — it
edits an MD file **only** when a doc claim genuinely contradicts the changed code; no drift
means no edit. Step 6 then records a dated **review-log entry** — when the review ran, what
survived, and a ship-readiness verdict — so that across sessions you can see at a glance
whether the code still needs another pass.

Each stage runs in its own isolated sub-agent context. A sub-agent cannot see the previous
stage's session — so **you must pass each stage's report forward in the next stage's prompt**.
That is the whole reason this skill exists: without it, the stages have nothing to chain through.

## Step 1 — Resolve the input

The user may pass a single `.pas` file, a folder, or several files. Build the **review set** —
the list of `.pas` files to review:

- **One or more explicit file paths** → use them as-is.
- **A folder** → Glob `<folder>/**/*.pas` for the file list. If the result is large (more than
  ~25 files), tell the user the count and ask whether to review all or narrow the scope.
- **No argument** → review the `.pas` files with **uncommitted** changes. Run
  `git status --porcelain` and keep the `.pas` files it lists (modified, added, or renamed).
  This is what "the code I just changed" means in practice and needs no branch-name guessing.
  If that list is empty, tell the user there is nothing to review and stop — do NOT fall back
  to reviewing the whole repository.

`.dfm` / `.fmx` files are never in the review set on their own — they are read by the agents as
needed to check bindings. If the user points at a `.dfm`, review its paired `.pas` instead.

Print the resolved review set as a short list before launching anything, so the user can see
the scope.

## Step 2 — Stage 1: launch `light-review-step1`

Call the **Agent** tool with `subagent_type: "light-review-step1"`.
Pass it the **full review set at once** — every file in one prompt. This is deliberate:
cross-file findings (a caller in file A misusing a procedure in file B) only work when the
agent can see all the files together.

The agent returns a findings report and a list of fixes it applied. **Capture its entire
final message verbatim** — you will need it for stage 2.

If the agent reports it could not read a file, or found nothing reviewable, relay that and
continue — an empty findings report is still a valid stage-1 result.

## Step 3 — Stage 2: launch `light-review-step2`

Call the **Agent** tool with `subagent_type: "light-review-step2"`. Its prompt MUST contain:

1. The **full review set** (the same file paths from Step 1).
2. The **complete stage-1 report** you captured — paste it in under a clear heading like
   `--- STAGE 1 REPORT ---`. This is the agent's only source for what stage 1 found and fixed;
   it has no other access to it.
3. One explicit line: **"The files on disk already contain stage 1's fixes."** Stage 2 reads
   the files to verify findings — without this line it may read an already-fixed line, not see
   the original bug, and wrongly mark a real finding a false positive.

The agent counter-analyzes every stage-1 finding, drops false positives, verifies the rest,
and applies the fixes that survive. It returns a revised report (Confirmed / Rejected /
Possible-issues) and the list of edits it applied or that stage 1 applied.

**Capture its entire final message verbatim** for stage 3.

## Step 4 — Stage 3: launch `light-review-step3`

Call the **Agent** tool with `subagent_type: "light-review-step3"`. Its prompt MUST contain:

1. The **full review set**.
2. The **complete stage-2 report** you captured — paste it under `--- STAGE 2 REPORT ---`.
   This is the agent's only record of which edits were applied; it verifies exactly those.
   The presence of this report is what puts stage 3 in pipeline mode (Mode A) — so it will
   verify the listed edits.

The agent verifies each fix, reverts any that do not hold up, then compiles the project (or
runs the test suite for a large change). It returns a report of what held, what was adjusted,
what was reverted, and the compile/test result.

**Capture its final message.**

## Step 5 — Keep the docs in sync (`light-md-DriftUpdate`)

The review may have changed how the code behaves. Project MD docs — `CLAUDE.md` above all —
can now describe code that no longer exists. This step fixes that drift.

**Skip this step entirely** if, after stage 3, **no edit survived** — i.e. stage 2 applied
nothing, or stage 3 reverted every fix. With no code change there is no drift; do not run the
skill, just move to Step 6.

Otherwise, invoke the **`light-md-DriftUpdate`** skill (via the **Skill** tool). In the same
message, tell it the scope so it does not re-scan every claim in every MD:

- The **list of `.pas` files that ended up changed** — the review-set files that still hold a
  surviving fix per stage 3's report (not the ones stage 3 reverted).
- One line: **"Check the project MD docs only for drift against these changed files. Edit an
  MD file only where a doc claim genuinely contradicts the changed code — no speculative
  rewrites, no style edits."**

`light-md-DriftUpdate` already verifies every claim against the code and edits only on real drift,
so this stays conservative by construction: a review that changed nothing user-visible will
produce zero MD edits. Capture what it reports (which MD files it touched, or "no drift").

If the changed code lives in a project with no `CLAUDE.md` / no MD docs, the skill will find
nothing to do — that is fine, report "no docs to update" and continue.

## Step 6 — Record the review-log entry

Write down that this review happened, so a future session can decide whether another pass is
needed without re-reading the whole codebase. **Run this step on every completed pipeline run,
including a clean one** — "reviewed, nothing found, ready to ship" is exactly the signal that
says *no further review needed*, and is more useful in the log than a noisy entry.

**Where to write it.** Two files in the reviewed code's project (the one whose `CLAUDE.md`
governs the review-set files — **not** the global `CLAUDE.md`). The full record lives in a
dedicated file; the always-loaded `CLAUDE.md` carries only a one-line pointer to it:

- **`ReviewHistory.md`** (in the project root, next to its `CLAUDE.md`) — the full log. This
  file is **not** auto-loaded into context, so it can hold real history: **prepend** a new dated
  block at the top (newest first), keeping past blocks in full. **Create the file if it does not
  exist** — start it with an `# Review history` heading, then the first block.
  **Size cap — trim oldest when it grows too large.** After prepending, if the file exceeds
  **~25 KB**, delete whole blocks from the **bottom** (the oldest reviews) until it is back under
  the cap. Drop entire `## <date>` blocks, never half a block. Keep at least the **5 most recent**
  blocks regardless — if even those exceed 25 KB, leave them; history integrity wins over the
  cap. Trimming loses only the oldest detail, which is the least useful — the recent verdict
  trend is what decides "do we need another review?".
- **`CLAUDE.md → ## Last review`** — a single pointer line, **overwritten** every run, carrying
  the latest verdict + date so the "do we need another review?" answer is visible in the
  always-loaded file without opening anything:
  `YYYY-MM-DD — **<verdict>** — full history in [ReviewHistory.md](ReviewHistory.md)`.
  Keep it to that one line — all detail belongs in `ReviewHistory.md`, never here.

If the project has no `CLAUDE.md` at all, still write `ReviewHistory.md`; skip the pointer line
(there is no file to put it in) and say so in the summary.

**What each `ReviewHistory.md` block contains** (keep it short — a few lines, not a report):

- **Heading** — `## YYYY-MM-DD — <verdict>`: the date (absolute, never "today" / "last week")
  and the ship-readiness verdict on one line. This same date + verdict is what the `CLAUDE.md`
  pointer line copies.
- **Scope** — how many `.pas` files and, if few, which ones (or the folder name).
- **Result** — confirmed-and-fixed count (the fixes stage 3 left in place), and the
  compile/test outcome from stage 3.
- **Unresolved** — the count and a one-line-each list of every "Possible issue" / skipped
  finding the agents flagged for a human (the "Needs your attention" items from the summary).
  Write **"none"** when there are none. This line is what drives the ship-readiness call.
- **Ship-readiness** — one verdict from this fixed scale, so entries stay comparable:
  - **Ready** — stage 3 compiled/passed clean **and** zero unresolved items.
  - **Ready with notes** — compiled/passed clean, but ≥1 low-risk unresolved item that does
    not block shipping (name them on the Unresolved line).
  - **Not ready** — the build/tests failed, **or** an unresolved item is serious enough to
    block a release (a likely crash, data loss, security, or correctness hole).

  Base the verdict on stage 3's actual compile/test result and the unresolved list — do not
  inflate it. If unsure between two levels, pick the more cautious one.

Example `ReviewHistory.md` (full log, newest block on top — every block kept in full):

```markdown
# Review history

## 2026-06-10 — Ready with notes
- **Scope:** 3 files — BxAIEngine.pas, BxAIMaskGen.pas, BxAIProviderComfyUI.pas
- **Result:** 2 issues fixed; compiles clean.
- **Unresolved:** 1 — ViewportResolver may deadlock if the queue is drained mid-await (needs a human call).

## 2026-05-28 — Ready
- **Scope:** playlist + monitor units.
- **Result:** nothing found; compiles clean.
- **Unresolved:** none.
```

And the matching one-line pointer in that project's `CLAUDE.md` (overwritten each run):

```markdown
## Last review
2026-06-10 — **Ready with notes** — full history in [ReviewHistory.md](ReviewHistory.md)
```

## Step 7 — Consolidated summary

Print one short consolidated summary for the user (the agents' full reports are already in the
transcript above — do not re-paste them). Cover:

- **Review set** — how many files, which ones.
- **Found → confirmed → fixed** — stage 1 found N, stage 2 confirmed M and rejected N−M as
  false positives, stage 3 reverted K bad fixes. Give the real numbers.
- **Compile/test result** — pass or fail, from stage 3.
- **Docs** — from Step 5: which MD files were updated for drift, or "docs already in sync" /
  "skipped — no surviving code change".
- **Review log** — from Step 6: the ship-readiness verdict (Ready / Ready with notes / Not
  ready), recorded in `ReviewHistory.md` with the pointer line refreshed in `CLAUDE.md`. Note
  here if the size cap trimmed old blocks.
- **Needs your attention** — any "Possible issue" or skipped finding the agents flagged for a
  human decision. List these explicitly; they are the only things the user must act on.

## Rules

- **Strict sequence.** Stages 1 → 2 → 3, never in parallel. Stage 2 needs stage 1's findings;
  stage 3 needs stage 2's edits. Launching them together produces garbage.
- **Thread the output.** Each stage's report goes into the next stage's prompt verbatim. If you
  skip this, the next agent has no input and will either stop or hallucinate findings.
- **One review set, passed whole.** All files go to every stage at once — do not loop the
  pipeline per file. Cross-file analysis depends on the agent seeing the whole set.
- **You do not review code.** Resolving input, launching agents, threading reports, and
  summarizing is your entire job. The agents do the review.
- **Shared memory checklist.** The `light-review-step1` and `light-review-step3` agents apply the Delphi memory-safety & exception checklist at `~/.claude/skills/light-ref-Memory/SKILL.md` — that file is its single source of truth, not copied here or inside the agents. Edit that one file to change what the pipeline checks for memory/exception safety.
- **If a stage fails** (agent errors out, returns nothing usable), stop the pipeline, report
  which stage failed and why, and do not fabricate the missing stage's output.
- **Docs come after the code is verified, not before.** Step 5 runs only after stage 3 has
  confirmed which fixes survive — so the docs are synced against the *verified* code, never
  against a fix stage 3 is about to revert. Skip Step 5 when no fix survived.
- **Always log the review, even a clean one.** Step 6 runs on every completed pipeline run.
  A "nothing found, ready to ship" entry is the whole point — it tells a later session the
  code does not need another pass. The verdict reflects stage 3's real compile/test result and
  the unresolved list, never an optimistic guess; when torn between two levels, pick the lower.
- **The review log goes in the project, not the global CLAUDE.md.** It belongs to the project
  that owns the reviewed files. The full history is a dedicated **`ReviewHistory.md`** in that
  project's root (prepend a full block per run; create it if absent); the project's
  `CLAUDE.md → ## Last review` holds only a **one-line pointer** carrying the latest date +
  verdict (overwritten each run) — `ReviewHistory.md` is not context-loaded, so it grows there,
  not in `CLAUDE.md`. Never put the log in the global `CLAUDE.md`.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
