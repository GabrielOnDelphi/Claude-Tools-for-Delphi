@echo off
setlocal enabledelayedexpansion

:: Get current date and time
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I

:: Parse datetime (format: YYYYMMDDHHMMSS)
set year=%datetime:~0,4%
set month=%datetime:~4,2%
set day=%datetime:~6,2%
set hour=%datetime:~8,2%
set minute=%datetime:~10,2%

:: Build folder name
set foldername=%year%.%month%.%day% - %hour%.%minute%
set backupdir=D:\Backups\Projects_APP_NAME\%foldername%
set sourcedir=c:\Projects\Light_APP_NAME\

:: Define excluded extensions (binary files)
set "excluded=.exe .dcu .map .dll .url .mes .scr .obj .o .bin .pdb .res .bpl .dcp .lib .a .so .dylib .ocx .sys .com .msi .cab .iso .img .zip .rar .7z .tar .gz .bz2 .xz .jar .war .ear .class .pyc .pyo .whl .ico .cur .bmp .jpg .jpeg .png .gif .tiff .mp3 .mp4 .avi .mkv .mov .wmv .flv .wav .ogg .pdf .doc .docx .xls .xlsx .ppt .pptx .db .sqlite .mdb .accdb .html .vsf .deployproj"

:: Track if any errors occurred
set haserrors=0

:: Create backup directory
echo Creating backup folder: %backupdir%
mkdir "%backupdir%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to create backup directory!
    set haserrors=1
    goto :done
)

:: Copy files
echo.
echo Copying files from: %sourcedir%
echo To: %backupdir%
echo.
echo Skipping files over 1MB and binary files...
echo.

call :copyfiles "%sourcedir%" "%backupdir%"

echo.
echo ============================================
if %haserrors%==1 (
    echo Backup completed with errors.
) else (
    echo Backup completed successfully.
)
echo Target folder: %backupdir%
echo ============================================

:done
if %haserrors%==1 (
    echo.
    echo Errors occurred. Press any key to exit...
    pause >nul
)
exit /b

:copyfiles
set "src=%~1"
set "dst=%~2"

:: Create destination directory if it doesn't exist
if not exist "%dst%" mkdir "%dst%"

:: Copy files in current directory
for %%F in ("%src%\*.*") do (
    set "skip=0"
    set "filename=%%~nxF"
    set "fileext=%%~xF"
    set "filesize=%%~zF"

    :: Check file size (1MB = 1048576 bytes)
    if !filesize! GTR 1048576 (
        echo Skipping [too large]: %%F
        set "skip=1"
    )

    :: Check if extension is in excluded list
    if !skip!==0 (
        for %%E in (%excluded%) do (
            if /i "!fileext!"=="%%E" (
                echo Skipping [binary]: %%F
                set "skip=1"
            )
        )
    )

    :: Copy file if not skipped
    if !skip!==0 (
        copy "%%F" "%dst%\" >nul 2>&1
        if errorlevel 1 (
            echo ERROR copying: %%F
            set haserrors=1
        ) else (
            echo Copied: !filename!
        )
    )
)

:: Recursively process subdirectories
for /d %%D in ("%src%\*") do (
    set "subdir=%%~nxD"
    call :copyfiles "%%D" "%dst%\!subdir!"
)

exit /b
