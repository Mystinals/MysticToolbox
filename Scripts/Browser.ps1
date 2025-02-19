# MysticToolbox Repository Browser
# Version: 1.0

function Get-CenteredString {
    param (
        [string]$String,
        [int]$TotalWidth = $host.UI.RawUI.WindowSize.Width,
        [switch]$NoTrim
    )
    if (-not $NoTrim) {
        # Trim the string if it's longer than the total width
        if ($String.Length -gt $TotalWidth) {
            $String = $String.Substring(0, $TotalWidth - 3) + "..."
        }
    }
    $padding = [math]::Max(0, ($TotalWidth - $String.Length) / 2)
    return " " * [math]::Floor($padding) + $String
}

function Show-Menu {
    param (
        [string]$Path = "Scripts"
    )
    
    $items = @()
    if ($Path -ne "Scripts") {
        $parentPath = $Path -replace '/[^/]+$', ''
        if ($parentPath -eq "") { $parentPath = "Scripts" }
        $items += @{
            Name = ".."
            Type = "Parent"
            Path = $parentPath
            DownloadUrl = $null
        }
    }
    
    try {
        $apiUrl = "https://api.github.com/repos/Mystinals/MysticToolbox/contents/$Path"
        $repoContents = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{
            'Accept' = 'application/vnd.github.v3+json'
        }
        foreach ($item in $repoContents) {
            $items += @{
                Name = $item.name
                Type = $item.type
                Path = $item.path
                DownloadUrl = $item.download_url
            }
        }
    }
    catch {
        Write-Host "Error fetching repository contents: $_" -ForegroundColor Red
    }
    
    $selectedIndex = 0
    $exit = $false
    
    while (-not $exit) {
        Clear-Host
        $width = $host.UI.RawUI.WindowSize.Width
        $separator = "─" * ($width - 2)
        
        # Header section (always at top)
        Write-Host (Get-CenteredString "MysticToolbox") -ForegroundColor Cyan
        Write-Host (Get-CenteredString "PowerShell Version: $($PSVersionTable.PSVersion.ToString())") -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Current Path: $Path") -ForegroundColor Cyan
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        Write-Host ""
        
        # Calculate available space for items
        $windowHeight = $host.UI.RawUI.WindowSize.Height
        $headerHeight = 5  # Title + Version + Path + separator + empty line
        $footerHeight = 4  # Navigation controls + separator + actions
        $availableHeight = $windowHeight - $headerHeight - $footerHeight
        
        # Display items with padding
        $displayedItems = [Math]::Min($items.Count, $availableHeight)
        $startIndex = [Math]::Max(0, [Math]::Min($selectedIndex - [Math]::Floor($availableHeight / 2), $items.Count - $displayedItems))
        
        for ($i = $startIndex; $i -lt [Math]::Min($startIndex + $displayedItems, $items.Count); $i++) {
            $item = $items[$i]
            $prefix = switch ($item.Type) {
                "Parent" { "[..]" }
                "dir" { "[>]" }
                "file" { "(*)" }
            }
            
            $itemText = "$prefix $($item.Name)"
            $centeredText = Get-CenteredString $itemText
            
            if ($i -eq $selectedIndex) {
                $padding = $centeredText.Length - $itemText.Length
                Write-Host ($centeredText.Substring(0, $padding)) -NoNewline
                Write-Host $itemText -ForegroundColor Black -BackgroundColor White
            }
            else {
                $color = switch ($item.Type) {
                    "Parent" { "Gray" }
                    "dir" { "Cyan" }
                    "file" { "Green" }
                    default { "White" }
                }
                Write-Host $centeredText -ForegroundColor $color
            }
        }
        
        # Fill remaining space
        $currentLine = $headerHeight + $displayedItems
        $emptyLines = $windowHeight - $currentLine - $footerHeight
        if ($emptyLines -gt 0) {
            1..$emptyLines | ForEach-Object { Write-Host "" }
        }
        
        # Footer (always at bottom)
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Navigation Controls") -ForegroundColor Yellow
        Write-Host (Get-CenteredString "↑↓ Move") -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Enter Select | Backspace Back | Esc Exit") -ForegroundColor Gray

        # Handle key input
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            }
            40 { # Down arrow
                if ($selectedIndex -lt ($items.Count - 1)) { $selectedIndex++ }
            }
            13 { # Enter
                # ... (rest of the key handling code remains the same)
            }
            8 { # Backspace
                if ($Path -ne "Scripts") {
                    Show-Menu -Path (Split-Path $Path -Parent)
                }
            }
            27 { # Escape
                Clear-Host
                Write-Host (Get-CenteredString $separator) -ForegroundColor Red
                Write-Host (Get-CenteredString "Exit MysticToolbox?") -ForegroundColor Red
                Write-Host (Get-CenteredString "Press Enter to Exit or Esc to Stay") -ForegroundColor Yellow
                Write-Host (Get-CenteredString $separator) -ForegroundColor Red
                
                $exitChoice = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($exitChoice.VirtualKeyCode -eq 13) {
                    Clear-Host
                    exit
                }
            }
        }
    }
}

# Main execution
Show-Menu
