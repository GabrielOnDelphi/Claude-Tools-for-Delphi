---
name: light-task-DerailmentCheck
description: "Pause mid-task and verify your own conclusions before continuing: classify every load-bearing conclusion VERIFIED / INFERRED / ASSUMED with evidence, actively attack the unverified ones, and find the earliest wrong turn if one exists. Not Delphi-specific — usable in any long or drifting task, in any language. Use when the user says \"derailment check\", \"are you on track\", \"checkpoint yourself\", \"pause and check your conclusions\", \"/light-task-DerailmentCheck\", or after any long autonomous stretch. ALSO fire this on yourself, unprompted, whenever: the user says \"nope\"/\"no\"/\"wrong\"/\"stop\" or otherwise corrects you; a fix didn't change the symptom; two fix attempts on the same problem both failed; you're editing a file your own analysis never mentioned; you're explaining away contradicting evidence instead of checking it; or you're about to act without ever having reproduced the problem."
---

# /light-task-DerailmentCheck — pause and verify conclusions

A subagent's report, a plausible-looking fix, and a confident root cause all share the same failure mode: they *feel* verified without being verified. This protocol forces the distinction before more work gets built on top of an unchecked assumption. It costs a few minutes; a wrong conclusion discovered three steps later costs the whole afternoon.

Run the **Full version** whenever this skill is invoked directly. Use the **Short version** only as a quick inline nudge when you are checkpointing yourself mid-task without stopping to run the full audit as a separate step.

## Full version

STOP. Do not write, edit, or run anything until this audit is done.

1. **Original goal.** Re-read the first message of this task. One sentence: what was asked for? Is the CURRENT activity still serving it, or did the scope drift?
2. **Load-bearing conclusions.** List every conclusion drawn so far that the current plan depends on. One line each.
3. **Classify each:** VERIFIED (direct proof seen — cite file:line / command output / doc URL), INFERRED (plausible deduction, never directly checked), ASSUMED (no evidence, it just felt right). A subagent's report counts as INFERRED until independently re-checked.
4. **Attack.** For each INFERRED / ASSUMED item, actively try to DISPROVE it — read the real code, run the check, search the docs. Argue against it like a hostile reviewer. Promote to VERIFIED or mark it WRONG. Nothing the next step depends on may stay unverified.
5. **Earliest wrong turn.** Find the FIRST item that is now WRONG. Everything built on top of it is suspect — name the work that must be discarded.
6. **Verdict:**
   - ON TRACK — every load-bearing conclusion is VERIFIED. Continue.
   - DERAILED — state the wrong turn in one sentence, go back to the last verified point, and show the corrected plan before touching anything else.

Do not defend prior work. A wrong conclusion found now is cheap; a wrong conclusion kept is expensive.

## Tripwires — when to fire this on yourself

- The user says "nope" / "no" / "wrong" / "stop" or corrects you — the model of the task was just contradicted.
- A fix did not change the symptom (the causal model is wrong — do not stack another fix on top).
- Two failed fix attempts on the same symptom.
- You are editing a file your own root-cause analysis never mentioned.
- You are explaining away contradicting evidence ("probably flaky", "must be caching") without verifying.
- You are proceeding without a reproduction, "based on reading the code" alone.

## Short version (quick mid-task nudge)

Checkpoint: stop. List the conclusions the current plan rests on, mark each VERIFIED / INFERRED / ASSUMED with the evidence, try to disprove the unverified ones, then state: ON TRACK or DERAILED — and where the wrong turn was.

## Relationship to other skills

The `/light-bug` family (the general skill, the `light-bug-MadShi` agent, and `light-bug-Android`) invokes this before every fix — a bug "fix" built on an unverified root cause is worse than no fix, because it burns a cycle and adds noise to the diff. Any other skill or task may invoke it too; it is deliberately generic.
