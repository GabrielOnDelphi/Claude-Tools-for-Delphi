---
name: light-code-RedGreen
description: Red-green TDD for any Delphi change — a new behavior OR a bug fix. Forces the FAILING DUnitX test to be written and confirmed red FIRST (failing on its assertion, not a compile error), then drives the implementation to green, compiling ONLY through the light-compiler agent. For a bug, the failing test IS the reproduction — green means fixed and regression-proofed. Stops the AI writing the code first and a test that merely echoes it. Use when the user says "TDD this", "write the test first", "reproduce the bug with a test", "red-green", or before implementing any change that has testable logic.
---

# /light-code-RedGreen — Test first, then make it pass

This skill enforces one discipline: **a failing test that fails on its own assertion exists and is confirmed RED before any production code is written.** Then you make it green. Nothing else.

Why it matters: a test written *after* the code is tautological — it confirms the code does what the code does, not what the requirement says. Red-first is the only cheap proof the test can actually fail.

## Two entry modes

- **New behavior** — the test encodes the requirement the new code must satisfy. It is red because the behavior does not exist yet.
- **Bug fix** — the test *reproduces the bug*: it asserts the correct result and therefore fails against today's buggy code. Green then means the bug is fixed AND a regression test guards it forever. This is the highest-value use — never fix a bug without it, unless the bug is genuinely untestable (see "When not to use").

## The loop (one behavior at a time)

1. **Locate the test project** (usually `UnitTesting\Tests.dproj`) and the unit under test. If the project has **no** test project, do NOT guess a layout — ask the user whether to create one (template: `c:\AI\Claude Code\TEMPLATE FOLDER\UnitTesting (TEMPLATE)\`) and wait.
2. **Write ONE failing `[Test]`** for this behavior. It MUST:
   - use a real assertion (`Assert.AreEqual`, `Assert.IsTrue`, `Assert.WillRaise`, …) — never `Assert.Pass` as the sole assertion, never zero `Assert.*` calls;
   - assert *behavior* (a returned value, a raised exception, a state change), not "the type exists" or "the function is callable";
   - have a name that states what is verified.
3. **Confirm RED — and for the RIGHT reason.** Compile the test `.dproj` via the **`light-compiler` agent** (see Compiling), then **launch the test EXE yourself** and read the DUnitX counts. The test must **fail on its assertion** (DUnitX reports a *failure* — e.g. "Expected 5 but got 0") — NOT fail to compile, and NOT error out for an unrelated reason. A compile error or an unexpected exception means the test is wrong; fix the test before writing any product code.
4. **Green — implement the smallest change that makes it pass.** Reuse LightSaber before writing new code — a `LightCore.*` / `LightVcl.*` / `LightFmx.*` unit may already do it; `uses` that unit instead of hand-rolling, and say you checked. Then compile via the agent, launch the EXE, and confirm the test now **passes** and nothing else went red.
5. **Refactor only if needed**, then re-run the EXE to confirm it is still green.
6. **Stop — do not commit.** Leave the change for the user to review and commit; git is theirs to trigger.

## Validity guards (so green means something)

- The test must have **failed first**. If you cannot make it red, you are not testing new behavior — rethink the test.
- It must fail **on the assertion**, proving it actually exercised the code. A test that "reds" via a compile error proves nothing.
- Confirm the runner's no-assert guard is on (`FailsOnNoAsserts` in the DUnitX runner) so an accidental zero-assertion test cannot pass silently. This is the same fakeness `/light-code-FakeTestAudit` hunts — do not author one here.

## Compiling — ALWAYS via the light-compiler agent

**Never run `BuildTests.cmd`, `Build.cmd`, MSBuild, or `dcc32` by hand** — not via Bash, PowerShell, or `cmd /c`. The global `CLAUDE.md` forbids it. To compile, call the **Agent** tool with `subagent_type: "light-compiler"` and give it the test `.dproj` to build. It returns structured errors (file/line/col + context); fix the code and call it again until clean. The agent **compiles and reports only** — **launching the test EXE to read DUnitX pass/fail counts is your job.** If the EXE is locked by a running app, tell the agent to use `--test` (it builds to a temp folder) rather than killing the process.

## Banned

- `Assert.Pass` as the sole assertion — allowed only on a documented skip path that still has a real assertion on the non-skip path.
- A `[Test]` with zero `Assert.*` calls.
- Compile-existence "tests" like `Assert.Pass('Type X exists')` — that is a compile check, not a behavior test.
- Calling the code under test and asserting nothing about the result.
- Writing the test AFTER the implementation. Red comes first — that is the whole point.

## When NOT to use this skill

- Pure UI / visual / "feel" changes with no testable logic — defer to manual QA.
- Trivial typo or comment fixes.
- Form layout dictated by the `.dfm`/`.fmx` (the project's "no form tests" rule — see `CLAUDE.md`).

## Relationship to other skills

This is the standalone red-green loop, usable for **any** change — especially **bug fixes**, which the feature pipeline does not cover. `light-code-NewFeature` Phase 4 is the same loop inside the feature flow; it should reference this skill rather than restating it.

Then beep once so the AFK user knows it finished:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\Tools\task_done_beep.wav').PlaySync()"
```
