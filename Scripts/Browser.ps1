# MysticToolbox Local Directory Browser
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

function Show-Menu {
    param (
        [string]$Path = $PWD
    )
    
    $items = @()
    if ($Path -ne $PWD) {
        $items += @{
            Name = ".."
            Type = "Parent"
            FullPath = (Split-Path $Path -Parent)
        }
    }
    
    Get-ChildItem $Path -Directory | ForEach-Object {
        $items += @{
            Name = $_.Name
            Type = "Directory"
            FullPath = $_.FullName
        }
    }
    
    Get-ChildItem $Path -Filter "*.ps1" | ForEach-Object {
        if ($_.Name -ne 'local-menu.ps1') {
            $items += @{
                Name = $_.Name
                Type = "Script"
                FullPath = $_.FullName
            }
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
            (Get-CenteredString "+$horizontalLine+"),
            (Get-CenteredString "|$(Get-BoxCenteredText 'MysticToolbox Directory' ($boxWidth - 2))|"),
            (Get-CenteredString "|$(Get-BoxCenteredText "PowerShell Version: $($PSVersionTable.PSVersion.ToString())" ($boxWidth - 2))|"),
            (Get-CenteredString "|$(Get-BoxCenteredText "Current Path: $Path" ($boxWidth - 2))|"),
            (Get-CenteredString "+$horizontalLine+")
        )
        
        foreach ($line in $topBox) {
            Write-Host $line -ForegroundColor 'Cyan'
        }
        
        Write-Host ""
        
        # Display menu items
        foreach ($i in 0..($items.Count - 1)) {
            $item = $items[$i]
            $prefix = switch ($item.Type) {
                "Parent" { "[..]" }
                "Directory" { "[>]" }
                "Script" { "(*)" }
            }
            
            $color = switch ($item.Type) {
                "Parent" { 'Gray' }
                "Directory" { 'Cyan' }
                "Script" { 'Green' }
                default { 'White' }  # Fallback color
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
            (Get-CenteredString "+$horizontalLine+"),
            (Get-CenteredString "|$(Get-BoxCenteredText 'Navigation Controls' ($boxWidth - 2))|"),
            (Get-CenteredString "|$(Get-BoxCenteredText 'UP/DOWN (Move) | Enter (Select) | Backspace (Back) | Esc (Exit)' ($boxWidth - 2))|"),
            (Get-CenteredString "+$horizontalLine+")
        )
        
        foreach ($line in $bottomBox) {
            Write-Host $line -ForegroundColor 'DarkCyan'
        }
        
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
                    "Parent" { Show-Menu -Path $selected.FullPath }
                    "Directory" { Show-Menu -Path $selected.FullPath }
                    "Script" {
                        Clear-Host
                        Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Execute Script?' 38)|") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "|$(Get-BoxCenteredText $selected.Name 38)|") -ForegroundColor White
                        Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Press Enter to confirm or Esc to cancel' 38)|") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                        
                        $confirm = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        if ($confirm.VirtualKeyCode -eq 13) {
                            Write-Host "`n" + (Get-CenteredString "Executing $($selected.Name)...") -ForegroundColor Yellow
                            try {
                                & $selected.FullPath
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
            8 { # Backspace
                if ($Path -ne $PWD) {
                    Show-Menu -Path (Split-Path $Path -Parent)
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