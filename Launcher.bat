@echo off
title MysticToolbox Launcher
setlocal EnableDelayedExpansion

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Running as administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Simple PowerShell 7 detection
where pwsh >nul 2>&1
if %errorLevel% equ 0 (
    goto LAUNCH
)

:: Check Program Files
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH_PATH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto LAUNCH
)

:: Not found - show options
:INSTALL_MENU
cls
echo PowerShell 7+ not found. Please choose:
echo.
echo [1] Install PowerShell 7 automatically
echo [2] Open download page
echo [3] Exit
echo.
set /p "choice=Enter choice (1-3): "

if "%choice%"=="1" (
    echo.
    echo Downloading PowerShell 7...
    powershell -Command "& { $url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi'; $output = '$env:TEMP\pwsh7.msi'; Invoke-WebRequest -Uri $url -OutFile $output; Start-Process msiexec.exe -Wait -ArgumentList '/i ""$output"" /quiet'; Remove-Item $output }"
    echo Installation complete! Restarting...
    timeout /t 2 >nul
    start "" "%~f0"
    exit
)

if "%choice%"=="2" (
    start "" "https://github.com/PowerShell/PowerShell/releases/"
    echo Please restart this launcher after installing.
    pause
    exit
)

if "%choice%"=="3" (
    exit
)

goto INSTALL_MENU

:LAUNCH
pwsh -NoProfile -Command "$browserScript = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1'); Set-Content -Path '$env:TEMP\browser.ps1' -Value $browserScript; Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$env:TEMP\browser.ps1' -Verb RunAs"
exit
