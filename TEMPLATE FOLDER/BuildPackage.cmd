REM TEMPLATE: Multi-package build in dependency order.
REM Use this when a project has 2+ dependent .dpk packages that must be built in sequence.
REM For a single project, use Build.cmd instead.

@echo off
setlocal enabledelayedexpansion
prompt $p
cls

echo Hint: Build without TESTINSIGHT to enable console output

REM NOTE TO CLAUDE! Do not kill the program! Beep me instead!
REM NOTE TO CLAUDE! When compiling put the dcus in Win32_Debug folder
REM NOTE TO CLAUDE! Documentatio for MsBuild for Delphi: https://docwiki.embarcadero.com/RADStudio/Athens/en/Building_a_Project_Using_an_MSBuild_Command
REM NOTE TO CLAUDE! Invoke from PowerShell tool: cmd /c BuildPackage.cmd
REM NOTE TO CLAUDE! Invoke from Bash tool:       cmd //c BuildPackage.cmd   (double slash escapes MSYS path mangling)
REM NOTE TO CLAUDE! Do NOT translate this script into bash or PowerShell ? keep it as .cmd.

call "c:\Delphi\Delphi 13\bin\rsvars.bat"

set "MSBuild=c:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"

REM Log goes to global Temp folder (not project dir). Use a project-unique filename to avoid collisions.
set "LogFile=c:\AI\Claude Code\Temp\PROJECTNAME_build.log"

REM List packages in dependency order (lowest dependency first).
REM Edit these to point to the actual .dproj files.
set "Project1=c:\Template\Lib1.dproj"
set "Project2=c:\Template\Lib2.dproj"
set "Project3=c:\Template\App.dproj"

echo Build started %time% > !LogFile!

for %%P in ("!Project1!" "!Project2!" "!Project3!") do (
    if not exist %%P (
        echo.
        echo ERROR: Project file not found: %%P
        echo.
        echo Fix: Edit this script and set ProjectN variables to your actual .dproj file paths
        echo.
        exit /b 1
    )
    echo.
    echo Compiling %%~nxP ...
    echo. >> !LogFile!
    echo === %%~nxP === >> !LogFile!
    "!MSBuild!" %%P /t:Clean;Build /p:platform=Win32 /p:Config=Debug >> !LogFile! 2>&1
    if errorlevel 1 (
        echo.
        echo BUILD FAILED at %%~nxP
        echo See !LogFile! for details
        echo Exit code: !errorlevel! >> !LogFile!
        exit /b 1
    )
)

echo Build finished %time% >> !LogFile!
echo Exit code: 0 >> !LogFile!

echo.
echo BUILD OK
