# Claude Tools for Delphi

Claude Code skills and agents for **Delphi** development — the same tooling I use daily to build commercial Delphi apps.
MORE tools to be published!

## Skills

Slash commands you call from any Claude Code session. The name of the folder is the command: `light-review-Full` → `/light-review-Full`. Several of them drive one of the agents listed further down.

### Bugs & crashes

| Skill | What it does |
| --- | --- |
| `/light-bug` | The general entry point for any bug, however it arrives — a crash report, a pasted exception or stack trace, or a symptom described in plain words. Routes to the specialised pipelines, otherwise runs the whole thing itself: intake → reproduce (a failing DUnitX test preferred) → localize → derailment check → fix → verify → compile. Never releases. |
| `/light-bug-Android` | Triage a Delphi FMX Android crash from the PC over `adb`: capture logcat, pull the app's own exception log via `run-as`, classify the failure (IDE `SIGUSR1` noise / Pascal exception / Java exception / native tombstone / deployment), and symbolicate stripped `.so` addresses against the linker `.map`. |
| `/light-bug-MadShi` | Diagnose and fix a madExcept `.mad` crash report: read the product profile, list the recent `.mad` attachments from the mail client, pick one, then diagnose, fix and build. Stops before release. |
| `/light-bug-BioniX` | The same pipeline with the BioniX product preselected — an example of how to wire your own product into `/light-bug-MadShi`. |

### Code audits

| Skill | What it does |
| --- | --- |
| `/light-code-ArchitectureUnit` | Audit your units (files) for SHALLOW modules that should merge into one deep module — information leakage, temporal decomposition, pass-through layers, always-paired usage. Reports ranked merge candidates; never merges. |
| `/light-code-ArchitectureClass` | Audit your classes (forms included) for bad shapes — god classes, anemic data classes, misplaced responsibility, fat config records, shared mutable singletons. Reports ranked reshapes; never refactors. |
| `/light-code-CheckOsCompatibility` | Audit FMX source for cross-platform issues — Windows-only APIs, hardcoded paths, missing platform conditionals, mobile-incompatible patterns. Run it before targeting Android / iOS / macOS / Linux. |
| `/light-code-Win64Audit` | Hunt Win64 truncation bugs: pointer-width API results (`DWORD_PTR`, `LRESULT`, handles) stored in 32-bit variables, and 32-bit casts of pointers handed back to the API. |
| `/light-code-StyleChecker` | Scan imported / 3rd-party Delphi code for style compliance, common mistakes and dangerous patterns (resource leaks, unsafe casts, missing `try..finally`). Not for your own code — use `/light-review-Full` for that. |

### Review & tests

| Skill | What it does |
| --- | --- |
| `/light-review-Full` | The full three-stage review pipeline: find correctness bugs → counter-analyze and apply the fixes that survive → verify and compile. |
| `/light-review-Critical` | Counter-analyze review findings already in the conversation: verify every surviving claim against the real code and docs, drop the false positives, then fix ALL that remain — not just the easy ones. |
| `/light-review-PostEdit` | Verify the code that was just written actually works — each change matches its stated intent, broke nothing observable, missed no call site, did not break a DFM/FMX binding. Reverts what does not hold up, then tests or compiles. |
| `/light-review-RedGreen` | Red-green TDD for any change, new behavior or bug fix: the FAILING DUnitX test first, confirmed red on its assertion (not on a compile error), then drive it to green. For a bug, that failing test *is* the reproduction. |
| `/light-review-FakeTest` | Audit a DUnitX / classic-DUnit suite for FAKE or WEAK tests — ones that pass without verifying the behavior they name (zero assertions, `Assert.Pass`-only, tautologies, setup-only checks). Can PROVE fakeness with a git-safe mutation pass. |

### Starting new work

| Skill | What it does |
| --- | --- |
| `/light-new-Feature` | Turn "I want feature X" into a designed, sliced, test-driven implementation: align → PRD → vertical slices → red-green each → hand off to the review pipeline. |
| `/light-new-Align` | A one-question-at-a-time design interview before any non-trivial task. Each question carries a recommended answer, the highest-stakes ones come first, and anything decidable without you is decided without you. |

### Documentation

| Skill | What it does |
| --- | --- |
| `/light-md-DriftUpdate` | Scan project markdown (`CLAUDE.md`, `README.md`, `docs/*.md`) for drift after code changes — stale class names, file paths, settings keys, procedure signatures, architecture claims — and apply surgical fixes. |
| `/light-md-DelphiIdiom` | Fix Delphi vocabulary and clarity in markdown docs: swap borrowed C/JS/Python terms for the Delphi ones (`void` → `procedure`, `struct` → `record`, `reflection` → RTTI) and apply bounded clarity rewrites. |
| `/light-md-PruneClaudeMD` | Prune and tighten a `CLAUDE.md` (or any instruction markdown) — cut bloat and duplication, delete stale rules, move misplaced content to the right layer — without losing load-bearing information. Backs the file up first. |
| `/light-md-Coherent` | Say the last answer again in plain, short English — the jargon-stripped version, an N-point version, or an explanation of just the part that did not land. Rewrites what was already said; never re-runs the analysis. |

### Reference (knowledge loaded on demand)

