@echo off
setlocal

:: Check if PowerShell 7 is installed
where pwsh >nul 2>nul
if %errorlevel% neq 0 (
    echo PowerShell 7 not found. Installing...
    curl -o pwsh-setup.msi https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.0-win-x64.msi
    msiexec /i pwsh-setup.msi /quiet /norestart
    echo Installation complete. Please restart your PC if necessary.
    exit /b
)

:: Run PowerShell 7 as Administrator to fetch RAM details
echo Running PowerShell 7...
pwsh -NoProfile -ExecutionPolicy Bypass -Command "$wmi = Get-CimInstance Win32_PhysicalMemory; $currentSpeed = (Get-CimInstance -Class 'Win32_PhysicalMemory' | Select-Object -First 1).ConfiguredClockSpeed; $ddr = if($wmi[0].Speed -ge 4800){'DDR5'} elseif($wmi[0].Speed -ge 2133){'DDR4'} elseif($wmi[0].Speed -ge 1066){'DDR3'} else{'Unknown'}; $ram = $wmi | Select-Object @{Name='Manufacturer';Expression={switch -Regex ($_.Manufacturer) {'Kingston' {'Kingston'}; 'Team|TEAM' {'Team Group'}; default {$_.Manufacturer}}}}, @{Name='Model';Expression={$_.PartNumber.Trim()}}, @{Name='Capacity_GB';Expression={$_.Capacity/1GB}}, @{Name='Max_Speed_MHz';Expression={$_.Speed}}, @{Name='Current_Speed';Expression={$currentSpeed}}, @{Name='Profile_Status';Expression={if($currentSpeed -ge $_.Speed){'XMP/EXPO Active'} else{'Stock/JEDEC'}}}, @{Name='Memory_Type';Expression={$ddr}}, @{Name='Data_Width';Expression={\"$($_.DataWidth) bit\"}}; Write-Host 'System RAM Specifications:' -ForegroundColor Cyan; Write-Host '------------------------' -ForegroundColor Cyan; $totalCapacity = ($ram | Measure-Object -Property Capacity_GB -Sum).Sum; Write-Host \"Total RAM Installed: $totalCapacity GB\" -ForegroundColor Green; Write-Host \"Current Operating Speed: $currentSpeed MHz\"; if ($currentSpeed -ge ($wmi[0].Speed)) {Write-Host ''; Write-Host '*** XMP/EXPO Profile: ACTIVE ***' -ForegroundColor Yellow -BackgroundColor DarkBlue; Write-Host ''} else {Write-Host 'XMP/EXPO Profile: NOT ACTIVE (Running at JEDEC)' -ForegroundColor Yellow}; Write-Host ''; if ($ram) {$ram | Format-Table -AutoSize} else {Write-Host 'No RAM detected!' -ForegroundColor Red}; Write-Host ''; Write-Host ('*' * 40) -ForegroundColor Magenta; Write-Host 'Made with <3 by Witchny' -ForegroundColor Magenta; Write-Host ('*' * 40) -ForegroundColor Magenta; pause"
exit /b
