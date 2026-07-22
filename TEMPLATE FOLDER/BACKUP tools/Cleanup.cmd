@echo off
REM Cleans up build artifacts. Run from the project root folder.
REM TEMPLATE: Review the list below before using! Remove extensions that your project needs.

echo Cleaning build artifacts...

del /s /q *.dcu 2>nul
del /s /q *.exe 2>nul
del /s /q *.dll 2>nul
del /s /q *.map 2>nul
del /s /q *.dsk 2>nul
del /s /q *.drc 2>nul
del /s /q *.res 2>nul
del /s /q *.deployproj 2>nul
del /s /q *.~* 2>nul
del /s /q *.url 2>nul
del /s /q *.lnk 2>nul

echo Done.
