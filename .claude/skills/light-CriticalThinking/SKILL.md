---
name: light-CriticalThinking
description: Counter-analyze the review findings already in this conversation, verify every surviving claim against the actual code and docs, drop false positives, then fix ALL the issues that remain — not just the easy ones. 
Use after a review/audit/listing has produced findings and you want them vetted and resolved end-to-end. 
Invoke when the user types `/light-CriticalThinking`, says "counter-analyze these findings", "vet and fix", or "verify then fix all of these".
---

# Delphi Post Review — Critical

Take the review findings already in this conversation and run them through a counter-analysis pass before fixing anything. Some of your suppositions WILL be false — this happens every review. Treat the prior findings as a hypothesis, not a verdict.
This is a general skill, not necesarly only for Delphi code. 

**Precondition:** if there are no review findings, list, or audit results in this conversation to work from, stop and tell the user: *"No prior findings found in this session — there is nothing to counter-analyze."* Do not invent findings to vet.

## Step 1 — Counter-analysis

For each finding in the prior review, argue against it:

- Is the original analysis exaggerating severity, or describing a problem that does not actually occur in practice?
- Did the reviewer misread the code — wrong scope, wrong type, wrong call site?
- Is there an upstream guarantee (an `Assert`, a `try/finally`, an ownership rule, a framework invariant) that already prevents the claimed failure?
- Is the "issue" actually an intentional pattern in this codebase? Check against any `patterns_*.md` files under `C:/Users/trei/.claude/agent-memory/light-review/` if the directory exists.
- For findings produced by a sub-agent: always re-check its conclusions. Sub-agents hallucinate. Do not trust a finding just because an agent wrote it down.

Mark each finding as **likely-real**, **likely-false**, or **needs-verification**.

## Step 2 — Verify every surviving claim

For each finding that is **likely-real** or **needs-verification**, confirm it against the actual evidence:

- **Read the actual file** and the surrounding code — not just the snippet quoted in the finding. The snippet may be out of context.
- **Read the declaration** of every named type, procedure, property, or field referenced by the finding.
- **Find at least one caller** of the affected procedure to confirm the claimed failure path is reachable.
- **For RTL/FMX/VCL APIs:** check `c:\Delphi\Delphi 13\source\` or the Embarcadero DocWiki. Do not guess what an RTL routine does.
- **For 3rd-party code:** check the library source or its docs.
- **For DFM/FMX bindings:** open the `.dfm` / `.fmx` and confirm the published field/event the finding mentions.
- **If unsure after reading the code:** search the Internet — Embarcadero docs, Stack Overflow, the library's GitHub. Do not assume.

Drop any finding you cannot verify. **Say so explicitly** — list each dropped finding and one line on why it was dropped (false positive, intentional pattern, upstream guarantee, etc.). Silent drops are a bug.

## Step 3 — Revise

Produce a clean, deduplicated list of the findings that survived verification. For each surviving item:

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

## Step 5 — Hand off to `light-code-PostEdit`

If this is a Delphi code project:
This skill verifies findings and applies fixes. It does **not** verify the fixes themselves — that is what `light-code-PostEdit` is for, and it already handles revert-on-regression, integration checks, and the final compile/test step.

Invoke the **`light-code-PostEdit`** skill via the Skill tool. It will pick up the edits you just made in this session and run them through its own verification pipeline.


## Rules

- **Counter-analyze before verifying, verify before fixing.** Do not start applying fixes during Step 1. Findings that survive only the counter-analysis but were never verified against the code are still just suppositions.
- **You do not trust sub-agent output.** Re-check it the same way you re-check any other finding.
- **No silent drops.** Every dropped finding gets one line of justification.
- **No cherry-picking.** All surviving findings get fixed, not just the easy ones.
- **Hand off, don't duplicate.** The final verify + compile + beep is `light-code-PostEdit`'s job, not this skill's.
