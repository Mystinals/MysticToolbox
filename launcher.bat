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

:: Check for PowerShell 7
powershell -NoProfile -Command "$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue; if ($pwsh) { exit 0 } else { exit 1 }"
if errorlevel 1 (
    echo PowerShell 7+ not detected. Would you like to install it? (Y/N)
    choice /C YN /N /M "> "
    if errorlevel 2 goto END
    if errorlevel 1 (
        start https://github.com/PowerShell/PowerShell/releases/latest
        echo Please install PowerShell 7 and run this launcher again.
        pause
        goto END
    )
)

:: Launch browser script
echo Launching MysticToolbox...
start pwsh -NoProfile -ExecutionPolicy Bypass -Command "& { $script = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing).Content; $scriptPath = Join-Path $env:TEMP 'Browser.ps1'; Set-Content -Path $scriptPath -Value $script; & $scriptPath; Remove-Item $scriptPath }"

:END
exit /b
