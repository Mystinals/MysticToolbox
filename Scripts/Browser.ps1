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

function Get-BoxCenteredText {
    param (
        [string]$Text,
        [int]$Width
    )
    $padding = [math]::Max(0, ($Width - $Text.Length) / 2)
    return (" " * [math]::Floor($padding)) + $Text + (" " * [math]::Ceiling($padding))
}

function Get-RepoContents {
    param (
        [string]$Path = "Scripts"
    )
    
    try {
        $apiUrl = "https://api.github.com/repos/Mystinals/MysticToolbox/contents/$Path"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{
            'Accept' = 'application/vnd.github.v3+json'
        }
        return $response
    }
    catch {
        Write-Host "Error fetching repository contents: $_" -ForegroundColor Red
        return @()
    }
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
    
    $repoContents = Get-RepoContents -Path $Path
    foreach ($item in $repoContents) {
        $items += @{
            Name = $item.name
            Type = $item.type
            Path = $item.path
            DownloadUrl = $item.download_url
        }
    }
    
    $selectedIndex = 0
    $exit = $false
    
    while (-not $exit) {
        Clear-Host
        $boxWidth = Get-BoxWidth
        $horizontalLine = "-" * ($boxWidth - 2)
        
        # Display top box
        $topBox = @(
            (Get-CenteredString "─".PadRight($boxWidth, '─')),
            (Get-CenteredString (Get-BoxCenteredText 'Mystic Toolbox' ($boxWidth))),
            (Get-CenteredString (Get-BoxCenteredText "PowerShell Version: $($PSVersionTable.PSVersion.ToString())" ($boxWidth))),
            (Get-CenteredString (Get-BoxCenteredText "Current Path: $Path" ($boxWidth))),
            (Get-CenteredString "─".PadRight($boxWidth, '─'))
        )
        
        foreach ($line in $topBox) {
            Write-Host $line -ForegroundColor Cyan
        }
        
        Write-Host ""
        
        # Display menu items
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
        
        # Display bottom box
        Write-Host ""
        $bottomBox = @(
            (Get-CenteredString "─".PadRight($boxWidth, '─')),
            (Get-CenteredString (Get-BoxCenteredText 'Navigation Controls' ($boxWidth))),
            (Get-CenteredString (Get-BoxCenteredText "$([char]0x2191)$([char]0x2193) Move" ($boxWidth))),
            (Get-CenteredString (Get-BoxCenteredText "Enter Select | Backspace Back | Esc Exit" ($boxWidth))),
            (Get-CenteredString "─".PadRight($boxWidth, '─'))
        )
        
        # Display navigation controls with colors
        Write-Host $bottomBox[0] -ForegroundColor DarkCyan
        Write-Host $bottomBox[1] -ForegroundColor Yellow
        
        # Split and color the arrow keys
        $arrowLine = $bottomBox[2]
        Write-Host $arrowLine.Substring(0, $arrowLine.IndexOf('Move')) -ForegroundColor Cyan -NoNewline
        Write-Host 'Move' -ForegroundColor White
        
        # Split and color the action keys
        $actionLine = $bottomBox[3]
        Write-Host (Get-CenteredString "Enter") -ForegroundColor Green -NoNewline
        Write-Host " Select | " -ForegroundColor Gray -NoNewline
        Write-Host "Backspace" -ForegroundColor Yellow -NoNewline
        Write-Host " Back | " -ForegroundColor Gray -NoNewline
        Write-Host "Esc" -ForegroundColor Red -NoNewline
        Write-Host " Exit" -ForegroundColor Gray
        
        Write-Host $bottomBox[4] -ForegroundColor DarkCyan
        
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
                            Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                            Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Execute Script?' 38)|") -ForegroundColor Yellow
                            Write-Host (Get-CenteredString "|$(Get-BoxCenteredText $selected.Name 38)|") -ForegroundColor White
                            Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Press Enter to confirm or Esc to cancel' 38)|") -ForegroundColor Yellow
                            Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                            
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
                Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Red
                Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Exit MysticToolbox?' 38)|") -ForegroundColor Red
                Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Press Enter to Exit or Esc to Stay' 38)|") -ForegroundColor Yellow
                Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Red
                
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
