@echo off
setlocal

set "APP_NAME=Screen Alignment Grid"
set "INSTALL_DIR=%~dp0"
set "DESKTOP_LINK=%USERPROFILE%\Desktop\%APP_NAME%.lnk"
set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\%APP_NAME%"

echo This will uninstall %APP_NAME% for the current user.
choice /C YN /N /M "Continue? [Y/N] "
if errorlevel 2 exit /b 0

if exist "%DESKTOP_LINK%" del /f /q "%DESKTOP_LINK%" >nul 2>nul
if exist "%START_MENU_DIR%" rmdir /s /q "%START_MENU_DIR%" >nul 2>nul

echo Removing installed files from:
echo %INSTALL_DIR%

start "" cmd.exe /c "timeout /t 1 /nobreak >nul & cd /d "%TEMP%" & rmdir /s /q "%INSTALL_DIR%""
exit /b 0
