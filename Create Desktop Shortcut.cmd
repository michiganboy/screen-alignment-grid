@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SCRIPT=%SCRIPT_DIR%ScreenAlignmentGrid.ps1"
set "LAUNCHER=%SCRIPT_DIR%Launch Screen Alignment Grid.vbs"
set "ICON=%SCRIPT_DIR%assets\ScreenAlignmentGrid.ico"

if not exist "%SCRIPT%" (
    echo Could not find "%SCRIPT%".
    echo Keep this shortcut creator in the same folder as ScreenAlignmentGrid.ps1.
    pause
    exit /b 1
)

if not exist "%LAUNCHER%" (
    echo Could not find "%LAUNCHER%".
    echo Keep this shortcut creator in the same folder as Launch Screen Alignment Grid.vbs.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$desktop=[Environment]::GetFolderPath('Desktop'); $shortcutPath=Join-Path $desktop 'Screen Alignment Grid.lnk'; $launcher='%LAUNCHER%'; $workdir='%SCRIPT_DIR%'; $icon='%ICON%'; $shell=New-Object -ComObject WScript.Shell; $shortcut=$shell.CreateShortcut($shortcutPath); $shortcut.TargetPath='wscript.exe'; $shortcut.Arguments='""' + $launcher + '""'; $shortcut.WorkingDirectory=$workdir; $shortcut.WindowStyle=7; if (Test-Path $icon) { $shortcut.IconLocation=$icon } else { $shortcut.IconLocation='wscript.exe,0' }; $shortcut.Description='Launch Screen Alignment Grid'; $shortcut.Save(); Write-Host ('Created desktop shortcut: ' + $shortcutPath); Write-Host ('Target launcher: ' + $launcher)"

if errorlevel 1 (
    echo Failed to create the desktop shortcut.
    pause
    exit /b 1
)

echo.
echo Desktop shortcut created or replaced: Screen Alignment Grid
echo You can now launch the tool from your desktop without a visible console window.
pause
