# TEMPLATE — Derailment check (pause and verify conclusions)

Paste this mid-task when Claude drifts off course, or after any long autonomous stretch.

**Canonical version:** the `light-task-DerailmentCheck` skill (`C:\Users\trei\.claude\skills\light-task-DerailmentCheck\SKILL.md`) — invoke it with `/light-task-DerailmentCheck` whenever skill access is available; it is also referenced by the /light-bug skill family. Keep this file only for pasting into a context that can't invoke a skill. If the protocol changes, edit the skill and copy the text back here — not the other way round.

## Full version

STOP. Do not write, edit, or run anything until this audit is done.

1. **Original goal.** Re-read my first message of this task. One sentence: what did I ask for? Is your CURRENT activity still serving it, or did the scope drift?
2. **Load-bearing conclusions.** List every conclusion you have drawn so far that your current plan depends on. One line each.
3. **Classify each:** VERIFIED (you saw direct proof — cite file:line / command output / doc URL), INFERRED (plausible deduction, never directly checked), ASSUMED (no evidence, it just felt right). A subagent's report counts as INFERRED until you re-checked it yourself.
4. **Attack.** For each INFERRED / ASSUMED item, actively try to DISPROVE it — read the real code, run the check, search the docs. Argue against yourself like a hostile reviewer. Promote to VERIFIED or mark it WRONG. Nothing your next step depends on may stay unverified.
5. **Earliest wrong turn.** Find the FIRST item that is now WRONG. Everything built on top of it is suspect — name the work that must be discarded.
6. **Verdict:**
   - ON TRACK — every load-bearing conclusion is VERIFIED. Continue.
   - DERAILED — state the wrong turn in one sentence, go back to the last verified point, and show me the corrected plan before touching anything.

Do not defend your prior work. A wrong conclusion found now is cheap; a wrong conclusion kept is expensive.

## Tripwires — when Claude must fire this on itself (for the planned light-task-DerailmentCheck skill)

- The user says "nope" / "no" / "wrong" / "stop" or corrects you — your model of the task was just contradicted.
- Your fix did not change the symptom (your causal model is wrong — do not stack another fix on top).
- Two failed fix attempts on the same symptom.
- You are editing a file that your own root-cause analysis never mentioned.
- You are explaining away contradicting evidence ("probably flaky", "must be caching") without verifying.
- You are proceeding without a reproduction, "based on reading the code" alone.

## Short version (quick mid-task nudge)

Checkpoint: stop. List the conclusions your current plan rests on, mark each VERIFIED / INFERRED / ASSUMED with the evidence, try to disprove the unverified ones, then tell me: ON TRACK or DERAILED — and where the wrong turn was.
