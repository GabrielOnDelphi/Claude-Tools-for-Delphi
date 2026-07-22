---
name: light-bug-Android
description: "Triage a Delphi FMX Android bug/crash from the PC over adb: capture logcat, pull the app's LightCore.ExceptionLogger log via run-as, classify the failure (SIGUSR1 IDE noise / Pascal exception / Java exception / native tombstone / deployment), symbolicate stripped-.so addresses against the linker .map (Tools\\MapLookup.ps1), then root-cause and fix (build via light-compiler, never release). Use when the user says \"/light-bug-Android\", \"the Android app crashes\", \"the app silently disappears on the phone\", \"triage this logcat\", \"exception class 10\", or an FMX bug shows only on Android."
---

# /light-bug-Android — FMX Android crash triage (PC-side, over adb)

When invoked, do this in order. Be terse. Full background knowledge (classification table, .map recipe, paths) is in `Reference - Android crash triage.md` in this skill's folder — read it once at the start.

Constants:

```
ADB = c:\Delphi\Delphi 13\CatalogRepository\AndroidSDK-37.0.59082.6021\platform-tools\adb.exe
CaptureDir = c:\AI\Claude Code\Temp
```

If that `CatalogRepository\AndroidSDK-*` folder does not exist, glob for the actual installed version — the embedded SDK number drifts between Delphi updates.

## Step 0 — Resolve device + package

1. `& $ADB devices` — need at least one device in `device` state. `unauthorized` almost always means an OLD standalone adb daemon (circa 2014) is running and answering instead of the Delphi-bundled one: `taskkill /f /im adb.exe`, then retry with the bundled path.
2. Package name: from the user's words, else grep the project's `.dproj` for `package=` (in `VerInfo_Keys`), else `AndroidManifest.template.xml`. Confirm it is installed: `& $ADB shell pm path <pkg>`.
3. If no project is obvious from the working directory, ask which app.

## Step 1 — Capture the evidence

Pick by situation:

- **Crash already happened, no tail was running:** one-shot dump, unfiltered:
  `& $ADB logcat -d > "$CaptureDir\logcat-<Tag>-dump.txt" 2>&1`
- **Crash is reproducible:** clear first (`& $ADB logcat -b all -c`), start an unfiltered capture in the background, have the human reproduce on the phone (or drive it yourself via the `mcp__autopilot-android__*` tools IF the build has the Autopilot bridge compiled in — `AUTOPILOT` define), then stop and read the capture.
- A human at the machine can instead double-click `c:\Projects\FMX\Bug reporter FMX\Logcat-Android.cmd` (verbs: tail/dump/clear; writes to `$CaptureDir\logcat-<Tag>-latest.txt`).

Capture UNFILTERED. Filter afterwards while reading: the interesting tags are `AndroidRuntime` (Java FATAL EXCEPTION), `DEBUG` (native tombstone), and `info` (Pascal-side `FMX.Types.Log.d`, prefixed `FMX: <AppTitle>:`).

## Step 2 — Pull the app-side exception log

If the app installs `LightCore.ExceptionLogger.pas` (LightSaber apps do — `InstallExceptionLogger('<App>-Exceptions.log')` first line of the DPR):

```
& $ADB shell run-as <pkg> cat files/<App>-Exceptions.log
```

- Works only on debug-signed builds; `run-as` denied on release-signed ones.
- An EMPTY/absent log after a visible "crash" is itself diagnostic — see the SIGUSR1 row in the classification table.
- If the build has the Autopilot bridge, its log is also reachable: `& $ADB shell run-as <pkg> cat cache/Autopilot/<name>-<pid>.log`.

## Step 3 — Classify

Match the evidence against the classification table in the Reference file. Check the SIGUSR1 ("exception class 10") row FIRST — it is IDE noise, not a crash, and needs zero code changes.

## Step 4 — Symbolicate native addresses (only for tombstones / `___lldb_unnamed_symbol` frames)

