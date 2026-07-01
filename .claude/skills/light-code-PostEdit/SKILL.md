---
name: light-code-PostEdit
description: Verify the code you just wrote (bug fix or new feature) actually works. For each change, confirm the new code matches the stated intent, didn't break anything observable, didn't miss call sites, and didn't break DFM/FMX bindings. Revert anything that doesn't hold up. Then run the project's tests (large change) or compile (small change). Terminal step — beeps when done. Use after implementing a fix or new feature, or when the user invokes `/light-code-PostEdit`.
---

# Delphi Post Change

You just wrote new code. Some of it is wrong. Find the problems before the user does.

**Precondition:** if no code changes were made in this session, stop and tell the user: *"No prior changes found in this session — there is nothing to verify."* Do not invent edits to verify.

## Step 1 — List what you changed

For each edit you applied in this session:
- file:line of the change
- one sentence: what the code does now (new feature) OR what the original did vs. what the new code does (bug fix)
- one sentence: WHY you made the change (the feature requirement or the bug you were fixing)

If you cannot state the "why" clearly, the change is suspect — flag it.

## Step 2 — Load the false-positive memory and match against the list

1. Read `C:/Users/trei/.claude/agent-memory/light-review/patterns_common_false_positives.md` if it exists.
2. Glob `C:/Users/trei/.claude/agent-memory/light-review/patterns_*.md` and read the 2–5 files whose filename keywords match the files you edited (e.g., edited `FormLessonChat.pas` → read `patterns_formlessonsetup_*.md`, `patterns_formview_main_chat.md`, etc.).

For every edit in your Step 1 list, check: does this change contradict a known-good pattern? If yes, **revert immediately** and note the revert.

If the memory directory does not exist, skip this step.

## Step 3 — Critical analysis of each change

For every edit:

- **Does the code match the stated intent?** Does the new code actually do what you described, or does it just appear to?
- **For bug fixes:** did you fix the root cause or just paper over a symptom? Could the underlying problem still manifest in a different code path?
- **For new features:** does the feature handle the obvious edge cases — empty input, nil references, boundary values, range-check errors, missing objects, double-invocation?
- **Did you change observable behavior the original code did not need to change?** Unintended side effects: wrong default, swapped order of operations, different exception type, weakened invariant.
- **Did you touch one call site but miss another?** Grep for the procedure name or pattern across the project.
- **Did you change a procedure signature, class layout, or DFM/FMX-bound field?** If yes, find every caller and confirm they still work.
- **Did the change introduce a new exception path, ownership shift, or broken invariant?** Watch for: `Free` on a non-owned object, missing `try/finally`, `FreeAndNil` on a borrowed reference, dangling event handlers after a form closes.
- **Resource leaks.** New `TStringList.Create`, `TFileStream.Create`, `TBitmap.Create` etc. — is there a matching `Free` or `try/finally`?
- **Threading.** Did you touch code that runs on a non-main thread? `Synchronize` / `Queue` boundary preserved?

## Step 4 — Counter-analysis

For each change, argue the opposite case:

- "What if the original code was actually correct (for fixes) or the new feature is solving the wrong problem?"
- "What if my change is correct but I overshot — could a smaller change have worked?"
- "What if a related guarantee exists upstream that my new code now violates downstream?"
- "What if the feature is correct in isolation but breaks an assumption another part of the code relies on?"

