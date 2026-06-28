# Compiling 


## Build System
Compile via the **`delphi-compiler` agent**. It calls `c:\Delphi\AI Delphi compiler\delphi-compiler.exe` (MSBuild wrapper → structured JSON) and reports. It does NOT run `Build.cmd`; it reads a project's `Build.cmd` only to discover the `.dproj` path. This is the default for every project here. See the global `CLAUDE.md` → "Compiling Delphi" for the full rule.

The agent compiles & reports only — it does not run anything. To run unit tests, build via the agent, then launch the test EXE yourself.

**Forced clean rebuild only:** the EXE builds incrementally. When you genuinely need `/t:Clean;Build`, run the project's `Build.cmd`. If none exists, create one from `c:\AI\Claude Code\TEMPLATE FOLDER\Build.cmd`.

**CRITICAL bash quirk (only when you do invoke Build.cmd):**
Never `cd /path && cmd //c Build.cmd` — bash cd doesn't affect cmd.exe CWD.
Always: `cmd //c "c:\\Full\\Path\\To\\Build.cmd" 2>&1`

**madExcept / madShi integration notes**
If you need to integrate madShi see: c:\AI\Claude Code\Tools\MadShi.md

### Cross-platform / mobile delivery

If you want to compile for cross platform (Android / iOS / macOS / Linux) and deliver the executable to a mobile phone, see this file: c:\Projects\FMX\CLAUDE.md
It documents the six-stage Delphi-on-Android toolchain (dccaarm64 → ld.lld → PAClient → adb → dlopen → Pascal), the FMX test sandbox, the FireUI LivePreview source, and the Android crash-reporting tool survey.


