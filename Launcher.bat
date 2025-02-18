@echo off
title MysticToolbox Launcher
mode con: cols=100 lines=30
setlocal EnableDelayedExpansion

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

:: Enhanced PowerShell 7+ detection
:CHECK_PWSH
set "PS7_FOUND="
set "PS7_PATH="

:: Check common installation paths
set "PATHS_TO_CHECK=^
%ProgramFiles%\PowerShell\7\pwsh.exe^
%ProgramFiles(x86)%\PowerShell\7\pwsh.exe^
%LocalAppData%\Microsoft\PowerShell\7\pwsh.exe^
%ProgramFiles%\PowerShell\7-preview\pwsh.exe^
%ChocolateyInstall%\lib\powershell-core\tools\pwsh.exe"

:: Check PATH environment variable
for %%p in (pwsh.exe) do set "PWSH_IN_PATH=%%~$PATH:p"
if defined PWSH_IN_PATH (
    set "PS7_PATH=!PWSH_IN_PATH!"
    goto VERIFY_VERSION
)

:: Check specific paths
for %%p in (%PATHS_TO_CHECK%) do (
    if exist "%%p" (
        set "PS7_PATH=%%p"
        goto VERIFY_VERSION
    )
)

:: If we haven't found PowerShell 7, check if it's in Program Files with any version number
for /f "delims=" %%a in ('dir /b /s /a-d "%ProgramFiles%\pwsh.exe" "%ProgramFiles(x86)%\pwsh.exe" 2^>nul') do (
    set "PS7_PATH=%%a"
    goto VERIFY_VERSION
)

:: If still not found, try Windows Terminal installation path
if exist "%LocalAppData%\Microsoft\WindowsApps\pwsh.exe" (
    set "PS7_PATH=%LocalAppData%\Microsoft\WindowsApps\pwsh.exe"
    goto VERIFY_VERSION
)

goto PWSH_NOT_FOUND

:VERIFY_VERSION
:: Verify that the found PowerShell is version 7 or higher
"!PS7_PATH!" -NoProfile -Command "$PSVersionTable.PSVersion.Major" > "%temp%\ps_version.txt"
set /p PS_VERSION=<"%temp%\ps_version.txt"
del "%temp%\ps_version.txt"

:: Check if version is 7 or higher
if %PS_VERSION% GEQ 7 (
    set "PS7_FOUND=1"
    goto LAUNCH
)

:PWSH_NOT_FOUND
cls
echo PowerShell 7+ not detected. Would you like to:
echo.
echo [1] Download and install PowerShell 7 automatically
echo [2] Download manually from browser
echo [3] Exit
echo.
set /p "CHOICE=Enter your choice (1-3): "

if "%CHOICE%"=="1" (
    echo.
    echo Downloading PowerShell 7 installer...
    
    :: Create PowerShell download script
    echo $ProgressPreference = 'SilentlyContinue' > "%temp%\download_pwsh.ps1"
    echo $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases' >> "%temp%\download_pwsh.ps1"
    echo $latest = $releases ^| Where-Object { $_.tag_name -like 'v7.*' -and -not $_.prerelease } ^| Select-Object -First 1 >> "%temp%\download_pwsh.ps1"
    echo $asset = $latest.assets ^| Where-Object { $_.name -like '*-win-x64.msi' } >> "%temp%\download_pwsh.ps1"
    echo $installerPath = Join-Path $env:TEMP $asset.name >> "%temp%\download_pwsh.ps1"
    echo Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath >> "%temp%\download_pwsh.ps1"
    echo Write-Host "Downloaded to: $installerPath" >> "%temp%\download_pwsh.ps1"
    echo return $installerPath >> "%temp%\download_pwsh.ps1"

    :: Execute download script
    powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\download_pwsh.ps1" > "%temp%\installer_path.txt"
    set /p INSTALLER_PATH=<"%temp%\installer_path.txt"
    del "%temp%\download_pwsh.ps1" "%temp%\installer_path.txt"

    echo.
    echo Installing PowerShell 7...
    msiexec /i "%INSTALLER_PATH%" /qb ENABLE_PSREMOTING=1 ADD_PATH=1
    
    echo.
    echo Installation complete. Press any key to restart the launcher...
    pause >nul
    start "" "%~f0"
    exit
)

if "%CHOICE%"=="2" (
    start https://github.com/PowerShell/PowerShell/releases/
    echo.
    echo After installing, please restart this launcher.
    echo Press any key to exit...
    pause >nul
    exit
)

if "%CHOICE%"=="3" (
    exit
)

goto PWSH_NOT_FOUND

:LAUNCH
:: Set window title with version info
for /f "tokens=*" do set "PS_FULL_VERSION="!PS7_PATH!" -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"" > "%temp%\ps_full_version.txt"
set /p PS_FULL_VERSION=<"%temp%\ps_full_version.txt"
del "%temp%\ps_full_version.txt"
title MysticToolbox (PowerShell %PS_FULL_VERSION%)

:: Download and execute the browser script
"!PS7_PATH!" -NoProfile -Command "$browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; $startInfo = New-Object System.Diagnostics.ProcessStartInfo; $startInfo.FileName = '!PS7_PATH!'; $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File %temp%\MysticBrowser.ps1'; $startInfo.UseShellExecute = $true; $startInfo.Verb = 'runas'; $startInfo.WindowStyle = 'Normal'; [System.Diagnostics.Process]::Start($startInfo)"

:: Clean up and exit
del "%temp%\MysticBrowser.ps1" 2>nul
exit
