---
name: light-bug
description: "Diagnose and fix a Delphi bug end-to-end, however it arrived: a Thunderbird crash report (.mad), a pasted exception/stack trace, or a symptom described in plain words. Routes internally — a .mad or 'crash report' goes to the light-bug-MadShi pipeline, an Android-only symptom hands off to /light-bug-Android, everything else runs here: intake, reproduce (a failing DUnitX test preferred), localize, a MANDATORY derailment check before any fix, fix, then verify and compile (never releases). Use whenever the user reports a bug, crash, or unexpected behavior in a Delphi project — says \"/light-bug\", \"/light-bug bionix\", \"I have a crash in program X\", \"the app does Y instead of Z\", \"this doesn't work\", pastes an exception or stack trace, forwards a bug-report email, or describes an app crashing/hanging/misbehaving — even without typing a command."
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-bug — Delphi bug diagnosis and fix (general entry point)

One skill for "there's a bug", regardless of how it arrived — a Thunderbird crash report, a pasted stack trace, or three sentences describing wrong behavior. Intake -> reproduce -> localize -> derailment check -> fix -> verify, every time. The derailment check is what stops a plausible-looking but wrong root cause from turning into a wasted afternoon.

**You (the main thread) run this directly.** Unlike the crash-report pipeline there is no workhorse agent: the derailment check needs to happen where the conclusions were actually drawn. A subagent's report only counts as `INFERRED` until re-checked, so relaying the reasoning secondhand would defeat the point of checking it at all.

## Step 0 — Route

Work through these in order — the first one that matches decides the path. Do not skip ahead to "general path" just because a message isn't obviously a crash report; case 3 below exists precisely to catch the messages that are too thin to act on either way.

