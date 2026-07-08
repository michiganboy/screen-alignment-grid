@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "INSTALLER=%SCRIPT_DIR%Install Screen Alignment Grid.ps1"

if not exist "%INSTALLER%" (
    echo Could not find "%INSTALLER%".
    echo Keep this installer in the extracted Screen Alignment Grid folder.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%INSTALLER%"

if errorlevel 1 (
    echo.
    echo Installation failed.
    pause
    exit /b 1
)

echo.
pause
