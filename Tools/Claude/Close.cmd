@echo off
REM CALLER: Claude runs this ON COMMAND ONLY, as the final step of a task, and ONLY when the user
REM         armed it earlier ("close the window when you're done"). Counterpart to Sleep.cmd.
REM Closes the terminal window hosting this Claude Code session (graceful WM_CLOSE, see the .ps1).
START "" /B powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0close_claude_session_wnd.ps1"