Verify, do NOT speculate. Read the files. Check the docs. Search the Internet if needed (Embarcadero, RTL source at `c:\Delphi\Delphi 13\source\`).

## Step 5 — Integration check

For every modified file:

- **Read the interface section** of the unit you changed. Did the public surface change in any way? If yes, every consumer is affected.
- **Grep for every public identifier you touched or added.** List every call site. Read each one.
- **DFM/FMX bindings.** If you renamed, removed, or added a published field/event the form expects, the form will fail to load. Check the `.dfm` / `.fmx`.
- **New units.** If you added a new unit, is it added to the `.dpr` / `.dproj` or only sitting on disk? An unreferenced unit will not be compiled into the project.
- **New `uses` entries.** Did you add a `uses` that pulls in a circular dependency? Don't manually trace cycles — the Delphi compiler emits E2004. Step 7's compile catches it.

Do NOT run the compiler in this step — Step 7 handles it. (Avoid double-compiling.)

## Step 6 — Revise

Produce three sections:

- **Changes that hold up** — short list, one line each.
- **Changes that need adjustment** — what was wrong, what the corrected version looks like, then apply the correction.
- **Changes that should be reverted** — the new code was wrong; undo the edit and explain why.

Apply adjustments and reverts in this step. Do NOT just report them.

## Step 7 — Final integration test

A change is **large** if any of these is true:
- More than one file was modified.
- More than 20 lines of code changed total (additions + deletions, ignoring blank/comment-only changes).
- A public procedure signature, class layout, or DFM/FMX-bound member changed.
- A new unit was added to the project.

**Compile ONLY via the `light-compiler` agent.** Call the **Agent** tool with
`subagent_type: "light-compiler"` and give it the `.dproj` path to build. That agent calls
`delphi-compiler.exe` and returns structured JSON (status + per-issue file/line/col + source
context). **Never** hand-run `Build.cmd` / `BuildTests.cmd` / MSBuild / `dcc32` — not via Bash,
not via PowerShell, not via `cmd /c`. The global `CLAUDE.md` forbids it.

**If the change is small:** point the agent at the **main** `.dproj` and confirm a clean build.
No tests needed.

**If the change is large:** point the agent at the **test** `.dproj` (usually
`UnitTesting\Tests.dproj`), then — once the agent reports a clean test build — **launch the test
EXE yourself** to read the DUnitX pass/fail counts. The agent compiles and reports only; running
the EXE for the counts is your job. Also compile the main `.dproj` via the agent and confirm it is
clean.

If you cannot find a `.dproj` (no test project for a large change, say), report that and wait for
user input — do NOT improvise an `msbuild` or `dcc32` invocation, and do NOT fall back to a build
script. If the target EXE is locked because the app is running, tell the agent to use `--test`
(it compiles to a temp folder) rather than killing the process.

If tests/compile fail, treat the failure as a regression you caused unless you can clearly trace it to a pre-existing issue. Fix it or revert the offending edit. Any new revert performed here feeds Step 8.

## Step 8 — Update the false-positive memory

If a change was reverted in Step 2, Step 6, OR Step 7 because the "improvement" turned out to contradict an intentional pattern, add it to `patterns_common_false_positives.md`. One short bullet per pattern.

If you create a new pattern file, add an index entry to `C:/Users/trei/.claude/agent-memory/light-review/MEMORY.md`.

Skip this step if the memory directory does not exist.

## Final report

This is the terminal step. Do NOT hand off to another skill.

Report: what held, what was adjusted, what was reverted (and at which step), test/compile result.

The output must end with **exactly one block** — the stage-end Report — followed by the beep command, and nothing after them:

```

================
Report:
<one or two lines max — what held / was adjusted / was reverted, plus the test or compile result. No detailed recap; the full report is above.>
================

```

Then run the beep so the AFK user knows verification is done:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\Tools\task_done_beep.wav').PlaySync()"
```

**Anti-duplication rule:** The Report block above is the ONLY end-of-stage summary. Do NOT write a "Final summary", "Conclusion", or "Wrap-up" section above it. The "Changes that hold up / need adjustment / should be reverted" sections from Step 6 stay — but no extra summary on top of them.

**Top-of-summary cue (redundancy):** As the FIRST line of your final response, write one line: `Pipeline terminal step — no further auto-chain.` — so the user can see at a glance the verification chain is ending here.

**Do not draw separators between intermediate tasks.** Only the single end-of-stage Report block above is emitted.