## Unit Testing
DUnitX + TestInsight. Files in `UnitTesting\`. Run: `UnitTesting\BuildTests.cmd`. No form tests.

**Fake test prevention**: Every `[Test]` must have real `Assert.*` calls verifying actual behavior. Banned: `Assert.Pass` as sole assertion (unless skipping for environment reasons with real assertion on non-skip path), zero Assert calls, compile-time-guarantee tests (`Assert.Pass('X exists')`), calling functions without checking results.


## Debugging

### DPT McpDebugger (MCP)
External debugger exposed via MCP. Attaches to compiled EXE — no IDE needed. Register once via `claude mcp add`; if not registered, tools unavailable.
Binary: `c:\Delphi\WDDelphiTools\Projects\DPT\DPT.exe D13 McpDebugger`
Tools: start/stop/terminate_debug_session, set/list/remove_breakpoint (hardware, max 4), continue, step_into, step_over, wait_until_paused, get_state, get_stack_trace, get_registers, get_stack_slots, get_stack_memory, read_memory, read_global_variable, get_proc_asm, list_threads, switch_thread, ignore_exception.
No local-variable tool — read stack slots + map file manually.
Use for: crash triage, exception flow, breakpoint sanity checks, global state, multi-threaded inspection. Not replacement for IDE debugger on heavy logic tracing.
Workflow: build EXE first → `start_debug_session <path-to-exe>` → set breakpoints → continue.

### Debugging FMX (Windows + Android)

The diagnostic stack is asymmetric — Windows is interactive, Android is passive.

**Windows-side (AI drives the app):**
- **Autopilot MCP bridge** at `c:\Projects\Projects AI\Autopilot for Delphi\` — `list_tree`, `click`, `get_text`, `set_text`, `set_property`, `read_property`, `wait_for`, `screenshot` (12 tools total). The VCL bridge is Windows-only (named-pipe transport + owner ACL); the FMX bridge is **cross-platform since Phase B** — Windows named pipe / Android AF_UNIX abstract socket reached via `adb forward`, device-verified driving an Android target end-to-end (2026-06-12). See `AI-INSTRUCTIONS.md` in that folder for verbs; `HANDOVER.md` → "Driving the demo on Android" for the Android recipe; `CLAUDE.md` → "Android support (Phase B...)" for the transport explanation.
- **DPT McpDebugger** (above) — external debugger MCP for crash triage and stepping.

**Android-side (AI reads logs the human ships back):**
- `c:\Projects\Project OrinocoReader\Frame FMX\Logcat-Android.cmd` — live tail / one-shot dump of `adb logcat` with the `AndroidRuntime:E DEBUG:E *:S` filter. Doc: `c:\Projects\FMX\Bug reporter FMX\Logcat-Android.md`.
- `c:\Projects\Project OrinocoReader\Frame FMX\ProcMaps-Android.cmd` — dumps `/proc/PID/maps` of the live process; optional hex-address argument finds the matching library / region. Resolves unsymbolicated PCs from IDE breaks.
- `c:\Projects\LightSaber\LightCore.ExceptionLogger.pas` — reusable `RaiseExceptObjProc` hook. Call `InstallExceptionLogger('<App>-Exceptions.log')` first thing in the .dpr's `begin..end`; writes every Pascal raise (class + message + thread ID + UTC timestamp) to `TPath.GetDocumentsPath\<App>-Exceptions.log`. Pull with `adb shell run-as <pkg> cat files/<App>-Exceptions.log`. Lives in LightSaber so any FMX project can `uses LightCore.ExceptionLogger;` and reuse it.
- Crash-reporter survey + DIY-hook baseline + section 6 logcat/map-file recipes + section 7 toolset roster: `c:\Projects\FMX\Bug reporter FMX\Crash Reporting Tools for Delphi FMX Android.md`.

**Known IDE noise: "exception class 10" on Android 14+** is SIGUSR1 from the Android Runtime, not a crash. Tick "Ignore this exception type" on the dialog — persists into the .dproj. Full evidence: `c:\Projects\Project OrinocoReader\Frame FMX\   android crash\CONCLUSION.md`.

## #Bug fix
Trace full call chain first. If first fix fails, re-examine the root cause; don't patch same area.



 

# LightSaber Framework 
In: c:\Projects\LightSaber\

## Key units
- `LightCore.AppData.pas` — TAppDataCore. Replaces standard DPR init code. Manages app lifecycle.
- `LightCore.StreamBuff.pas` — TLightStream binary serialization
- `LightCore.TextFile.pas` — StringToFile/StringFromFile (use instead of TFile)
- `LightCore.IO.pas` — ListFilesOf, ListDirectoriesOf, CopyFolder, DeleteFolder (use instead of System.IOUtils)
- `LightCore.LogRam.pas` — Log.Write/Log.WriteError
- `LightFmx.*` — FMX components. `LightFmx.Common.AppData.pas` = TAppData (FMX layer). `LightFmx.Common.AppData.Form.pas` = TLightForm (self-saving forms).

## AppData Architecture (3-layer system)
**1. TAppDataCore** (`LightCore.AppData.pas`) - Platform-agnostic base
- Cross-platform path management (AppData folder, Documents, System folders)
- INI file handling for application settings
- Logging system (`TRamLog`) with severity levels (Verb, Hint, Info, Warn, Error)
- Single instance detection via `SingleInstClassName`
- First-run detection via `RunningFirstTime` property
- BetaTester mode detection
- Command-line parameter handling
- Settings: `AutoStartUp`, `StartMinim`, `Minimize2Tray`, `Opacity`, `HintType`

**2. TAppData** (`LightFmx.Common.AppData.pas`) - FMX-specific functionality
- Extends TAppDataCore
- Form creation management via `CreateMainForm`/`CreateForm`
- AutoState queue system for form restoration (`asPosOnly`, `asFull`, `asNone`)
- Visual log window (`TfrmRamLog`) - auto-created on demand
- Platform-specific startup registration (Windows Registry, macOS LaunchAgents, Linux autostart)
- Application control: `Run()`, `Minimize()`, `Restart()`, `SelfDelete()`
- Dialog helpers: `PromptToSaveFile`, `PromptToLoadFile`
- Global instance: `AppData` (freed in FINALIZATION)

**3. TLightForm** (`LightFmx.Common.AppData.Form.pas`) - Self-saving forms
- Base class for all application forms (instead of TForm)
- Auto-saves form position/size/state to INI file on close
- Auto-restores position/size/state on load
- `AutoState` property controls save/restore behavior
- Mobile toolbar support (back/next buttons for Android/iOS)
- `FormPreRelease` - guaranteed single-call cleanup event
- `CloseOnEscape` property
- Event order: `Loaded` → `FormCreate` → `FormPreRelease` → `SaveForm`

### Key Concepts

**AppData Initialization Pattern**:
```delphi
begin
  AppData:= TAppData.Create('AppName', 'UniqueWindowClassName', MultiThreaded);
  AppData.CreateMainForm(TMainForm, MainForm, asPosOnly);
  AppData.CreateForm(TSecondForm, SecondForm, asFull);
  AppData.Run;  // Sets Initializing:= FALSE