1. **Unambiguous crash-report evidence** — a `.mad` file path, or wording like "crash report" / ".mad" / "bug report email" / "madExcept". This is the crash-report pipeline: read `C:\Users\trei\.claude\skills\light-bug-MadShi\SKILL.md` and follow it exactly (it resolves the product, lists/extracts the `.mad`, and launches its own agent). That skill is self-contained end to end — do not continue into Phase 1 below.
2. **An Android-only symptom** (works on Windows, fails only on the phone; "disappears on the phone"; a logcat paste) — hand off to the `light-bug-Android` skill (Skill tool) instead of continuing here.
3. **Too thin to act on** — neither 1 nor 2 matched, AND you cannot pin down BOTH (a) which product/project this is about and (b) a concrete symptom (the message is just "there's a bug" / "it crashes", names no registered product, and no project is obvious from the working directory). Do not guess on either axis — ask with `AskUserQuestion`. If evidence type is the unclear part (might be a report they haven't attached yet, might be pure description), lead with that: "New crash-report email (.mad) or a bug you'll describe?" — its answer usually resolves the product question too, since case 1 (if they do have a report) asks about product internally. If evidence type is clear but the product/project genuinely isn't, ask which project instead.
4. **A concrete symptom with a resolvable product/project** — everything else. This is the general path (Phase 1 onward). If a product word is named (`bionix`, `dna`/`dnabaser`/`baser`), read that product's block from `C:\Users\trei\.claude\skills\light-bug-MadShi\products.ini` — you need `SourceRoot`, `ProjectFile`, `ProjectClaude`, `BugProtocol`, `FixesLog`, `BugFolderRoot` even though nothing crashed. A product word alone does NOT imply a crash: a `.mad` only exists after one, and most bugs reach you as prose, not a report. If no product word is named but a project is obvious from the working directory, use that project's own `CLAUDE.md` / Fixes Log if it has one — proceed with whatever it has, and skip the Fixes Log bookkeeping in Phase 6 if it has none.

---

## Phase 1 — Intake

1. **Restate the bug** in one sentence each: expected behavior vs. actual behavior. If the user's report doesn't make this crisp, ask.
2. **Collect evidence**: exact error text, stack trace, log excerpt, repro steps, the version/build the user is running. Quote error messages verbatim — don't paraphrase them.
3. **Define the DONE criterion**: one sentence, the observable result that proves the bug is fixed (e.g. "tray icon reappears after resume without a restart").
4. **Open a bug ledger** at `<SourceRoot>\.claude\session-bug-<short-name>.md` (create the `.claude\` folder if it doesn't exist). This doubles as the HandOver file the global CLAUDE.md convention expects, so the task survives a restart. Seed it with:

```markdown
# Bug: <short name>

## Expected vs actual
<one line each>

## DONE criterion
<one line>

## Hypotheses
| Hypothesis | Status | Evidence |
|---|---|---|
| ... | ASSUMED | ... |
```

`Status` is one of `VERIFIED` (direct proof — file:line / command output), `INFERRED` (plausible deduction, not directly checked), `ASSUMED` (no evidence yet) — the same three labels the derailment check in Phase 4 uses, so that phase can just read this table instead of re-deriving it. Update the ledger after every phase below; don't wait until the end.

## Phase 2 — Reproduce

Prefer, in this order:

1. **A failing DUnitX test** — the strongest reproduction, and it becomes the regression guard for free. Follow the `light-review-RedGreen` skill: write the test, confirm it fails on its assertion (not a compile error), for the exact symptom from Phase 1.
2. **Run the EXE** and trigger the symptom yourself, or drive it via the Autopilot MCP (`mcp__autopilot__*`) if the app has the bridge and the bug needs specific UI interaction to surface.
3. **The DPT debugger MCP** (`mcp__dpt-debugger__*`) — attach, set a breakpoint near the suspected area, step through and inspect state directly.
4. **Logs** — if the product logs exceptions (e.g. `LightCore.ExceptionLogger`), read the relevant window.

If none of these reproduce it: say so explicitly and switch to **evidence-constrained mode** for the rest of the task — every conclusion needs a citation (file:line, log line, or the user's own words), and no fix gets written without the user confirming your diagnosis first. Record which mode you're in on the ledger.

## Phase 3 — Localize

Trace the FULL call chain from the reproduction to the root cause — never stop at the first suspicious line. Same order as any Delphi trace: the product's own code first (under `SourceRoot`), then shared framework (`c:\Projects\LightSaber\`, `c:\Projects\LightProteus\`), then VCL/RTL (`c:\Delphi\Delphi 13\source\`) only if the product code genuinely doesn't explain it.

Update the hypothesis table as you go. A conclusion earns `VERIFIED` only when you've read the actual line and confirmed it does what you think — not because it "must be right." Leave it `INFERRED` otherwise.

## Phase 4 — Derailment check (mandatory)

Before writing a single line of the fix, invoke the **`light-task-DerailmentCheck`** skill (Skill tool) against the hypothesis table you've been building since Phase 1. This is not optional: a fix built on an unverified root cause costs more than the check does.

Re-run it immediately, mid-task, whenever one of these fires — the full protocol lives in that skill; this is just the trigger list so you recognize the moment:

- The user says "nope" / "no" / "wrong" / "stop", or otherwise corrects you.
- Your fix didn't change the symptom.
- Two failed fix attempts on the same symptom.
- You're editing a file your own localization in Phase 3 never mentioned.
- You're explaining away contradicting evidence ("probably flaky", "must be caching") instead of checking it.
- You're about to fix something you never reproduced in Phase 2.

If the check comes back DERAILED, follow its verdict: go back to the last verified point and show the corrected plan before touching any code.

## Phase 5 — Fix

Smallest change that fixes the root cause the derailment check just confirmed:

- `FreeAndNil` not `.Free`. Delphi vocabulary only — no `null`/`void`/`enum`/`struct`/etc.
- Specific exception types; never swallowed. `Assert`/`raise` for nil checks on objects that should never be nil.
- No cargo-cult nil-checks beyond what Phase 3 actually proved necessary. No drive-by refactoring.
- If the fix would touch shared framework code (LightSaber, LightProteus, BioControl) used by more than this product, name the affected products to the user before touching it — that code is shared, and a "fix" there can regress a different app.

The full implementation checklist (path rebasing, shared-framework precedence order, the anti-patterns list) lives in the `light-bug-MadShi` agent's Steps 5–6 (`C:\Users\trei\.claude\agents\light-bug-MadShi.md`) — read it for a non-trivial fix; the rules above cover most bugs.

If the right fix is unclear and a wrong one would do real harm, stop and ask rather than guess.

## Phase 6 — Verify

1. **Re-run the Phase 2 reproduction** (the test, the EXE, the debugger session) and confirm the DONE criterion from Phase 1 now holds.
2. **Compile ONLY via the `light-compiler` agent** (`subagent_type: "light-compiler"`) — never by hand, never `Build.cmd`/MSBuild/`dcc32` directly.
3. Invoke the **`light-review-PostEdit`** skill (Skill tool) — it checks the edit itself: broke nothing observable, missed no call sites, DFM/FMX bindings intact.
4. If the product has a `FixesLog` (from Step 0 / Phase 1), append a draft entry under **"## DRAFT — pending user verification"** at the top, in the same format as existing entries. Skip this for an ad-hoc project with no Fixes Log.
5. Report to the user: bug + root cause + fix, files touched, whether the DONE criterion is confirmed, compile/test result. Then delete the bug ledger — the global CLAUDE.md convention retires session files once the task is done. If the user hasn't confirmed the fix yet, leave the ledger in place for the next session.

**Do NOT release.** That is always a manual, explicit user action — same rule as `light-bug-MadShi`.

---

## Relationship to other skills

- **`light-bug-MadShi`** — the crash-report-specific pipeline (Thunderbird `.mad` extraction + its own agent). Step 0 routes there directly; this skill does not re-implement it.
- **`light-bug-Android`** — Android-only symptom triage (adb / logcat / tombstones). Step 0 hands off there.
- **`light-task-DerailmentCheck`** — the canonical "pause and verify conclusions" protocol. Phase 4 invokes it rather than restating it.
- **`light-review-RedGreen`** — the red/green test discipline used in Phase 2.
- **`light-review-PostEdit`** — the terminal verification step, used in Phase 6.

This skill is the entry point that ties them together for a bug of unknown shape; it isn't a replacement for any of them, and shouldn't grow to duplicate what they already own.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*
