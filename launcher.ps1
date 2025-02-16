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

    # Debugging: Show runtime config contents
    Write-Host "`nRuntime Configuration:" -ForegroundColor Yellow
    Get-Content (Join-Path $tempDir "MTB.runtimeconfig.json")

    # List all downloaded files
    Write-Host "`nDownloaded Files:" -ForegroundColor Yellow
    Get-ChildItem $tempDir

    # Run the application with additional diagnostics
    Write-Host "`nStarting MysticToolbox..." -ForegroundColor Green
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = (Join-Path $tempDir "MTB.exe")
    $processInfo.WorkingDirectory = $tempDir
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true

    $process = New-Process $processInfo
    $output = $process.StandardOutput.ReadToEnd()
    $error = $process.StandardError.ReadToEnd()

    Write-Host "Standard Output:" -ForegroundColor Green
    Write-Host $output
    Write-Host "Standard Error:" -ForegroundColor Red
    Write-Host $error

    $process.WaitForExit()
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
