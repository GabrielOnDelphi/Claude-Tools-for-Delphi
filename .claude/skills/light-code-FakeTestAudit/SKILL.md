---
name: light-code-FakeTestAudit
description: Audit a Delphi DUnitX or classic-DUnit test suite for FAKE tests — tests that pass without verifying the behavior they claim (zero assertions, Assert.Pass-only, tautologies, setup-only checks, tautological helpers, vague error checks, negative tests with no probe). Establishes the green baseline, launches the light-code-FakeTestAudit agent, and optionally PROVES fakeness with a git-safe mutation pass. Use when the user invokes `/light-code-FakeTestAudit`, says "are these tests fake", "make sure the tests aren't fake", "did we game the tests to pass", "audit test integrity", or "check the dunit tests actually test something".
---

# /light-code-FakeTestAudit — Test-Integrity Auditor

This skill answers one question: **is the suite's green real, or do some tests pass without testing anything?** A "fake" test is one that stays green even when the product code it names is broken — zero assertions, `Assert.Pass`-only, a tautology, a setup-only check, a tautological helper, a vague "something errored" check, or a negative test with no probe.

**Scope:** this audits EXISTING tests for honesty — whether each one *can fail*. It does NOT measure code coverage or find missing tests; a suite of 100%-honest tests can still under-test the product. Coverage gaps are a different job — say so if the user conflates the two.

**You (the main thread) orchestrate. You do NOT audit the tests yourself** — the `light-code-FakeTestAudit` agent does the per-test analysis. Your job: resolve the scope, establish the green baseline, launch the auditor (sharded if large), optionally run a mutation proof, then summarize.

## Parse `$args`

