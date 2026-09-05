---
name: light-review-Full
description: |
  Full three-stage Delphi code review pipeline: find correctness bugs, counter-analyze and apply the fixes that survive, verify them and compile. Say "review this Delphi code", "code review FormFoo.pas", "deep review the Lib folder", "review the code I just changed", "check this unit for bugs", "is this code correct". With no file named it reviews whatever `git status` shows as uncommitted, so it works on a bare "review my changes".
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

- **`ReviewHistory.md`** (in the project root, next to its `CLAUDE.md`) — the full log, newest
  block first. It is **not** auto-loaded into context, so it can hold real history.
- **`CLAUDE.md → ## Last review`** — a single pointer line carrying the latest verdict and date,
  so the "do we need another review?" answer is visible in the always-loaded file without opening
  anything. Overwritten every run; all detail belongs in `ReviewHistory.md`.

**Do not write either file by hand — run the bundled script.** It prepends the block, enforces the
size cap by dropping only whole `## <date>` blocks from the bottom while never falling below the 5
most recent, and overwrites the `## Last review` pointer, creating `ReviewHistory.md` or the pointer
section when they do not exist yet:

```
python "c:\Users\<you>\.claude\skills\light-review-Full\scripts\review-log.py" add "<project root>" ^
  --date 2026-06-10 --verdict "Ready with notes" --model "Opus 5" ^
  --scope "3 files - BxAIEngine.pas, BxAIMaskGen.pas, BxAIProviderComfyUI.pas" ^
  --result "2 issues fixed; compiles clean." ^
  --unresolved "1 - ViewportResolver may deadlock if the queue is drained mid-await."
```

`--verdict` accepts only `Ready`, `Ready with notes` or `Not ready`, so a verdict outside the scale
below fails loudly instead of quietly entering the log. Omit `--unresolved` and it writes `none`.
The script prints the block count, the resulting size, how many old blocks it dropped, and whether
the pointer line was added or overwritten — put those numbers in the Step 7 summary. A project with
no `CLAUDE.md` still gets its `ReviewHistory.md`; the script says `no CLAUDE.md - pointer line
skipped` and that goes in the summary too.

**Why a script rather than an edit.** Trimming to a byte cap by hand is where this step goes wrong,
and both ways it goes wrong leave a file that still looks right: cutting a block in half at the cap,
and trimming past the 5-block floor because the file is still over it. `scripts\test-review-log.py`
checks exactly those two, plus that a hand-written header above the first block survives. Run it
after any change to the script:

```
python "c:\Users\<you>\.claude\skills\light-review-Full\scripts\test-review-log.py"
```

To see the current state of a project's log without writing anything:
`python "…\review-log.py" check "<project root>"`.

**What to pass to each switch.** The script owns the shape of the block; these rules own its content.

- `--date` — absolute, never "today" or "last week".
- `--model` — the model that ran the review, read live from this session, never guessed. Reviews from
  different models are not equally trustworthy, and a year from now nobody can tell which one produced
  a block from the text alone.
- `--scope` — how many `.pas` files, and which ones if there are few, or the folder name if there are many.
- `--result` — the confirmed-and-fixed count, meaning the fixes stage 3 left in place, plus stage 3's
  compile or test outcome.
- `--unresolved` — the count, then one line each for every "Possible issue" or skipped finding the
  agents left for a human: the same items the Step 7 summary lists under "Needs your attention".
  Omit the switch when there are none and the script writes `none`. This line is what drives the verdict.
- `--verdict` — one of three, so entries stay comparable across years:
  - **Ready** — stage 3 compiled or passed clean, **and** there are zero unresolved items.
  - **Ready with notes** — compiled or passed clean, but at least one low-risk unresolved item that
    does not block shipping. Name those items on `--unresolved`.
  - **Not ready** — the build or the tests failed, **or** an unresolved item is serious enough to block
    a release: a likely crash, data loss, a security hole, a correctness hole.

  Base it on stage 3's real compile or test result and on the unresolved list, never on an optimistic
  reading. Torn between two levels? Take the more cautious one — an inflated verdict is the one thing
  in this log that actively misleads a later session.

## Optional - check it in the running app

Stage 3 ends at a successful compile. That is not the same as the program behaving correctly.

If the project has the **Autopilot for Delphi** bridge linked in, drive the running program and check the behaviour for real: call `list_tree` once to learn the control paths, then `click`, `set_text`, `get_text` or `read_property`. Prefer `get_text` over a screenshot - it is faster and costs no image tokens.

If a tool answers `-32099 target_not_running`, the program is closed or was built without the bridge. Say so and stop; do not retry, and do not go and wire the bridge in unless asked. What it is and how to link it: https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/

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
- **Shared memory checklist.** The `light-review-step1` and `light-review-step3` agents apply the Delphi memory-safety & exception checklist at `c:/Users/<you>/.claude/skills/light-ref-Memory/SKILL.md` — that file is its single source of truth, not copied here or inside the agents. Edit that one file to change what the pipeline checks for memory/exception safety.
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

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