Full recipe + tool paths in the Reference file. Order by what actually resolves:

1. **addr2line / ndk-stack on the UNSTRIPPED `.so` (primary).** The `.so` deployed in the APK is stripped — use the unstripped build output, or Delphi's retained `*.apk.symbols\lib\<abi>\` copy. `llvm-addr2line` → function + source line; `ndk-stack` → a whole tombstone. `delphi-arm-backtrace` (shadow-cs, GitHub) automates the Delphi-on-ARM flow. Confirm a binary is usable with `llvm-readelf -S` (`.symtab`/`.debug_*` present).
2. **Borland `.map` + `MapLookup.ps1` — LAST RESORT, UNPROVEN.** Only if the `.so` is stripped with no unstripped copy or DWARF anywhere, but you kept the Detailed linker `.map` (Project Options → Linking → Map file = Detailed, SAME build). Public symbols only, no line numbers. Load base from the logcat `DEBUG` block or `/proc/<pid>/maps`, then:
   `& '<this skill folder>\Tools\MapLookup.ps1' -Map <file.map> -Address 0x<frame> -Base 0x<base>`
   First use: calibrate with `-Name <KnownRoutine>`, feed its offset back with `-Offset`; a constant delta → pass as `-Delta`. Not yet validated against a real Delphi ARM `.map`.

## Step 5 — Root cause + fix

- Trace the FULL call chain before touching code (global #Bug-fix rule). Fix the root cause, not the symptom site.
- **Before writing the fix**, run a derailment check on your root-cause conclusion: invoke the `light-task-DerailmentCheck` skill (Skill tool) against the chain you just traced — classify each step VERIFIED / INFERRED / ASSUMED, attack the unverified ones. Mandatory once, and again if Step 6 doesn't clear the symptom or the user pushes back.
- Compile via the **light-compiler agent** only. Note: `delphi-compiler.exe` does not support Android64 — the agent must go through `rsvars.bat` + MSBuild `/p:Platform=Android64`, or verify the shared units on Win64 first.
- **NEVER release.** The user reviews the diff and ships manually.

## Step 6 — Verify on device

Redeploy (IDE F9; or headless `/t:Make;Deploy /p:Platform=Android64` if a `.deployproj` exists — see `c:\Projects\FMX\Compiling FMX projects for cross-platform targets\` Stage 3), clear the buffer, reproduce, confirm the logcat and the exception log stay clean.

## Failure modes

- **`unauthorized` device** — old adb daemon; kill it, use the bundled adb (Step 0).
- **`offline` device** — same cure: `taskkill /f /im adb.exe`, then `& $ADB start-server` and re-check (fixed a real `offline` Nord, 2026-07-22).
- **Empty capture file** — a second `adb logcat` is already attached; kill it or unplug/replug.
- **`run-as` denied** — build not debug-signed; fall back to logcat only.
- **`adb install` says "Success" but the app is absent / `am start` says the activity "does not exist"** — a stale copy on another Android user (Guest / work profile / parallel space) makes `adb install -r` update only THAT user. Install for the foreground user explicitly: `& $ADB install -r --user 0 <apk>` (foreground user = `& $ADB shell am get-current-user`). Seen live 2026-07-22: a copy on user 10 (Guest) hid the user-0 install.
- **No `.map` for Android** — expected, don't chase it: a standard Android64 build emits NO Borland `.map` (the ARM64 link is `ld.lld`, which ignores `DCC_MapFile`; verified 2026-07-22). Symbolicate via addr2line on the UNSTRIPPED `.so` instead (Step 4, option 1).
- **Nothing matches any classification row** — report what WAS captured and stop; do not invent a root cause.

## Notes

- If the bug also reproduces on Windows, prefer the Win64 Debug build + Autopilot bridge / DPT debugger — much faster loop. Reach for the phone only for Android-only bugs.
- `Assert`/`raise` policy, no-swallowed-exceptions, FreeAndNil — the global Delphi rules apply to any fix.
