---
name: light-review-Critical
effort: max
description: Counter-analyze review findings already in this conversation, verify each surviving claim against the code and the documentation, drop the false positives, then fix every one that remains — not just the easy ones. Use whenever a review, audit, listing or subagent report has produced findings and the next step is deciding which of them are real — "counter-analyze these findings", "vet and fix", "verify then fix all of these", "are these findings real", "critical review of that list", "which of these are false positives".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-review-Critical — Delphi Post Review

Take the review findings already in this conversation and run them through a counter-analysis pass before fixing anything. Some of your suppositions WILL be false — this happens every review. Treat the prior findings as a hypothesis, not a verdict.
This is a general skill, not necessarily only for Delphi code. 

**Precondition:** if there are no review findings, list, or audit results in this conversation to work from, stop and tell the user: *"No prior findings found in this session — there is nothing to counter-analyze."* Do not invent findings to vet.

## Step 0 — Say where the findings came from

Before arguing about anything, write one line per finding — or one line for the whole batch if they share an origin — naming who produced it:

- **This same conversation**, by you, earlier in this session.
- **A sub-agent** you launched from this session.
- **An earlier, separate run** that no longer exists — a report on disk, a file the user pasted in, another console's output.

This is not bookkeeping. It says how much the batch is worth before you spend an hour on it. A re-check inside the same session that produced the findings is the weakest of the four ways this has been measured: it caught 21.7% of planted errors against 28.6% for a brand new console reading the document cold, and it raised the wrong complaints from 3.1 to 4.4 per document (Song, arXiv:2603.12123).

So when the findings were produced in THIS conversation, say this to the user in one line, then carry on with the run:

*"These findings were made earlier in this same session, which is the weakest window for checking them. A fresh console reading them cold does better. Say the word and I stop; otherwise I continue here."*

Do not stall waiting for an answer — starting over costs him a paste and a new window, and that is his call to make, not a reason to leave the work sitting. If he does move it to a fresh console, nothing downstream breaks: the fixes get applied in that new console, and `light-review-PostEdit` at Step 5 verifies the edits of whichever session applied them.

## Step 1 — Counter-analysis

For each finding in the prior review, argue against it:

- Is the original analysis exaggerating severity, or describing a problem that does not actually occur in practice?
- Did the reviewer misread the code — wrong scope, wrong type, wrong call site?
- Is there an upstream guarantee (an `Assert`, a `try/finally`, an ownership rule, a framework invariant) that already prevents the claimed failure?
- Is the "issue" actually an intentional pattern in this codebase? Check against any `patterns_*.md` files under `c:/Users/<you>/.claude/agent-memory/light-review/` if the directory exists.
- For findings produced by a sub-agent: always re-check its conclusions. Sub-agents hallucinate. Do not trust a finding just because an agent wrote it down.

**Do not label anything yet.** Step 1 only collects the argument against each finding. The verdict comes in Step 2, once the file is open — a label written before the read is an opinion about a snippet, and Step 4 goes on to fix everything the label kept.

## Step 2 — Verify every claim, then give it one verdict

Every finding goes through this step, including the ones your Step 1 argument seems to have killed. Confirm each against the actual evidence:

- **Read the actual file** and the surrounding code — not just the snippet quoted in the finding. The snippet may be out of context.
- **Read the declaration** of every named type, procedure, property, or field referenced by the finding.
- **Find at least one caller** of the affected procedure to confirm the claimed failure path is reachable.
- **For RTL/FMX/VCL APIs:** check `c:\Delphi\Delphi 13\source\` or the Embarcadero DocWiki. Do not guess what an RTL routine does.
- **For 3rd-party code:** check the library source or its docs.
- **For DFM/FMX bindings:** open the `.dfm` / `.fmx` and confirm the published field/event the finding mentions.
- **If unsure after reading the code:** search the Internet — Embarcadero docs, Stack Overflow, the library's GitHub. Do not assume.

Then give every finding exactly one verdict, in this shape:

```
VERDICT: REAL | NOT REAL | CANNOT TELL
PROOF:   <File.pas:LINE> then that line of code, quoted verbatim
WHY:     one sentence
```

`REAL` needs a quotable line. `NOT REAL` needs the line that disproves it — a guard, a clamp, an early exit, a declaration the finding assumed wrongly. `CANNOT TELL` is a real verdict, not a failure to answer; use it rather than inventing one of the other two. No percentages, no confidence scores, and never the word "likely": a wrong line number is caught in one keystroke, a wrong confidence score is not.

Everything marked `NOT REAL` or `CANNOT TELL` is dropped. **Say so explicitly** — list each dropped finding with its verdict block and one line on why it went (false positive, intentional pattern, upstream guarantee, nothing provable either way). Silent drops are a bug.

## Step 3 — Revise

Produce a clean, deduplicated list of the findings that survived verification — everything marked `REAL`. For each surviving item:

- **file:line** of the issue
- **Severity** — critical / major / minor
- **The problem** — one or two sentences
- **The verified evidence** — quoted code and what you read to confirm it
- **The fix** — what you intend to change

If two findings collapse into the same root cause, merge them.

## Step 4 — Fix everything that survived

Fix **ALL** the surviving issues. No cherry-picking. The "fix only small issues" reflex is exactly what this skill exists to override.

Apply the fixes in order: critical → major → minor. For each fix:

- Make the edit.
- For non-trivial fixes, briefly verify the change still compiles in your head — does it reference symbols that exist, match the surrounding style, preserve the public surface where it should?
- If a fix turns out to require a design decision only the user can make (e.g. "should this `Free` go in the caller or the callee?"), flag it explicitly and ask. Do **not** silently skip it.

**Do not stop early.** If you find yourself thinking "the rest are minor, the user can do them later" — that is the failure mode this skill prevents. Fix them.

## Step 5 — Hand off to `light-review-PostEdit`

If this is a Delphi code project:
This skill verifies findings and applies fixes. It does **not** verify the fixes themselves — that is what `light-review-PostEdit` is for, and it already handles revert-on-regression, integration checks, and the final compile/test step.

Invoke the **`light-review-PostEdit`** skill via the Skill tool. It will pick up the edits you just made in this session and run them through its own verification pipeline.


## Rules

- **Say where the findings came from before you argue about them.** Findings made earlier in this same conversation are the weak case — warn the user in one line, then continue.
- **Counter-analyze before verifying, verify before fixing.** Do not start applying fixes during Step 1. Findings that survive only the counter-analysis but were never verified against the code are still just suppositions.
- **You do not trust sub-agent output.** Re-check it the same way you re-check any other finding.
- **No silent drops.** Every dropped finding gets one line of justification.
- **No cherry-picking.** All surviving findings get fixed, not just the easy ones.
- **Hand off, don't duplicate.** The final verify + compile is `light-review-PostEdit`'s job, not this skill's.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
