@echo off
REM  Forces this PC to SLEEP a few seconds from now, then returns immediately.
REM  CALLER: Claude Code on user command ("sleep the PC" / "sleep now" / "/sleep").
REM          Also runnable by hand or via  ! Tools\Claude\Sleep.cmd
REM
REM  HOW IT WORKS (rewired 2026-07-22):
REM    This now drives the user's own, battle-tested LightSleep tool in its headless command mode:
REM        LightSleep.exe /sleep <delay>
REM    LightSleep waits <delay> seconds, then calls LightVcl.Common.PowerUtils.SystemSleep(TRUE) -
REM    the SAME SetSuspendState primitive the LightSleep GUI "Test Now" button uses and that is
REM    verified working on this machine. It writes a trail to LightSleep-cmd.log next to the exe.
REM
REM    We launch it with START so this wrapper (and Claude's turn + task-done beep) return AT ONCE;
REM    the detached LightSleep then waits the grace delay and suspends. The grace period lets the
REM    final output + beep flush BEFORE the display powers off.
REM
REM  WHY the change: the previous approach (Sleep-PC.ps1 - a hidden detached PowerShell calling the
REM    WinForms SetSuspendState wrapper) did NOTHING on this PC and failed silently. Sleep-PC.ps1 is
REM    kept in this folder as a documented fallback only. See Sleep-README.md.
REM
REM  Usage:   Sleep.cmd            (default grace = 4 s)
REM           Sleep.cmd 10         (override grace, seconds)
setlocal
set "DELAY=%~1"
if "%DELAY%"=="" set "DELAY=4"

REM  SET THIS to wherever your own LightSleep.exe is built.
set "EXE=C:\Projects\LightSleep\LightSleep.exe"
if not exist "%EXE%" (
  echo ERROR: LightSleep.exe not found at "%EXE%".
  echo Edit the EXE= line in this file to point at your own build of LightSleep.dproj,
  echo or run Sleep-PC.ps1 as a fallback.
  endlocal
  exit /b 1
)

start "" "%EXE%" /sleep %DELAY%
endlocal
