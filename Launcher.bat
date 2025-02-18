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

:: Check for PowerShell 7+
powershell -Command "$version = $PSVersionTable.PSVersion.Major; Write-Host $version" > "%temp%\ps_check.txt"
set /p PS_VERSION=<"%temp%\ps_check.txt"
del "%temp%\ps_check.txt"

if %PS_VERSION% LSS 7 (
    echo PowerShell 7+ not detected. Installing...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "winget install --id Microsoft.PowerShell --accept-source-agreements"
    if errorlevel 1 (
        echo Winget installation failed. Trying direct download...
        powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi' -OutFile '%temp%\pwsh7.msi'; Start-Process msiexec.exe -Wait -ArgumentList '/i %temp%\pwsh7.msi /quiet'"
    )
)

:: Download and execute the browser script
powershell -NoProfile -ExecutionPolicy Bypass -Command "$browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; Start-Process pwsh -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '%temp%\MysticBrowser.ps1', 'https://api.github.com/repos/Mystinals/MysticToolbox/contents'"

exit
