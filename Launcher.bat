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

:: Create PowerShell detection script
echo $ErrorActionPreference = 'Stop' > "%temp%\detect_pwsh.ps1"
echo try { >> "%temp%\detect_pwsh.ps1"
echo     $pwshPaths = @() >> "%temp%\detect_pwsh.ps1"
echo     # Method 1: Check PATH >> "%temp%\detect_pwsh.ps1"
echo     $pwshPaths += (Get-Command pwsh -ErrorAction SilentlyContinue).Source >> "%temp%\detect_pwsh.ps1"
echo     # Method 2: Common installation paths >> "%temp%\detect_pwsh.ps1"
echo     $commonPaths = @( >> "%temp%\detect_pwsh.ps1"
echo         "${env:ProgramFiles}\PowerShell\*\pwsh.exe", >> "%temp%\detect_pwsh.ps1"
echo         "${env:ProgramFiles(x86)}\PowerShell\*\pwsh.exe", >> "%temp%\detect_pwsh.ps1"
echo         "${env:LocalAppData}\Microsoft\PowerShell\*\pwsh.exe", >> "%temp%\detect_pwsh.ps1"
echo         "${env:LocalAppData}\Microsoft\WindowsApps\pwsh.exe", >> "%temp%\detect_pwsh.ps1"
echo         "${env:ChocolateyInstall}\lib\powershell-core\tools\pwsh.exe" >> "%temp%\detect_pwsh.ps1"
echo     ) >> "%temp%\detect_pwsh.ps1"
echo     $pwshPaths += Get-ChildItem -Path $commonPaths -ErrorAction SilentlyContinue ^| Select-Object -ExpandProperty FullName >> "%temp%\detect_pwsh.ps1"
echo     # Method 3: Registry check >> "%temp%\detect_pwsh.ps1"
echo     $regPaths = @( >> "%temp%\detect_pwsh.ps1"
echo         'HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions\*', >> "%temp%\detect_pwsh.ps1"
echo         'HKCU:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions\*' >> "%temp%\detect_pwsh.ps1"
echo     ) >> "%temp%\detect_pwsh.ps1"
echo     foreach ($regPath in $regPaths) { >> "%temp%\detect_pwsh.ps1"
echo         if (Test-Path $regPath) { >> "%temp%\detect_pwsh.ps1"
echo             $pwshPaths += (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).InstallLocation >> "%temp%\detect_pwsh.ps1"
echo         } >> "%temp%\detect_pwsh.ps1"
echo     } >> "%temp%\detect_pwsh.ps1"
echo     # Find valid PowerShell 7+ installation >> "%temp%\detect_pwsh.ps1"
echo     $validPwsh = $null >> "%temp%\detect_pwsh.ps1"
echo     foreach ($path in ($pwshPaths ^| Where-Object { $_ -and (Test-Path $_) } ^| Select-Object -Unique)) { >> "%temp%\detect_pwsh.ps1"
echo         try { >> "%temp%\detect_pwsh.ps1"
echo             $version = ^& $path -NoProfile -Command "$PSVersionTable.PSVersion.Major" >> "%temp%\detect_pwsh.ps1"
echo             if ([int]$version -ge 7) { >> "%temp%\detect_pwsh.ps1"
echo                 $validPwsh = $path >> "%temp%\detect_pwsh.ps1"
echo                 break >> "%temp%\detect_pwsh.ps1"
echo             } >> "%temp%\detect_pwsh.ps1"
echo         } catch { continue } >> "%temp%\detect_pwsh.ps1"
echo     } >> "%temp%\detect_pwsh.ps1"
echo     if ($validPwsh) { >> "%temp%\detect_pwsh.ps1"
echo         Write-Host "PWSH_FOUND=$validPwsh" >> "%temp%\detect_pwsh.ps1"
echo         exit 0 >> "%temp%\detect_pwsh.ps1"
echo     } >> "%temp%\detect_pwsh.ps1"
echo     exit 1 >> "%temp%\detect_pwsh.ps1"
echo } catch { >> "%temp%\detect_pwsh.ps1"
echo     Write-Error $_.Exception.Message >> "%temp%\detect_pwsh.ps1"
echo     exit 1 >> "%temp%\detect_pwsh.ps1"
echo } >> "%temp%\detect_pwsh.ps1"

:: Run detection script
powershell -NoProfile -ExecutionPolicy Bypass -File "%temp%\detect_pwsh.ps1" > "%temp%\pwsh_result.txt" 2>&1
set /p PWSH_RESULT=<"%temp%\pwsh_result.txt"
del "%temp%\detect_pwsh.ps1" "%temp%\pwsh_result.txt"

:: Parse result
set "PWSH_PATH="
for /f "tokens=2 delims==" %%a in ("%PWSH_RESULT%") do set "PWSH_PATH=%%a"

if not defined PWSH_PATH (
    cls
    echo PowerShell 7+ not detected. Would you like to:
    echo.
    echo [1] Download and install PowerShell 7 automatically
    echo [2] Download manually from browser
    echo [3] Exit
    echo.
    set /p "CHOICE=Enter your choice (1-3): "

    if "!CHOICE!"=="1" (
        echo.
        echo Downloading PowerShell 7 installer...
        
        :: Download latest stable version
        powershell -NoProfile -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; $ProgressPreference = 'SilentlyContinue'; $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases'; $latest = $releases | Where-Object { $_.tag_name -like 'v7.*' -and -not $_.prerelease } | Select-Object -First 1; $asset = $latest.assets | Where-Object { $_.name -like '*-win-x64.msi' }; $installerPath = Join-Path $env:TEMP $asset.name; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installerPath; Write-Output $installerPath" > "%temp%\installer_path.txt"
        
        set /p INSTALLER_PATH=<"%temp%\installer_path.txt"
        del "%temp%\installer_path.txt"

        echo.
        echo Installing PowerShell 7...
        msiexec /i "!INSTALLER_PATH!" /qb ENABLE_PSREMOTING=1 ADD_PATH=1

        echo.
        echo Installation complete. Press any key to restart the launcher...
        pause >nul
        start "" "%~f0"
        exit
    )

    if "!CHOICE!"=="2" (
        start https://github.com/PowerShell/PowerShell/releases/
        echo.
        echo After installing, please restart this launcher.
        echo Press any key to exit...
        pause >nul
        exit
    )

    if "!CHOICE!"=="3" (
        exit
    )

    goto :eof
)

:: Launch MysticToolbox
title MysticToolbox (PowerShell 7+)
"!PWSH_PATH!" -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; try { $browserScript = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Scripts/Browser.ps1' -UseBasicParsing; Set-Content -Path '%temp%\MysticBrowser.ps1' -Value $browserScript.Content; $startInfo = New-Object System.Diagnostics.ProcessStartInfo; $startInfo.FileName = '!PWSH_PATH!'; $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File %temp%\MysticBrowser.ps1'; $startInfo.UseShellExecute = $true; $startInfo.Verb = 'runas'; $startInfo.WindowStyle = 'Normal'; [System.Diagnostics.Process]::Start($startInfo) } catch { Write-Host $_.Exception.Message; pause }"

:: Cleanup and exit
del "%temp%\MysticBrowser.ps1" 2>nul
exit
