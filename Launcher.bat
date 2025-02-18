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

:: Check for any version of PowerShell 7 (including RC and Preview)
powershell -NoProfile -Command "$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue; if ($pwsh) { Write-Host $pwsh.Version.Major }" > "%temp%\ps_version.txt"
set /p PS_VERSION=<"%temp%\ps_version.txt"
del "%temp%\ps_version.txt"

if "%PS_VERSION%"=="7" (
    echo PowerShell 7+ detected, proceeding with launch...
    goto LAUNCH
)

:: Only reached if PowerShell 7 is not found
echo PowerShell 7+ not detected. Please download and install from:
echo https://github.com/PowerShell/PowerShell/releases/
echo.
echo Press any key to exit...
pause >nul
exit /b 1

:LAUNCH
:: Download and execute the browser script
echo Downloading MysticToolbox Browser...
pwsh -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; Start-Process pwsh -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '%temp%\MysticBrowser.ps1', 'https://api.github.com/repos/Mystinals/MysticToolbox/contents/Scripts' } catch { Write-Host 'Error: ' + $_.Exception.Message; pause }"

exit
