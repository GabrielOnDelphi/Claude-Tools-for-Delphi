# Sleep command — force the PC to sleep on command

A counterpart to the automatic task-done **beep**. Where the beep fires by itself (Stop hook), **sleep fires on your command**: you say *"sleep the PC"* / *"sleep now"* / *"/sleep"* and Claude runs `Sleep.cmd`, which puts this machine to sleep a few seconds later — ignoring wake-locks other apps hold.

Status: **working** (rewired 2026-07-22, Opus 4.8). Now drives the user's own tested LightSleep tool in a headless command mode. The earlier hidden-PowerShell approach (`Sleep-PC.ps1`) did **nothing** on this PC and failed silently — it is kept only as a fallback.

## Files

| File | Role |
|------|------|
| `Sleep.cmd` | Entry point Claude runs. `START`s `LightSleep.exe /sleep <delay>` detached and returns at once. Optional arg = grace seconds (`Sleep.cmd 10`, default 4). |
| `Sleep-PC.ps1` | **Fallback only** — the old worker. Waits the grace period, then suspends via the WinForms `SetSuspendState` wrapper. Use only if `LightSleep.exe` is unavailable. |
| `Sleep-README.md` | This file. |

## How it works

`Sleep.cmd` launches the headless command mode of the author's own **LightSleep** tool. Set the `EXE=` line in `Sleep.cmd` to wherever your build of it sits:

```bat
start "" "C:\Projects\LightSleep\LightSleep.exe" /sleep 4
```

`LightSleep.exe /sleep <delay>` waits `<delay>` seconds, then calls `LightVcl.Common.PowerUtils.SystemSleep(TRUE)`:

```
SetSuspendState(bHibernate=FALSE, bForce=TRUE, DisableWakeEvent=FALSE)   // powrprof.dll
```

This is the **same primitive the LightSleep GUI "Test Now" button uses and that the user has tested on Win 7/10/11** — so the CLI path is as reliable as the button. Command mode also handles `/hibernate` and `/shutdown`, and logs every step to `LightSleep-cmd.log` next to the exe (a GUI-subsystem app has no console; the log is the only trail). The command-mode code lives in `LightSleep.dpr` (`RunCommandMode` + helpers) and runs before any GUI/AppData is created — see that project's `CLAUDE.md`.

### Why sleep, not hibernate

The popular one-liner `rundll32.exe powrprof.dll,SetSuspendState 0,1,0` **hibernates instead of sleeping whenever hibernation is enabled** — rundll32 ignores the `0,1,0` text and passes a non-null pointer as `bHibernate`. `SystemSleep` passes `bHibernate=FALSE` explicitly, so it **always sleeps** regardless of the machine's hibernation setting. (Use `LightSleep.exe /hibernate` if you ever want hibernate on purpose.)

### Why it beats wake-locks

On Vista+ `SetSuspendState` does **not** go through the vetoable `PBT_APMQUERYSUSPEND` broadcast, so other apps' `ES_SYSTEM_REQUIRED` wake-locks (Firefox tabs, the Claude desktop app, Steam, OBS…) cannot keep the PC awake — the exact problem LightSleep was built to solve.

### Why detached + a grace delay

If Claude called sleep synchronously, the PC would suspend **mid tool-call** — the turn would never finish, so no confirmation text and no done-beep would reach you. Instead `Sleep.cmd` `START`s LightSleep detached and returns immediately, and LightSleep itself waits the grace delay (default 4 s) before suspending — so the turn completes (and beeps) first, then the display powers off.

## Facts verified (per the "fact-check before asserting" rule)

- `SystemSleep`/`SystemHibernate`/`WinShutDown` signatures and behaviour — `C:\Projects\LightSaber\FrameVCL\LightVcl.Common.PowerUtils.pas` (read 2026-07-22).
- `bForce` "has no effect" on Vista+ (kept for parity) — https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-setsuspendstate
- `rundll32 …,SetSuspendState 0,1,0` hibernates when hibernation is enabled; passing `bHibernate=FALSE` explicitly (as `SystemSleep` does) always sleeps. — https://learn.microsoft.com/en-us/answers/questions/3952334/windows-11-24h2-goes-into-hibernation-mode-instead
- This machine supports Standby (S3); `powercfg /a` confirmed 2026-07-22.

## How to test

**Without sleeping (safe, AFK-friendly):**
1. Run `LightSleep.exe /sleep 3600` (1-hour delay). Confirm **no window** appears and `LightSleep-cmd.log` gets a `Command mode: Sleep requested, delay=3600 s` line.
2. Kill the process (`Stop-Process -Name LightSleep`) before it fires. This exercises the whole chain except the final `SetSuspendState`.

**Real test (do together — this actually sleeps the machine):**
1. Save any open work first.
2. Say **"sleep the PC"** — Claude runs `Sleep.cmd`. Expect: normal reply + done-beep, then the PC sleeps ~4 s later.
3. Wake it and confirm it **slept** (near-instant resume) rather than **hibernated** (slower resume, disk spin).
4. Direct check without Claude: type `! "C:\AI\Claude Code\Tools\Claude\Sleep.cmd"` in the session.

If it does **not** sleep: check `LightSleep-cmd.log` — a `FAILED:` line names the error. Run `powercfg /requests` (admin) to see what is blocking suspend; a kernel-driver veto is outside this tool's control.

## Fallback: the old PowerShell worker

`Sleep-PC.ps1` remains as a fallback for machines without `LightSleep.exe`. It reproduces `SystemSleep(TRUE)` via `[System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $true, $false)` with no external binary. On this PC it failed silently (nothing happened) — the reason the tool was switched to the exe. To use it, point `Sleep.cmd` back at `powershell.exe -File Sleep-PC.ps1 -Detach`.

## To disable

Delete `Sleep.cmd` (and `Sleep-PC.ps1`), and remove the "Sleep command" line from `C:\AI\Claude Code\CLAUDE.md`.
