@echo off
title MysticToolbox Launcher
mode con: cols=100 lines=30
color 0B

:: Request admin privileges
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

:: Check for PowerShell 7+
powershell -NoProfile -Command "$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue; if ($pwsh) { Write-Host 'PS7_FOUND'; Write-Host $pwsh.Source }" > "%temp%\ps_check.txt"
set /p PS_STATUS=<"%temp%\ps_check.txt"
set /p PS_PATH=<"%temp%\ps_check.txt"
del "%temp%\ps_check.txt"

if not "%PS_STATUS%"=="PS7_FOUND" (
    echo PowerShell 7 or newer is required but not found.
    echo.
    echo Would you like to install PowerShell 7 now? (Y/N)
    choice /C YN /N /M "> "
    if errorlevel 2 goto END
    if errorlevel 1 (
        echo.
        echo Opening PowerShell download page...
        start https://github.com/PowerShell/PowerShell/releases/latest
        echo Please install PowerShell 7 and run this launcher again.
        pause
        goto END
    )
)

:: Set execution policy and launch browser script
echo Setting up environment...
powershell -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force"

:: Download and execute the browser script
echo Launching MysticToolbox...
pwsh -NoProfile -ExecutionPolicy Bypass -Command "$script = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\Browser.ps1' -Value $script.Content; & '%temp%\Browser.ps1'"

:END
exit /b
