# MysticToolbox Repository Browser
# Version: 1.0

function Get-CenteredString {
    param (
        [string]$String,
        [int]$TotalWidth = $host.UI.RawUI.WindowSize.Width
    )
    $padding = [math]::Max(0, ($TotalWidth - $String.Length) / 2)
    return " " * [math]::Floor($padding) + $String
}

function Get-BoxWidth {
    $windowWidth = $host.UI.RawUI.WindowSize.Width
    return [math]::Min(80, $windowWidth - 4)
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
        $boxWidth = Get-BoxWidth
        $separator = "─".PadRight($boxWidth, '─')
        
        # Header
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Mystic Toolbox") -ForegroundColor Cyan
        Write-Host (Get-CenteredString "PowerShell Version: $($PSVersionTable.PSVersion.ToString())") -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Current Path: $Path") -ForegroundColor Cyan
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        Write-Host ""
        
        # Menu items
        foreach ($i in 0..($items.Count - 1)) {
            $item = $items[$i]
            $prefix = switch ($item.Type) {
                "Parent" { "[..]" }
                "dir" { "[>]" }
                "file" { "(*)" }
            }
            
            $color = switch ($item.Type) {
                "Parent" { 'Gray' }
                "dir" { 'Cyan' }
                "file" { 'Green' }
                default { 'White' }
            }
            
            $itemText = "$prefix $($item.Name)"
            $centeredText = Get-CenteredString $itemText
            
            if ($i -eq $selectedIndex) {
                $textStart = $centeredText.IndexOf($itemText)
                $textLength = $itemText.Length
                Write-Host $centeredText.Substring(0, $textStart) -NoNewline
                Write-Host $centeredText.Substring($textStart, $textLength) -ForegroundColor 'Black' -BackgroundColor 'White' -NoNewline
                Write-Host $centeredText.Substring($textStart + $textLength)
            }
            else {
                Write-Host $centeredText -ForegroundColor $color
            }
        }
        
        Write-Host ""
        # Navigation Controls
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        Write-Host (Get-CenteredString "Navigation Controls") -ForegroundColor Yellow
        Write-Host (Get-CenteredString "↑↓ Move") -ForegroundColor Cyan
        
        # Action Keys
        $actionLine = "Enter Select | Backspace Back | Esc Exit"
        $centeredActionLine = Get-CenteredString $actionLine
        $parts = $actionLine.Split('|').Trim()
        
        $startPos = $centeredActionLine.IndexOf($actionLine)
        Write-Host $centeredActionLine.Substring(0, $startPos) -NoNewline
        
        # Enter Select
        Write-Host "Enter" -ForegroundColor Green -NoNewline
        Write-Host " Select" -ForegroundColor Gray -NoNewline
        Write-Host " | " -ForegroundColor DarkGray -NoNewline
        
        # Backspace Back
        Write-Host "Backspace" -ForegroundColor Yellow -NoNewline
        Write-Host " Back" -ForegroundColor Gray -NoNewline
        Write-Host " | " -ForegroundColor DarkGray -NoNewline
        
        # Esc Exit
        Write-Host "Esc" -ForegroundColor Red -NoNewline
        Write-Host " Exit" -ForegroundColor Gray
        
        Write-Host (Get-CenteredString $separator) -ForegroundColor Cyan
        
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) { $selectedIndex-- }
            }
            40 { # Down arrow
                if ($selectedIndex -lt ($items.Count - 1)) { $selectedIndex++ }
            }
            13 { # Enter
                $selected = $items[$selectedIndex]
                switch ($selected.Type) {
                    "Parent" { Show-Menu -Path $selected.Path }
                    "dir" { Show-Menu -Path $selected.Path }
                    "file" {
                        if ($selected.Name -match '\.ps1$') {
                            Clear-Host
                            Write-Host (Get-CenteredString "─".PadRight(40, '─')) -ForegroundColor Yellow
                            Write-Host (Get-CenteredString "Execute Script?") -ForegroundColor Yellow
                            Write-Host (Get-CenteredString $selected.Name) -ForegroundColor White
                            Write-Host (Get-CenteredString "Press Enter to confirm or Esc to cancel") -ForegroundColor Yellow
                            Write-Host (Get-CenteredString "─".PadRight(40, '─')) -ForegroundColor Yellow
                            
                            $confirm = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            if ($confirm.VirtualKeyCode -eq 13) {
                                Write-Host "`n" + (Get-CenteredString "Downloading and executing $($selected.Name)...") -ForegroundColor Yellow
                                try {
                                    $script = (Invoke-WebRequest -Uri $selected.DownloadUrl -UseBasicParsing).Content
                                    $scriptPath = Join-Path $env:TEMP $selected.Name
                                    Set-Content -Path $scriptPath -Value $script
                                    & $scriptPath
                                    Remove-Item $scriptPath
                                    Write-Host "`n" + (Get-CenteredString "Script executed successfully.") -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "`n" + (Get-CenteredString "Error executing script: $_") -ForegroundColor Red
                                }
                                Write-Host "`n" + (Get-CenteredString "Press any key to continue...")
                                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            }
                        }
                    }
                }
            }
            8 { # Backspace
                if ($Path -ne "Scripts") {
                    $parentPath = $Path -replace '/[^/]+$', ''
                    if ($parentPath -eq "") { $parentPath = "Scripts" }
                    Show-Menu -Path $parentPath
                }
            }
            27 { # Escape
                Clear-Host
                Write-Host (Get-CenteredString "─".PadRight(40, '─')) -ForegroundColor Red
                Write-Host (Get-CenteredString "Exit MysticToolbox?") -ForegroundColor Red
                Write-Host (Get-CenteredString "Press Enter to Exit or Esc to Stay") -ForegroundColor Yellow
                Write-Host (Get-CenteredString "─".PadRight(40, '─')) -ForegroundColor Red
                
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
