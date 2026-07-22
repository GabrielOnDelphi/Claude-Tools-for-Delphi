# Reference — Delphi FMX Android crash triage

Extracted 2026-07-03 (by Fable 5) from `c:\Projects\FMX\Bug reporter FMX\Crash Reporting Tools for Delphi FMX Android.md` (Sections 3.0 + 6). This file is the canonical copy for the `/light-bug-Android` skill; the source sections get pruned per the no-duplication rule (see that folder's `HandOver.md`).

## Why triage is different on Android

madExcept and EurekaLog are Windows-only — on Android an unhandled exception kills the app with NO dialog and NO report. Destructors, `unit FINALIZATION`, `FormPreRelease` do not reliably run (the OS SIGKILLs the process). The only windows into a failure are: logcat, the app's own exception log (`LightCore.ExceptionLogger.pas`), and — for pre-Pascal deaths — the APK layout.

## Classification table

Work top-down; first match wins.

| Evidence signature | Class | Next move |
|---|---|---|
| IDE debugger dialog says **"exception class 10"**; logcat quiet; exception log EMPTY across the episode | **SIGUSR1 — NOT a crash.** `SIGUSR1 = 10` (`c:\Delphi\Delphi 13\source\rtl\posix\android\SignalTypes.inc:88-100`). ART's SignalCatcher thread handles it (forces a GC + profile save, AOSP `signal_catcher.cc`), usually system-delivered; the IDE intercepts it. On Android 14+ it can fire repeatedly during interactive use. | Tick **"Ignore this exception type"** on the dialog, Continue. Persists in the IDE's GLOBAL options (registry `…\Embarcadero Debuggers\ExceptionCodes\Android64Exceptions`; applies to ALL projects, NOT the `.dproj`). No code change. A raw signal never becomes a Pascal exception, so an empty `RaiseExceptObjProc` log is the PROOF (measured: Orinoco 2026-05-27, zero raises across two class-10 cascades). |
| Exception log has entries (timestamp, class, message, location) | **Pascal exception** | Straight to source — the log line names the raise site. |
| logcat `AndroidRuntime: FATAL EXCEPTION` + Java stack trace | **Uncaught Java-side exception** (JNI callback, intent, service) | Read the Java stack, map the entry point back to the Pascal/JNI call that triggered it. |
| logcat `DEBUG` block: `signal 11 (SIGSEGV)`, `backtrace:`, frames with `base: 0x...`; or IDE frames like `:0000006EDB17BB40 ___lldb_unnamed_symbol52707` | **Native crash in a `.so`** | Symbolicate — addr2line/ndk-stack on the UNSTRIPPED `.so` first, the Borland `.map` only as last resort (recipe below). Check any binary with `llvm-readelf -S`: `.symtab` → `ndk-stack` names functions; `.debug_*` → `llvm-addr2line` gives source lines; only `.dynsym` → stripped. |
| App icon shows ~1 s then dies, BEFORE any Pascal log line; logcat may show `UnsatisfiedLinkError: dlopen failed: library "libX.so" not found` | **Deployment failure** | APK layout check (below). Classic cause: a `.so` missing from `lib/arm64-v8a/` or misrouted into `assets\internal` — the ProjectOutput singleton trap. |
| App vanishes; nothing in logcat, exception log empty, no tombstone | **OS kill** (LowMemoryKiller, swipe-from-Recents) or a death before the hooks installed | Not a code crash. Check state persistence instead — `c:\Projects\FMX\CLAUDE.md` → "Android state persistence" (eager-save + `TApplicationEventMessage`). |

## Symbolicating native addresses (tombstones / `___lldb_unnamed_symbol` frames)

Order the options by what actually resolves — DWARF first, the Borland `.map` only as a last resort. (Book 4 "Crossplatform FMX" → "Debugging Android applications" makes the same point: no standard tool consumes the Delphi-emitted `.map`.)

**1 — addr2line / ndk-stack on the UNSTRIPPED `.so` (primary when available).** The `.so` DEPLOYED in the APK is stripped to `.dynsym` only (verified 2026-05-25: the deployed `libOrinocoReaderFMX.so` had no `.symtab`/`.debug_*` — a `.so` pulled from the running process resolves nothing). But the build output BEFORE deployment stripping — and Delphi's retained `*.apk.symbols\lib\<abi>\` copy when present — can carry symbols/DWARF: `delphi-arm-backtrace` (shadow-cs, GitHub) resolves Delphi ARM stacks by feeding addr2line, so usable symbols exist in at least some build configs (it captures the stack via `TPosixProcEntryList`). Point `llvm-addr2line` (function + source line) or `ndk-stack` (whole tombstone) at that UNSTRIPPED binary, NOT the APK's. The Debug build-output `.so` retains full DWARF (CONFIRMED 2026-07-22, below); other configs (Release/optimized) may differ, so check YOURS first with `llvm-readelf -S` (below). (At runtime, Grijjy ErrorReporting sidesteps this with `_Unwind_Backtrace` + `dladdr` against `.dynsym` — coarse names, no offline files needed.)

```
c:\Delphi\Delphi 13\CatalogRepository\AndroidSDK-37.0.59082.6021\ndk\27.1.12297006\ndk-stack.cmd
c:\Delphi\Delphi 13\CatalogRepository\AndroidSDK-37.0.59082.6021\ndk\27.1.12297006\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-addr2line.exe
```

Check what a `.so` carries first: `llvm-readelf -S lib<X>.so` — `.symtab` → `ndk-stack` names functions; `.debug_*` → `llvm-addr2line` gives source lines; only `.dynsym` → stripped, go to option 2.

**CONFIRMED end-to-end 2026-07-22 (Opus 4.8), Delphi 13 Android64 Debug, real crash.** Both prior `[UNVERIFIED]` flags resolved:
- The unstripped build-output `.so` (`_Android64_Debug\lib<App>.so`, ~69 MB) carries full DWARF (`.debug_info/line/pubnames/str/loc/ranges`); the deployed APK `.so` (`...\lib\arm64-v8a\`, ~39 MB) has `.dynsym` only. So point addr2line at the BUILD-OUTPUT `.so`, never the APK's.
- Worked recipe from a live `EAccessViolation` (Delphi converts the nil-deref SIGSEGV to a Pascal exception and reports the faulting PC, so you often get the address without a tombstone):
  1. `ELFoffset = faultPC − rxBase` where `rxBase` is the `r-xp` mapping start of the `.so` in `& $ADB shell run-as <pkg> cat /proc/<pid>/maps` (file offset there was `0`, so no extra term).
  2. `llvm-addr2line -e <unstripped .so> -f -C -i 0x<ELFoffset>`
  - Live example: PC `0x7D779CB104` − base `0x7D761AD000` = `0x181E104` → `TForm1::btnCrashAVClick` / `MainForm.pas:64` (the exact nil-deref line).

**2 — Borland `.map` + `MapLookup.ps1` (LAST RESORT — and note there is usually NO `.map` on Android).** Verified 2026-07-22: a standard Delphi 13 Android64 build emits NO Borland `.map` even with `DCC_MapFile` set (Publics) — the ARM64 link is `ld.lld`, invoked with no `-Map`, so `DCC_MapFile` is effectively ignored (the `.map` you may find in the project root is the Win64 build's, image base `0x1400…`). So in practice this path has no input on Android; it survives only for the rare case you produced a Borland `.map` some other way. Public symbols ONLY — nearest exported routine, no line numbers, misses locals/inlines. **Never validated against a real Delphi ARM `.map`** (none exists to test) — calibrate before trusting it. Project Options → Linking → Map file = **Detailed** (must be the SAME build as the running process — offsets shift between builds).

- Load base: logcat `DEBUG` prints `base: 0x...` per frame, or `/proc/<pid>/maps` `r-xp` line (`adb shell run-as <pkg> cat /proc/<pid>/maps`, or `ProcMaps-Android.cmd`).
- `offset = absolute address − load base`; the script finds the "Publics by Value" symbol with the largest offset ≤ target.

```
MapLookup.ps1 -Map App.map -Address 0x6EDB17BB40 -Base 0x6EDB000000   # runtime frame
MapLookup.ps1 -Map App.map -Offset 0x17BB40                           # already-relative offset
MapLookup.ps1 -Map App.map -Name TFormMain.FormCreate                 # reverse lookup (calibration)
```

**Calibrate on first use:** resolve a KNOWN routine with `-Name`, feed its offset back via `-Offset`, confirm the same name returns; if a constant difference shows up, pass it as `-Delta`.

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