`$args` may contain a path (file / folder / several files) and/or a mode keyword:
- **default** — baseline run + static audit.
- `static` or `--no-run` — skip the build+run baseline; static audit only (use when the build infra isn't here or the user just wants the read).
- `deep` or `mutation` — after the static audit, PROVE the findings with a git-safe mutation pass (Step 4). Opt-in because it edits product code (and reverts it) and rebuilds repeatedly.

## Step 1 — Resolve the test scope

Build the **test set** — the list of test `.pas` units to audit:
- **Explicit file(s)** → use as-is.
- **A folder** → Glob `<folder>/**/*.pas`, then keep only units that are actually tests: Grep them for `DUnitX.TestFramework` or `TestFramework` (the framework `uses`), plus `[Test]` or a `TTestCase` descendant. Drop helpers/fixtures that contain no tests (still note them — the auditor may need them to resolve helpers).
- **No argument** → discover. Look for a `Tests\` or `UnitTesting\` folder under the project; if none, Grep the repo for `DUnitX.TestFramework|TestFramework` to find test units. Present the discovered set and proceed. If you find more than ~25 test units, print the count and ask whether to audit all or narrow.
- **No test units found at all** → say so and stop. There is nothing to audit; do not invent a scope.

Also locate the **runner unit** (the test `.dpr` or the unit that calls `TDUnitX.CreateRunner` / `RegisterTest` / `RunRegisteredTests`). The auditor needs the no-assert guard setting from it.

Print the resolved test set + runner file as a short list before launching anything.

## Step 2 — Establish the green baseline (default; skip on `static` / `--no-run`)

A fake test only matters if it is **passing**. Confirm the suite is green first, so the audit can say "of the N passing tests, M are fake".

1. **Build the test project via the `light-compiler` agent** (per project rules: never compile by hand, never run `Build*.cmd` to build). Pass it the test `.dproj`. Capture the hints/warnings/errors result.
2. **Launch the test exe yourself** and capture DUnitX/DUnit pass/fail/ignored counts (the compiler agent reports compile only; it does not run tests). A DUnitX console runner prints `Tests Found / Passed / Failed / Errored`. Record the numbers and the exit code.

Handle the messy cases:
- **Build fails, or no test `.dproj`/exe found** (some projects aren't wired the same) → say so and continue to the static audit anyway; note in the final report that the green baseline is unverified.
- **Some tests FAIL or ERROR** (suite not all-green) → those are honestly red and out of scope — list them separately and audit the PASSING set for fakeness (a fake hides in green, not red). Pass the failing-test names to the auditor so it doesn't waste effort claiming a red test "can't fail".
- **More than one test project** → build+run each, or, if there are many, ask the user which to audit. Don't silently audit just the first.

## Step 3 — Launch the auditor agent

Call the **Agent** tool with `subagent_type: "light-code-FakeTestAudit"`.

- **Small set** (one or two modest files) → one agent, pass the whole test set.
- **Large set** (a big fixture like a 2000+-line unit, or many units) → shard: **one agent per test unit, launched in parallel** (cap ~6 concurrent), so each agent reads its file completely instead of sampling. Give every agent the SAME shared context: the framework dialect and the **runner no-assert-guard setting** from Step 1/2 (so it doesn't re-derive it), plus the paths of any shared helper/fixture units it may need to open to resolve assertion helpers.

Tell each agent plainly: audit these test units for fake/weak tests, READ-ONLY, return the REAL / WEAK / SUSPECT / IGNORED verdicts with evidence per the agent's report format. **Capture each agent's final report verbatim** — you'll merge them.

The auditor is read-only on code by design (independent, untainted audit). Do not ask it to fix anything.

## Step 4 — Mutation proof (only on `deep` / `mutation`)

Static analysis is strong but a verdict is *proven* by mutation: break the product code a test covers, and a REAL test must turn red. This step proves SUSPECT tests are fake (they stay green) and spot-checks a sample of REAL tests (they go red).

**Safety rails — do not skip:**
- **Require a clean git working tree.** Run `git status --porcelain`; if it's dirty, do NOT proceed — tell the user to commit/stash first. Mutation edits real source; git is the undo.
- Operate on **one product file at a time**, one mutation at a time.

**Per chosen test** (all SUSPECTs, plus ~3 REAL tests sampled across fixtures):
1. Identify the exact product line the test claims to cover (the auditor's "mutation that would not be caught" line tells you what to break).
2. Apply ONE small mutation to the product source (negate a boolean, swap a comparison, change a returned constant/error code, force an early `Exit`).
3. **Rebuild via the `light-compiler` agent.** If the mutation does not compile, it proves nothing — revert and pick another. Then **run the whole suite** and note which tests flipped green→red (don't rely on per-test filtering — it's unreliable across runners; diff the pass list instead).
4. Read the result:
   - A **REAL** test under that code must now **FAIL**. If it still passes → it's fake after all; upgrade it to SUSPECT, tagged "proven: survived live mutation `<desc>`".
   - A **SUSPECT** staying green is conclusive **only if the mutation is demonstrably LIVE** — i.e. at least one OTHER test (ideally a REAL test on the same line) went red, proving the mutated code actually runs under test. If NOTHING went red, the mutation was inert (dead code, or off every tested path) and proves nothing — pick a mutation closer to the SUSPECT's path and retry. A live mutation that the SUSPECT ignores = fakeness **confirmed**.
5. **Revert immediately: `git checkout -- <file>`** (or `git restore`). Rebuild (clean, via the compiler agent, so no stale DCU masks the revert) and re-run to confirm the suite is green again before the next mutation. Never leave a mutation in the tree; if interrupted, `git status` shows it and `git checkout -- <file>` restores it.

If git isn't available, refuse the mutation pass (don't risk unrecoverable edits) and say the deep proof was skipped for safety.

## Step 5 — Consolidated report + beep

Merge the agents' verdicts (and any mutation results) into ONE short summary — the agents' full reports are already in the transcript, don't re-paste them. Cover:

- **Baseline** — built clean? `Found/Passed/Failed/Ignored` from Step 2 (or "not run").
- **Headline counts** — across the whole set: REAL / WEAK / SUSPECT(fake) / IGNORED, and **how many SUSPECT tests are currently counted as passing** (the inflated-green number — the thing the user actually cares about). To get it: with an all-green baseline every SUSPECT is a passing fake; if some tests were red, subtract any SUSPECT that's in the failing set (a red fake isn't inflating the green).
- **Runner guard** — `FailsOnNoAsserts` (or DUnit `FailsOnNoChecksExecuted`) true/false, and whether an off-guard is justified.
- **The fakes** — list every SUSPECT test (`Unit.pas:line` + the one-line reason). These are the action items.
- **Weak** — list WEAK tests briefly (especially vague-error and no-probe negative tests) as "real but should be strengthened".
- **Ignored** — any `[Ignore]`/unregistered tests that look green but never run.
- **Mutation proof** (deep mode) — which verdicts were proven.
- **Verdict** — one line: is the green trustworthy?

Optionally, if the user wants a trail across sessions, append a dated one-line entry (`YYYY-MM-DD — audited N tests: r real / w weak / s fake — <verdict>`) to a `TestAuditHistory.md` in the project root. Keep it to one line per run.

**Fixing is a separate, explicit step.** This skill reports; it does not rewrite tests (turning a fake test into a real one needs product knowledge and is easy to get wrong). If the user wants the fakes fixed, do that as a follow-up task, one test at a time, and re-run this audit after.

Then beep once so the AFK user knows it finished:

```
powershell -c "(New-Object Media.SoundPlayer 'c:\AI\Claude Code\claude bip.wav').PlaySync()"
```

## Rules

- **You orchestrate; the agent audits.** Resolving scope, baseline build+run, launching/​sharding the auditor, optional mutation, and summarizing is your whole job. Don't second-guess the auditor's per-test verdicts — relay them.
- **Build only via the `light-compiler` agent.** Never compile by hand, never run `Build*.cmd` to build (project rule). You launch the resulting exe yourself for pass/fail counts.
- **Default is read-only.** Only `deep`/`mutation` mode edits code, and only under a clean git tree with immediate `git checkout --` revert. A dirty tree or missing git ⇒ no mutation pass.
- **Be honest about the green.** The headline number is "how many passing tests are fake". Don't soften it. A suite can be "105/105 passing" and still have fakes inflating that count.
- **Dialect-aware.** Handle both DUnitX (`[Test]`, `Assert.*`, `FailsOnNoAsserts`) and classic DUnit (`published` on `TTestCase`, `Check*`/`Fail`, `FailsOnNoChecksExecuted`).
- **One beep, at the very end**, after the report.
