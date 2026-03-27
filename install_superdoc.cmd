@echo off
cls
echo SuperDoc is a plugin (MCP) that allows Claude Code to read/write Microsoft Word DocX files.

set PATH=C:\Program Files\nodejs;%PATH%
echo Installing SuperDoc MCP...
call npm install -g @superdoc-dev/mcp
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Global install failed. Trying local install...
    call npm install @superdoc-dev/mcp
)
echo.
echo Done. Press any key to close.
pause >nul
