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

:: Enhanced PowerShell 7 detection
echo $found = $false > "%temp%\check_pwsh.ps1"
echo $paths = @( >> "%temp%\check_pwsh.ps1"
echo     "$env:ProgramFiles\PowerShell\7\pwsh.exe", >> "%temp%\check_pwsh.ps1"
echo     "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe", >> "%temp%\check_pwsh.ps1"
echo     "$env:LocalAppData\Microsoft\PowerShell\7\pwsh.exe", >> "%temp%\check_pwsh.ps1"
echo     "$env:LocalAppData\Microsoft\WindowsApps\pwsh.exe" >> "%temp%\check_pwsh.ps1"
echo ) >> "%temp%\check_pwsh.ps1"
echo foreach ($path in $paths) { >> "%temp%\check_pwsh.ps1"
echo     if (Test-Path $path) { >> "%temp%\check_pwsh.ps1"
echo         $found = $true >> "%temp%\check_pwsh.ps1"
echo         break >> "%temp%\check_pwsh.ps1"
echo     } >> "%temp%\check_pwsh.ps1"
echo } >> "%temp%\check_pwsh.ps1"
echo if (-not $found) { >> "%temp%\check_pwsh.ps1"
echo     try { >> "%temp%\check_pwsh.ps1"
echo         $pwsh = Get-Command pwsh -ErrorAction Stop >> "%temp%\check_pwsh.ps1"
echo         $found = $true >> "%temp%\check_pwsh.ps1"
echo     } catch { } >> "%temp%\check_pwsh.ps1"
echo } >> "%temp%\check_pwsh.ps1"
echo if ($found) { Write-Host "FOUND" } >> "%temp%\check_pwsh.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\check_pwsh.ps1" > "%temp%\pwsh_result.txt"
set /p PWSH_RESULT=<"%temp%\pwsh_result.txt"
del "%temp%\check_pwsh.ps1" "%temp%\pwsh_result.txt"

if "%PWSH_RESULT%"=="FOUND" (
    echo PowerShell 7+ detected, proceeding with launch...
    goto LAUNCH
)

:: Show interactive menu for installation
cls
echo PowerShell 7+ not detected. Choose an option:
echo.
echo [1] Install PowerShell 7 automatically
echo [2] Open download page
echo [3] Exit
echo.
choice /c 123 /n /m "Enter choice (1-3): "

if errorlevel 3 exit /b
if errorlevel 2 (
    start "" "https://github.com/PowerShell/PowerShell/releases/"
    echo.
    echo Please restart this launcher after installing PowerShell 7.
    pause
    exit /b
)

:: Automatic installation
echo.
echo Downloading PowerShell 7...
powershell -NoProfile -Command "& { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi' -OutFile '$env:TEMP\pwsh7.msi' }"
echo Installing...
start /wait msiexec /i "%temp%\pwsh7.msi" /qb ENABLE_PSREMOTING=1 ADD_PATH=1
del "%temp%\pwsh7.msi"
echo.
echo Installation complete! Press any key to restart...
pause >nul
start "" "%~f0"
exit /b

:LAUNCH
:: Download and execute the browser script silently
powershell -NoProfile -Command "$browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; $startInfo = New-Object System.Diagnostics.ProcessStartInfo; $startInfo.FileName = 'pwsh.exe'; $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File %temp%\MysticBrowser.ps1 https://api.github.com/repos/Mystinals/MysticToolbox/contents/Scripts'; $startInfo.UseShellExecute = $true; $startInfo.Verb = 'runas'; $startInfo.WindowStyle = 'Normal'; [System.Diagnostics.Process]::Start($startInfo)"

:: Close this window immediately
(goto) 2>nul & del "%~f0"
