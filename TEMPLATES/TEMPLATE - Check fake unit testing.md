Audit the DUnitX tests in this project for **fake tests** — tests that look like they verify behavior but actually verify nothing.
Use multiple agents when useful (for reading related files or Internet searches).

Claude (and Opus 4.7 in particular) tends to fabricate tests just to make the suite go green. Hunt them down.

## What counts as a fake test

A `[Test]` method is fake if ANY of these are true:

1. **Zero `Assert.*` calls** — the test runs code but never checks the result.
2. **`Assert.Pass` as the only assertion** — unconditional success. The only acceptable use is in the *skip* branch of an environment guard, AND the non-skip branch must contain real assertions.
3. **Compile-time-guarantee tests** — e.g. `Assert.Pass('TFoo exists')`, `Assert.IsTrue(SizeOf(TBar) > 0)`. The compiler already guarantees this; the test verifies nothing at runtime.
4. **Tautologies** — `Assert.AreEqual(X, X)`, `Assert.IsTrue(TRUE)`, `Assert.IsNotNil(Self)`.
5. **Calls without verification** — invokes a procedure but never inspects its output, side effects, or state changes.
6. **Swallowed exceptions** — `try DoStuff except end;` followed by `Assert.Pass`. If the test is supposed to verify an exception, use `Assert.WillRaise`.
7. **Hardcoded expected = actual from the same source** — `Expected:= Foo(); Actual:= Foo(); Assert.AreEqual(Expected, Actual);`.
8. **Asserts on input, not output** — verifies the value it just set, not what the SUT produced.
9. **Disabled assertions** — real `Assert` lines commented out or behind `{$IFDEF FALSE}`, leaving only weak ones.
10. **`Assert.IsTrue(Obj <> nil)` after `Obj:= TFoo.Create`** — Create either succeeds or raises; the check is dead code.

## Procedure

1. Locate the test project (usually `UnitTesting\Tests.dproj`). Enumerate every `.pas` file in `UnitTesting\` and any nested test folders.
2. For each unit, list every `[Test]`-attributed method and classify it: **real**, **fake**, or **suspicious** (needs human judgment).
3. For each fake/suspicious test:
   - Quote the offending lines with `file:line` references.
   - Explain *why* it's fake (which rule above it violates).
   - Read the SUT (system under test) and propose a real assertion that would actually verify behavior.
4. Counter-analysis: re-check your "real" verdicts. Did you miss a subtle tautology? Did you flag something as fake that has a legitimate environment-guard pattern?
5. Apply fixes directly (don't ask permission for obvious cases). For ambiguous cases — where the test's intent is unclear — list them at the end for me to decide.

## Rules

- Don't delete a fake test outright unless the SUT it claims to cover no longer exists. Replace it with a real one.
- If a test was skipping due to a missing fixture/file/env, keep the skip but add real assertions on the non-skip path.
- Update the file date (top of each `.pas` you modify) to today.
- After fixes, rebuild via `UnitTesting\BuildTests.cmd` and confirm the suite still compiles.
- Give me a short summary: count of real / fake / suspicious tests, what you fixed, what needs my input.

## Reference

Global rule (from `~\.claude\CLAUDE.md` → Unit Testing):
> Every `[Test]` must have real `Assert.*` calls verifying actual behavior. Banned: `Assert.Pass` as sole assertion (unless skipping for environment reasons with real assertion on non-skip path), zero Assert calls, compile-time-guarantee tests (`Assert.Pass('X exists')`), calling functions without checking results.

 

