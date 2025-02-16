# Define the image path
$ImagePath = "C:\Users\Mystic\Downloads\Logo_Blanc_Accent_Orange_Font_GrisAlpha.png"

# Update the registry to set the wallpaper
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $ImagePath

# Refresh the wallpaper immediately
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
[Wallpaper]::SystemParametersInfo(0x0014, 0, $ImagePath, 0x01 -bor 0x02)
