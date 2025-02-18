@echo off
setlocal enabledelayedexpansion
title MysticToolbox Launcher

:: Create a temporary PowerShell script to check version
echo $version = $PSVersionTable.PSVersion.Major > "%temp%\check_version.ps1"
echo if ($version -ge 7) { exit 0 } else { exit 1 } >> "%temp%\check_version.ps1"

:: Try to run pwsh directly first
pwsh -NoProfile -File "%temp%\check_version.ps1" >nul 2>&1
if %errorlevel% equ 0 (
    del "%temp%\check_version.ps1"
    goto START_BROWSER
)

:: If that failed, check common installation paths
set "paths=^
%ProgramFiles%\PowerShell\7\pwsh.exe;^
%ProgramFiles(x86)%\PowerShell\7\pwsh.exe;^
%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe"

for %%p in ("%paths:;=";"%") do (
    if exist %%p (
        "%%~p" -NoProfile -File "%temp%\check_version.ps1" >nul 2>&1
        if !errorlevel! equ 0 (
            set "PWSH_PATH=%%~p"
            del "%temp%\check_version.ps1"
            goto START_BROWSER
        )
    )
)

del "%temp%\check_version.ps1"

:: PowerShell 7 not found - show menu
cls
echo PowerShell 7+ not found. Choose an option:
echo.
echo 1. Install PowerShell 7 automatically
echo 2. Open download page in browser
echo 3. Exit
echo.
choice /c 123 /n /m "Enter your choice (1-3): "

if errorlevel 3 goto :eof
if errorlevel 2 (
    start "" "https://github.com/PowerShell/PowerShell/releases/"
    echo.
    echo Please restart this launcher after installing PowerShell 7.
    pause
    goto :eof
)

:: Automatic installation
cls
echo Installing PowerShell 7...
echo.

:: Download using Windows built-in tools
powershell -Command "& {$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi' -OutFile '%temp%\pwsh7.msi'}"

if exist "%temp%\pwsh7.msi" (
    :: Install silently
    msiexec /i "%temp%\pwsh7.msi" /qb ENABLE_PSREMOTING=1 ADD_PATH=1
    del "%temp%\pwsh7.msi"
    
    echo.
    echo Installation complete! Press any key to restart the launcher...
    pause >nul
    start "" "%~f0"
    exit
) else (
    echo Failed to download PowerShell 7 installer.
    echo Please try downloading manually.
    pause
    exit /b 1
)

:START_BROWSER
:: Launch the browser script
if defined PWSH_PATH (
    "!PWSH_PATH!"
) else (
    pwsh
) -NoProfile -Command "$ProgressPreference='SilentlyContinue'; try { $script = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1'); Set-Content -Path '$env:TEMP\browser.ps1' -Value $script; Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$env:TEMP\browser.ps1' -Verb RunAs } catch { Write-Host $_.Exception.Message; pause }"

exit /b
