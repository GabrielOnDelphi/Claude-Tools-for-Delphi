# Reference — Delphi FMX Android crash triage

Extracted 2026-07-03 (by Fable 5) from `c:\Projects\FMX\Bug reporter FMX\Crash Reporting Tools for Delphi FMX Android.md` (Sections 3.0 + 6). This file is the canonical copy for the `/light-bug-Android` skill; the source sections get pruned per the no-duplication rule (see that folder's `HandOver.md`).

## Why triage is different on Android

madExcept and EurekaLog are Windows-only — on Android an unhandled exception kills the app with NO dialog and NO report. Destructors, `unit FINALIZATION`, `FormPreRelease` do not reliably run (the OS SIGKILLs the process). The only windows into a failure are: logcat, the app's own exception log (`LightCore.ExceptionLogger.pas`), and — for pre-Pascal deaths — the APK layout.

## Classification table

Work top-down; first match wins.

| Evidence signature | Class | Next move |
|---|---|---|
| IDE debugger dialog says **"exception class 10"**; logcat quiet; exception log EMPTY across the episode | **SIGUSR1 — NOT a crash.** `SIGUSR1 = 10` (`c:\Delphi\Delphi 13\source\rtl\posix\android\SignalTypes.inc:88-100`). The Android Runtime uses it for GC checkpoints / JIT stop-the-world; the IDE intercepts it. On Android 14+ (e.g. Android 16 / One UI 8) it can fire every few seconds while scrolling. | Tick **"Ignore this exception type"** on the dialog, Continue. Persists into the `.dproj` `<DebuggerOptions>`. No code change. A raw signal never becomes a Pascal exception, so an empty `RaiseExceptObjProc` log is the PROOF (measured: Orinoco 2026-05-27, zero raises across two class-10 cascades). |
| Exception log has entries (timestamp, class, message, location) | **Pascal exception** | Straight to source — the log line names the raise site. |
| logcat `AndroidRuntime: FATAL EXCEPTION` + Java stack trace | **Uncaught Java-side exception** (JNI callback, intent, service) | Read the Java stack, map the entry point back to the Pascal/JNI call that triggered it. |
| logcat `DEBUG` block: `signal 11 (SIGSEGV)`, `backtrace:`, frames with `base: 0x...`; or IDE frames like `:0000006EDB17BB40 ___lldb_unnamed_symbol52707` | **Native crash in a stripped `.so`** | Symbolicate against the linker `.map` (recipe below). If the faulting frame is in a NON-Delphi `.so` (e.g. `libpdfium.so`), check that binary with `llvm-readelf -S`: has `.symtab` → `ndk-stack` names functions; has `.debug_*` → `llvm-addr2line` gives source lines. |
| App icon shows ~1 s then dies, BEFORE any Pascal log line; logcat may show `UnsatisfiedLinkError: dlopen failed: library "libX.so" not found` | **Deployment failure** | APK layout check (below). Classic cause: a `.so` missing from `lib/arm64-v8a/` or misrouted into `assets\internal` — the ProjectOutput singleton trap. |
| App vanishes; nothing in logcat, exception log empty, no tombstone | **OS kill** (LowMemoryKiller, swipe-from-Recents) or a death before the hooks installed | Not a code crash. Check state persistence instead — `c:\Projects\FMX\CLAUDE.md` → "Android state persistence" (eager-save + `TApplicationEventMessage`). |

## The `.map` symbolication recipe (Delphi `.so` files are stripped)

Delphi-built Android `.so` files carry only `.dynsym` — no `.symtab`, no `.debug_info` (verified empirically 2026-05-25 on `libOrinocoReaderFMX.so`). `ndk-stack` and `llvm-addr2line` therefore resolve NOTHING on them, and Delphi emits no DWARF for ARM64. The linker `.map` is the only path:

1. **Get the right `.map`.** Project Options → Linking → Map file = **Detailed**; the file lands next to the project (~25 MB for a real app). It must come from the SAME build as the running process — offsets shift between builds.
2. **Get the load base.** The logcat `DEBUG` block prints `base: 0x...` per frame; or read `/proc/<pid>/maps` and take the `r-xp` line of your `.so` (`adb shell run-as <pkg> cat /proc/<pid>/maps`, or `ProcMaps-Android.cmd`).
3. **offset = absolute address − load base**, then find the "Publics by Value" symbol with the largest offset ≤ target; the difference is the byte offset INSIDE that routine.

`Tools\MapLookup.ps1` (this skill) automates step 3:

```
MapLookup.ps1 -Map App.map -Address 0x6EDB17BB40 -Base 0x6EDB000000   # runtime frame
MapLookup.ps1 -Map App.map -Offset 0x17BB40                           # already-relative offset
MapLookup.ps1 -Map App.map -Name TFormMain.FormCreate                 # reverse lookup (calibration)
```

**Calibration on first use against a new target:** resolve a KNOWN routine with `-Name`, feed its offset back via `-Offset`, and confirm the same name returns. If a constant difference shows up (segment base convention), pass it as `-Delta`.

NDK tools, for the rare non-Delphi `.so` with retained symbols (NOT in `platform-tools\` next to adb — common confusion):

```
c:\Delphi\Delphi 13\CatalogRepository\AndroidSDK-37.0.59082.6021\ndk\27.1.12297006\ndk-stack.cmd
c:\Delphi\Delphi 13\CatalogRepository\AndroidSDK-37.0.59082.6021\ndk\27.1.12297006\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-addr2line.exe
```

## Pull paths (debug-signed builds only — `run-as` denied otherwise)

- **Exception log** (`LightCore.ExceptionLogger.pas`, writes to `TPath.GetDocumentsPath`): `adb shell run-as <pkg> cat files/<App>-Exceptions.log`
- **Autopilot bridge log** (only `AUTOPILOT` builds): `adb shell run-as <pkg> cat cache/Autopilot/<name>-<pid>.log`
- **APK layout check:** `adb shell pm path <pkg>` → `adb pull <apkPath>` → list the zip (`[IO.Compression.ZipFile]::OpenRead(...)`) and verify `lib/arm64-v8a/` holds every expected `.so` and `assets/internal/` the expected data files.

## Logcat tags that matter for FMX

- `info` — Pascal-side `FMX.Types.Log.d`; the tag is hard-coded in `Androidapi.Log.LOGI`, and the FMX logger service prefixes `FMX: <AppTitle>:` (`FMX.Platform.Logger.Android.pas`).
- `AndroidRuntime:E` — Java FATAL EXCEPTION.
- `DEBUG:E` — native tombstones.
- Standard read filter: `adb logcat -d info:I AndroidRuntime:E DEBUG:E *:S` (capture unfiltered; filter when reading).

## adb

Always Delphi 13's bundled `platform-tools\adb.exe`. An old standalone adb daemon (2014-era installs) reports modern phones as `unauthorized` even after "Allow USB debugging" is accepted — kill it (`taskkill /f /im adb.exe`) and let the bundled one start.