end.
```

**Why It Replaces Standard DPR Code**:
- LearnAssist doesn't use `Application.Initialize`, `Application.CreateForm` directly
- AppData manages the entire application lifecycle
- Forms created via `AppData.CreateForm` are queued and realized later
- Provides consistent cross-platform behavior
- Auto-wires form save/restore without manual code

**Important Properties**:
- `Initializing`: TRUE during startup, set to FALSE in `Run()`. Used to prevent saving corrupted state if app crashes during initialization
- `RunningHome`: TRUE if .dpr file exists (development mode)
- `RunningFirstTime`: TRUE if INI file doesn't exist yet
- `AppName`: Central identifier used for INI filename, AppData folder name, etc.

Path helpers:
- `AppDataFolder()`: `C:\Users\Name\AppData\Roaming\AppName\`
- `AppFolder()`: Where EXE lives (mobile: Documents folder)
- `IniFile()`: `AppDataFolder + AppName + '.ini'`

Form AutoState (passed to CreateForm/CreateMainForm):
- `asNone`: No save/restore; `ShowModal` auto-centers on main form
- `asPosOnly`: Position only
- `asFull`: Position + all GUI controls
- `asUndefined`: Error — must be set

Form event order: `Loaded → FormCreate → FormPreRelease → SaveForm`


## Other Libraries
- **Proteus**   (c:\Projects\LightProteus\LightProteus.dpk) — Licensing system
- **AI Client** (c:\Projects\LightSaber AI Client) 


## 3rd Party
3rd party libs in 
- c:\Projects-3rd_Packages\
- c:\Delphi\
- c:\Projects\LightSaber\External (janFX, AniImg, DirectoryWatch, FastJpegDec, GifProperties, HtmlParserEx, MonitorHelper)



# Delphi codding style

Target: Delphi 13.1. Compat down to Rio when possible.


## Zero Tolerance For:
Global variables, compiler hints/warnings, swallowed exceptions, memory leaks.


## Comments
- NEVER delete `///` comments — that's temporarily disabled code, meant to return.
- Think twice before removing ANY comment. Better extra info than none.
- Verify before writing a "why". Explaining why code is needed = claiming what breaks without it. Verify first (`c:\Delphi\Delphi 13\source\`, DocWiki, framework source). Unverified → write only *what* the code does. Same for MD prose and commit messages.
- Cut "whats" the code already says. `Delay := 10` needs no `// seconds before first check`; `ShowConnectFail := FALSE` needs no `// silent on offline`. Don't re-document a library the project already uses. Keep the comment only when the *what* isn't recoverable from the code in 5 seconds: magic number (`if WeekNo = 53 then // ISO week-53 edge case`), odd cast, non-obvious branch, unfamiliar algorithm.
- `{ # Label }` spacers separate distinct logical code blocks **inside** a procedure (PAS only). Navigation aid, not documentation. One level, no nesting. Use when a procedure has several blocks - ex: form setup + splash screen, use `{ # Form setup }` then `{ # Splash screen }`.


## File Headers
- Bump the date in PAS file header to today IF you do major changes (format is 2026.04.19).

## Do use 
- Always use FreeAndNil, never use `.Free`
- Assert/raise for nil checks on objects that should never be nil. No silent `if nil then Exit`.
- Specific exception types in try/except. Always log+reraise, NEVE EVER swallow.


## Avoid
- `absolute`, raw pointers (`^`), old `file` type, `Application.ProcessMessages`, `with` statement.
- `initialization`/`finalization` sections — Non-deterministic order. If you must use it, ask.
- Generics — Only when type safety truly demands it (e.g. TDictionary). Prefer custom classes.
- String helpers — Not debuggable, minimize usage.
- Format(). I preffer IntToStr, etc.
- Dynamic component creation. When possible, create them in the DFM/FMX file.
- Boilerplate delegation — In a class, if `User` is accessible, use `TMyClass.User.Color` directly instead of creating a new method UserColor.
- Trivial properties — skip `property Age: Integer read FAge write FAge;`. Rename FAge to Age and use it directly.
- `Result:= X; EXIT;`. Use EXIT(X) instead.
- Avoid parallelization! It is VERY prone to bugs! Maybe accepted for simple tasks like GUI synchronization! When it starts requiring complex stuff like semaphores, avoid it like hell!


## Code Style - Modern Patterns
Use constants/enumerations. Use anonymous methods. Use TThread/TTask for async (never ProcessMessages).
Do not split long code and commnets on multiple rows.


## Compiler Quirks (recurring mistakes)
- `TThread.Queue`/`ForceQueue` only accept `TThreadProcedure` (parameterless ref-to-proc). `TProc` and `TNotifyEvent` are NOT auto-compatible — wrap: `TThread.ForceQueue(NIL, procedure begin Cb(); end);`


## Project rules
- Finish asked task before expanding scope.
- For larger projects, use Internet to check if somebody already implemented the code. Especially this: https://github.com/Fr0sT-Brutal/awesome-pascal
- ALWAYS preserve backward compat for binary serialization/loading!
- Speed optimizations: benchmark first, revert if worse. No assumptions.



