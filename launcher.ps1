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
    $baseUrl = "https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/bin/Release/net9.0/win-x64"
    $files = @{
        "MTB.exe" = "$baseUrl/MTB.exe"
        "MTB.dll" = "$baseUrl/MTB.dll"
        "MTB.runtimeconfig.json" = "$baseUrl/MTB.runtimeconfig.json"
        "software-list.json" = "https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/data/software-list.json"
    }
    Write-Host "Downloading required files..." -ForegroundColor Cyan
    
    foreach ($file in $files.GetEnumerator()) {
        $output = Join-Path $tempDir $file.Key
        Write-Host "  -> $($file.Key)" -ForegroundColor Gray
        Write-Host "     URL: $($file.Value)" -ForegroundColor DarkGray
        
        try {
            $response = Invoke-WebRequest -Uri $file.Value -OutFile $output -UseBasicParsing -Verbose
            Write-Host "     Status: $($response.StatusCode)" -ForegroundColor Green
        }
        catch {
            Write-Host "     Error details:" -ForegroundColor Red
            Write-Host "     StatusCode: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            Write-Host "     StatusDescription: $($_.Exception.Response.StatusDescription)" -ForegroundColor Red
            throw
        }
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
