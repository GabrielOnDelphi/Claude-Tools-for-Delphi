# Topic: code

> **This is the author's own stack profile, kept as a worked example.** Replace the sections
> below with your own compiler version, framework, build and test rules before using the skill,
> or the "apply it" section will adapt every video to somebody else's project.

Load this when the video teaches something about writing software — a technique, a design idea, a testing practice, a language feature, a tool. Gabriel writes Delphi, so a general programming idea still lands in Delphi code: an architecture talk, a Rust error-handling talk, a "tidy first" talk all get adapted to the stack below. Do not translate a general idea into fake Delphi specifics it never had — say what transplants and what doesn't.

Section heading to use: `## Applying it to your Delphi work`

Be specific. Name the unit, the agent, the rule, the path. Generic advice is useless to him.

## Compiler & target

Delphi 13.1 (Athens). Compat down to Rio when feasible. Primarily Windows; some FMX cross-platform (Android/iOS/macOS).

## LightSaber framework (`c:\Projects\LightSaber\`)

- `TAppDataCore` (`LightCore.AppData.pas`) — replaces standard DPR init code; app lifecycle, paths, INI, single-instance, logging.
- `TAppData` (`LightFmx.Common.AppData.pas`) — FMX layer; queue-based `CreateMainForm` / `CreateForm`, `Run()` to start.
- `TLightForm` (`LightFmx.Common.AppData.Form.pas`) — self-saving forms (auto save/restore position + state via INI).
- `TLightStream` (`LightCore.StreamBuff.pas`) — binary serialization. **Backward-compat is mandatory** for any persisted format.
- `TRamLog` — `Log.Write` / `Log.WriteError`.
- `LightCore.IO.pas` — `ListFilesOf`, `CopyFolder`. Use **instead of** `System.IOUtils`.
- `LightCore.TextFile.pas` — `StringToFile` / `StringFromFile`. Use **instead of** `TFile`.

## Build

- Compile **only** through the `light-compiler` agent, pointing it at the `.dproj`. Never run a `Build.cmd` yourself, and never call MSBuild or `dcc32` directly.
- Configs: Debug (no optimization, range/overflow checks on) / PreRelease (optimized, checks on) / Release (optimized, checks off). madExcept is in **all three** — Debug uses a shared no-box settings file so an unattended run cannot block.

## Test

- DUnitX + TestInsight, files in `UnitTesting\`. Build the test `.dproj` via the `light-compiler` agent, then launch the test EXE.
- No form/UI tests. Every `[Test]` needs real `Assert.*` calls — fake tests are banned (`light-review-FakeTest` hunts them).
- Red-green workflow lives in `/light-review-RedGreen`; DUnitX structure reference in `/light-review-DUnitX`.

## Style baseline (zero tolerance)

- `FreeAndNil` mandatory, never bare `.Free`. No global variables. No swallowed exceptions. No leaks. No compiler hints/warnings.
- Avoid: `with`, `absolute`, raw pointers, old `file` type, `Application.ProcessMessages`, `Format()`, string helpers, generics unless type safety demands, dynamic component creation.
- Prefer: anonymous methods, `TThread`/`TTask` for async, specific exception types, `EXIT(value)` over `Result := X; EXIT;`.
- Comments starting with `///` are temporarily disabled code — never delete.

## Agents & skills an idea could slot into

`light-compiler` (build) · `light-review-Full` (own code, 3 stages) · `light-code-StyleChecker` (3rd-party) · `light-code-ArchitectureUnit` / `-ArchitectureClass` (shallow units, god classes) · `light-code-CheckOsCompatibility` · `light-code-Win64Audit` · `light-bug` (+ `-MadShi` crash reports, `-Android`) · `light-new-Feature` / `-Align` / `-Blindspot` · `light-ref-Threading` / `-Memory` / `-DesignPatterns` / `-Refactoring`.

## Debug

DPT McpDebugger MCP — attaches to a compiled EXE without the IDE: breakpoints, step, registers, stack, globals, threads. Autopilot MCP drives a running VCL/FMX app (desktop + Android).

## The honest-misfit rule

Ideas that assume a garbage collector, a JIT, hot reload, a package ecosystem like npm, a REPL, or cheap parallel builds usually do **not** transplant — Delphi compilation is IDE-and-licence-bound and serialized through MSBuild. Saying so in two sentences is worth more than a forced adaptation.
