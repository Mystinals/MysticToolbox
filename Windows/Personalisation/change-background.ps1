# Define the image path
$ImagePath = "C:\Users\Mystic\Downloads\Logo_Blanc_Accent_Orange_Font_GrisAlpha.png"

# Ensure the file exists before proceeding
if (-Not (Test-Path $ImagePath)) {
    Write-Host "Error: Image file not found at $ImagePath" -ForegroundColor Red
    exit 1
}

# Set wallpaper in the registry
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $ImagePath

# Set wallpaper style to "Fit" (6) and disable tiling
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value 6
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value 0

# Set background color to black (RGB: 0,0,0)
Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0"

# Apply changes by forcing Windows to reload settings
$signature = @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
Add-Type -TypeDefinition $signature -PassThru | Out-Null
[Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01 -bor 0x02)

# Additional command to force update in Windows 11
Start-Process -FilePath "RUNDLL32.EXE" -ArgumentList "USER32.DLL,UpdatePerUserSystemParameters"

Write-Host "Wallpaper successfully changed to Fit mode with a black background!" -ForegroundColor Green
