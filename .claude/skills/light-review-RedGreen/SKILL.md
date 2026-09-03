---
name: light-review-RedGreen
description: Red-green TDD for any Delphi change (new behavior OR bug fix): write the FAILING DUnitX test first, confirm red on its assertion (not a compile error), then drive to green, compiling only via the light-compiler agent. For a bug the failing test is the reproduction. Say "TDD this", "write the test first", "reproduce the bug with a test", "red-green".
author: Gabriel Moraru
homepage: https://gabrielmoraru.com
license: MPL-2.0
---

# /light-review-RedGreen — Test first, then make it pass

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
- Confirm the runner's no-assert guard is on (`FailsOnNoAsserts` in the DUnitX runner) so an accidental zero-assertion test cannot pass silently. This is the same fakeness `/light-review-FakeTest` hunts — do not author one here.

## Compiling — via the light-compiler agent

Compile the test `.dproj` via the **`light-compiler` agent** (`subagent_type: "light-compiler"`) — never build by hand (global `CLAUDE.md` rule). Fix and recompile until clean, then **launch the test EXE yourself** to read the DUnitX counts. If the EXE is locked by a running app, tell the agent to use `--test` (it builds to a temp folder) rather than killing the process.

## Optional - check it in the running app

A DUnitX test cannot reach behaviour that only exists once a form is on screen.

If the project has the **Autopilot for Delphi** bridge linked in, drive the running program and check the behaviour for real: call `list_tree` once to learn the control paths, then `click`, `set_text`, `get_text` or `read_property`. Prefer `get_text` over a screenshot - it is faster and costs no image tokens.

If a tool answers `-32099 target_not_running`, the program is closed or was built without the bridge. Say so and stop; do not retry, and do not go and wire the bridge in unless asked. What it is and how to link it: https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/

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

This is the standalone red-green loop, usable for **any** change — especially **bug fixes**, which the feature pipeline does not cover. `light-new-Feature` Phase 4 is the same loop inside the feature flow; it should reference this skill rather than restating it.

---

*[Claude Tools for Delphi](https://github.com/GabrielOnDelphi/Claude-Tools-for-Delphi) — © 2026 Gabriel Moraru, [gabrielmoraru.com](https://gabrielmoraru.com) — MPL-2.0*

*[Autopilot for Delphi](https://gabrielmoraru.com/my-delphi-code/autopilot-for-delphi/) — Claude clicks, types and reads inside your running VCL / FMX app.*
