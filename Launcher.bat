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

:: Check if pwsh is available in PATH
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo PowerShell 7+ detected, proceeding...
    goto LAUNCH
)

echo PowerShell 7+ not found, checking Windows Package Manager...
where winget >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Installing PowerShell 7 using winget...
    winget install --id Microsoft.PowerShell --silent --accept-source-agreements
    if %ERRORLEVEL% EQU 0 (
        echo PowerShell 7 installation completed.
        goto LAUNCH
    )
)

echo Unable to install PowerShell 7. Please install it manually from:
echo https://github.com/PowerShell/PowerShell/releases/
pause
exit /b 1

:LAUNCH
:: Download and execute the browser script
echo Downloading MysticToolbox Browser...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; Start-Process pwsh -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '%temp%\MysticBrowser.ps1', 'https://api.github.com/repos/Mystinals/MysticToolbox/contents/Scripts'"

exit