| Skill | What it does |
| --- | --- |
| `/light-ref-Memory` | Delphi memory safety and exception handling: the `try..finally` gold standard, freeing owned fields, `FreeAndNil`, Owner-managed components, functions that return objects, specific `try..except`, domain exception hierarchies, bare `raise`. |
| `/light-ref-Threading` | Delphi threading on VCL and FMX (Android/iOS included): `TThread`, `CreateAnonymousThread`, the PPL, `Synchronize` vs `Queue`, `TInterlocked` / `TCriticalSection` / `TMonitor` / `TLightweightMREW`, `TThreadList` / `TThreadedQueue` / `TEvent`, graceful cancellation. |
| `/light-ref-Refactoring` | A catalog of behaviour-preserving Delphi refactorings — Extract Method, Extract Class, Guard Clauses, Named Constants, Replace Conditional with Polymorphism, Introduce Parameter Object (record), Remove `with`, Inline Method, and introducing a test seam via a shared base class. |
| `/light-ref-DesignPatterns` | The GoF patterns that actually pay off in Delphi desktop/mobile code, each with its Delphi-native shortcut (anonymous methods, virtual methods, `System.Messaging`, class functions, enumerators) so you reach for the full pattern only when it earns its keep. |
| `/light-review-DUnitX` | How to structure DUnitX tests: project layout, `[TestFixture]` / `[Setup]` / `[TearDown]` / `[Test]`, `Method_Scenario_Expected` naming, the assertion cheat-sheet, substituting a collaborator with a concrete fake (no interface required), and SQLite `:memory:` integration tests. |

### Security & process

| Skill | What it does |
| --- | --- |
| `/light-security-ClaudeSettingsAudit` | Audit the Claude Code config files on your machine (`settings.json`, `settings.local.json`, `.mcp.json`) for unsafe or malicious content — hooks that run shell commands, credential or proxy environment variables, arbitrary MCP servers, permission-bypass modes, over-broad allow rules. Read-only. |
| `/light-task-DerailmentCheck` | Pause mid-task and verify your own conclusions before continuing: classify every load-bearing conclusion VERIFIED / INFERRED / ASSUMED with its evidence, attack the unverified ones, and find the earliest wrong turn if there is one. Not Delphi-specific. |

### Web & release

| Skill | What it does |
| --- | --- |
| `/light-web-CodeReview` | Review HTML, CSS or JavaScript for errors, formatting, best practices, accessibility and cross-browser problems. |
| `/light-web-PushToFTP` | Release a tool's new version to its website FTP, following that tool's own `ReleaseProfile.md`. |
| `/light-web-UncensoredFetch` | Read a web page that Claude Code's built-in `WebFetch` refuses (the whole `reddit.com` domain is on its denylist; also Cloudflare-walled and JavaScript-only pages). Drives a local Delphi WebView2 browser and writes the visible text to a file. |
| `/light-web-YoutubeSummarizer` | Clean a YouTube transcript and summarize it — with a Delphi adaptation section when the talk is about programming. |

## Agents

The engines the skills launch. Most are also usable standalone. All are self-documented.

| Agent | What it does |
| --- | --- |
| `light-review-step1` | Stage 1 of the review pipeline: a thorough, critical review that reads code to understand intent, then verifies correctness. Not a style checker. |
| `light-review-step2` | Stage 2: counter-analyze the stage-1 findings, drop false positives (each claim re-checked against the actual file, the declaration of every named type, and at least one caller), apply the fixes that survive. |
| `light-review-step3` | Stage 3: verify the applied fixes hold up, revert the ones that do not, then compile or run the tests. |
| `light-review-FakeTest` | Read every test and decide whether a real product bug would make at least one assertion fail. Read-only. |
| `light-compiler` | Compile a Delphi project and report whether the change actually builds. Every other skill here compiles through this agent rather than calling the compiler itself. |
| `light-code-ArchitectureUnit` | The unit-granularity architecture audit — reads whole units in its own context and returns a ranked merge report. |
| `light-code-ArchitectureClass` | The class-granularity architecture audit — reads whole classes and returns ranked reshapes. |
| `light-code-CheckOsCompatibility` | Audit FMX source for cross-platform compatibility issues. |
| `light-code-StyleChecker` | Scan imported / 3rd-party Delphi units for style issues and dangerous patterns. |
| `light-bug-MadShi` | Diagnose a `.mad` crash report end-to-end, up to and including a successful build. Never releases. |
| `light-md-DriftUpdate` | Verify each documentation claim against the code and apply surgical fixes. |
| `light-md-DelphiIdiom` | The vocabulary and clarity workhorse behind `/light-md-DelphiIdiom`. |
| `light-md-PruneClaudeMD` | Prune an instruction markdown without losing load-bearing information. Verifies before cutting; flags what it is unsure about instead of deleting it. |
| `light-security-ClaudeSettingsAudit` | Classify every Claude Code config finding DANGEROUS / SUSPICIOUS / SAFE against a known-good baseline. Read-only. |
| `light-web-CodeReview` | Review HTML / CSS / JavaScript. |
| `light-web-YoutubeSummarizer` | Clean and summarize a transcript in its own context, so the bulk never reaches your main conversation. |

## How to install

Drop an agent into `~/.claude/agents/` and a skill folder into `~/.claude/skills/`, then call it from any Claude Code session. On Windows that is `C:\Users\<you>\.claude\`.

A few skills reach for something specific to my machine — a product profile, an FTP profile, a helper `.exe`. They say so in their own `SKILL.md`; adapt or ignore those.

## Author

Built by Gabriel Moraru, a long-time Delphi developer. More of my open-source Delphi code, libraries and articles: [gabrielmoraru.com/my-delphi-code](https://gabrielmoraru.com/my-delphi-code/).

## Licence

Mozilla Public License 2.0 — see [LICENSE](LICENSE). Use them, commercially included, and build your own skills around them. If you modify one of *these* files and ship it, that file stays MPL and its source has to be available. Keep the attribution footer at the bottom of each `SKILL.md`.
