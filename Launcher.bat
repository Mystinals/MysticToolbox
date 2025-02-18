@echo off
title MysticToolbox Launcher
mode con: cols=100 lines=30

:: Run as admin
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

:: Check for PowerShell 7+ availability without attempting installation
powershell -Command "$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue; if ($pwsh) { Write-Host 'PWS7OK' } else { Write-Host 'PWS7NO' }" > "%temp%\ps_check.txt"
set /p PS_STATUS=<"%temp%\ps_check.txt"
del "%temp%\ps_check.txt"

if "%PS_STATUS%"=="PWS7NO" (
    echo PowerShell 7+ not detected. Installing...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "winget install --id Microsoft.PowerShell --accept-source-agreements --disable-interactivity"
)

:: Download and execute the browser script
echo Downloading MysticToolbox Browser...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; Start-Process pwsh -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '%temp%\MysticBrowser.ps1', 'https://api.github.com/repos/Mystinals/MysticToolbox/contents/Scripts'"

exit
