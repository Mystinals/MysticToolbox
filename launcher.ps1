# Ensure running with appropriate execution policy
if ((Get-ExecutionPolicy) -ne "Bypass") {
    Set-ExecutionPolicy Bypass -Scope Process -Force
}

# Create and switch to temp directory
$tempDir = Join-Path $env:TEMP "MysticToolbox"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
Push-Location $tempDir

try {
    # Download required files
    $baseUrl = "https://raw.githubusercontent.com/Mystinals/MysticToolbox/main"
    $files = @{
        "MTB.exe" = "$baseUrl/binn/MTB.exe"
        "software-list.json" = "$baseUrl/data/software-list.json"
    }

    Write-Host "Downloading required files..." -ForegroundColor Cyan
    foreach ($file in $files.GetEnumerator()) {
        $output = Join-Path $tempDir $file.Key
        Write-Host "  -> $($file.Key)" -ForegroundColor Gray
        Invoke-WebRequest -Uri $file.Value -OutFile $output
    }

    # Run the application
    Write-Host "`nStarting MysticToolbox..." -ForegroundColor Green
    Start-Process -FilePath (Join-Path $tempDir "MTB.exe") -Wait -NoNewWindow
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
finally {
    # Cleanup
    Pop-Location
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
