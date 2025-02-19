@echo off
title MysticToolbox Launcher
mode con: cols=100 lines=30

echo Starting MysticToolbox Launcher...
echo.

:: Run as admin
echo Checking administrative privileges...
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

echo Checking for PowerShell 7...
powershell -NoProfile -Command "$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue; if ($pwsh) { Write-Host 'PS7_FOUND' } else { Write-Host 'PS7_NOT_FOUND' }" > "%temp%\ps_check.txt"
set /p PS_STATUS=<"%temp%\ps_check.txt"
del "%temp%\ps_check.txt"

if not "%PS_STATUS%"=="PS7_FOUND" (
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

echo PowerShell 7 found. Launching browser script...
echo.

pwsh -NoProfile -ExecutionPolicy Bypass -Command "Write-Host 'Downloading Browser script...'; $ErrorActionPreference = 'Stop'; try { $script = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing).Content; $scriptPath = Join-Path $env:TEMP 'Browser.ps1'; Set-Content -Path $scriptPath -Value $script; Write-Host 'Executing Browser script...'; & $scriptPath; Remove-Item $scriptPath } catch { Write-Host ('Error: ' + $_.Exception.Message) -ForegroundColor Red; Read-Host 'Press Enter to exit' }"

if errorlevel 1 (
    echo Error occurred while running the script.
    pause
)

:END
echo Exiting launcher...
timeout /t 3 > nul
