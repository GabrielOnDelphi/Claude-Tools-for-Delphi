# Claude Tools for Delphi

Claude Code agents and skills for **Delphi** development — the same tooling I use daily to build commercial Delphi apps.  
MORE tools to be published!

## Skills

Slash commands you call from any Claude Code session. Most drive one of the agents below.

| Skill | What it does |
| --- | --- |
| `/light-code-Review` | Full three-stage Delphi code review pipeline: find bugs → counter-analyze + fix → verify + compile. |
| `/light-code-StyleChecker` | Scan imported / 3rd-party Delphi code for style compliance, common mistakes and dangerous patterns (resource leaks, unsafe casts, missing `try/finally`). Not for your own project code — use `/light-code-Review` for that. |
| `/light-code-FakeTestAudit` | Audit a DUnitX / classic-DUnit test suite for FAKE or WEAK tests — ones that pass without verifying the behavior they claim (zero assertions, `Assert.Pass`-only, tautologies, setup-only checks). Reports REAL / WEAK / SUSPECT per test, and can PROVE fakeness with a git-safe mutation pass. |
| `/light-code-CheckOsCompatibility` | Audit Delphi FMX source for cross-platform issues — Windows-only units/APIs, hardcoded paths, missing platform conditionals, mobile-incompatible patterns. Use before targeting Android / iOS / macOS / Linux. |
| `/light-md-DelphiIdiom` | Fix Delphi vocabulary and writing-clarity issues in Markdown docs — swaps non-Delphi terms for Delphi ones and applies bounded clarity rewrites. |

## Agents

The engines the skills launch (some are usable standalone). All are self-documented.

| Agent | What it does |
| --- | --- |
| `light-review-step1` | Stage 1 of the review pipeline: thorough, critical code review that finds correctness bugs. |
| `light-review-step2` | Stage 2: counter-analyze the stage-1 findings, drop false positives, apply the fixes that survive. |
| `light-review-step3` | Stage 3: verify the applied fixes hold up, revert bad ones, then compile. |
| `light-style-checker` | Scan imported / 3rd-party Delphi units for style issues and dangerous patterns. |
| `light-fake-test-auditor` | Read every test and decide whether a real product bug would make at least one assertion fail. |
| `light-os-compat` | Audit Delphi FMX source for cross-platform compatibility issues. |
| `light-md` | Fix Delphi vocabulary and writing-clarity issues in Markdown docs (the `/light-md-DelphiIdiom` workhorse). |
| `light-ClaudeMD-prune` | Prune and tighten a `CLAUDE.md` (or any agent/skill instruction markdown) — cut bloat, fix stale rules, relayer misplaced content — without losing load-bearing info. |

## How to install

Drop an agent into `~/.claude/agents/` and a skill into `~/.claude/skills/`, then call it from any Claude Code session.

## Author

Built by Gabriel Moraru, a long-time Delphi developer. More of my open-source Delphi code, libraries and articles: [gabrielmoraru.com/my-delphi-code](https://gabrielmoraru.com/my-delphi-code/).
