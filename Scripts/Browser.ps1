# MysticToolbox Enhanced Directory Browser
# Version: 2.0

using namespace System.Management.Automation.Host

# Configuration
$script:config = @{
    MaxWidth = 100
    MinWidth = 60
    HeaderColor = 'Cyan'
    FooterColor = 'DarkCyan'
    FolderColor = 'Cyan'
    ScriptColor = 'Green'
    HighlightFg = 'Black'
    HighlightBg = 'White'
    ErrorColor = 'Red'
    SuccessColor = 'Green'
}

# Improved string centering with caching
$script:centerCache = @{}
function Get-CenteredString {
    param (
        [string]$String,
        [int]$TotalWidth = $host.UI.RawUI.WindowSize.Width
    )
    
    $cacheKey = "$String|$TotalWidth"
    if ($script:centerCache.ContainsKey($cacheKey)) {
        return $script:centerCache[$cacheKey]
    }
    
    $padding = [math]::Max(0, ($TotalWidth - $String.Length) / 2)
    $centeredString = " " * [math]::Floor($padding) + $String
    $script:centerCache[$cacheKey] = $centeredString
    return $centeredString
}

# Smart box sizing with window adaptation
function Get-BoxDimensions {
    $windowWidth = $host.UI.RawUI.WindowSize.Width
    $width = [math]::Min($script:config.MaxWidth, 
                         [math]::Max($script:config.MinWidth, $windowWidth - 4))
    return @{
        Width = $width
        HorizontalLine = "-" * ($width - 2)
    }
}

# Enhanced menu item rendering
function Show-MenuItem {
    param (
        [hashtable]$Item,
        [bool]$IsSelected,
        [int]$Index
    )
    
    $prefix = switch ($Item.Type) {
        "Parent" { "↑ " }
        "Directory" { "▶ " }
        "Script" { "⚡ " }
        default { "  " }
    }
    
    $shortcut = if ($Index -lt 10) { "[$Index] " } else { "    " }
    $itemText = "$shortcut$prefix$($Item.Name)"
    $centeredText = Get-CenteredString $itemText
    
    if ($IsSelected) {
        $textStart = $centeredText.IndexOf($itemText)
        Write-Host $centeredText.Substring(0, $textStart) -NoNewline
        Write-Host $centeredText.Substring($textStart, $itemText.Length) `
            -ForegroundColor $script:config.HighlightFg `
            -BackgroundColor $script:config.HighlightBg -NoNewline
        Write-Host $centeredText.Substring($textStart + $itemText.Length)
    }
    else {
        $color = switch ($Item.Type) {
            "Parent" { 'Gray' }
            "Directory" { $script:config.FolderColor }
            "Script" { $script:config.ScriptColor }
            default { 'White' }
        }
        Write-Host $centeredText -ForegroundColor $color
    }
}

# Improved script execution with progress and error handling
function Invoke-ScriptSafely {
    param (
        [string]$ScriptPath,
        [string]$ScriptName
    )
    
    $progressBar = @('⣾','⣽','⣻','⢿','⡿','⣟','⣯','⣷')
    $progressIndex = 0
    $job = Start-Job -ScriptBlock {
        param($path)
        & $path
    } -ArgumentList $ScriptPath
    
    while ($job.State -eq 'Running') {
        Write-Host "`r$($progressBar[$progressIndex]) Executing $ScriptName..." -NoNewline
        $progressIndex = ($progressIndex + 1) % $progressBar.Length
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "`r" -NoNewline
    
    $result = Receive-Job $job
    Remove-Job $job
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host (Get-CenteredString "✓ Script executed successfully") -ForegroundColor $script:config.SuccessColor
    }
    else {
        Write-Host (Get-CenteredString "✗ Error executing script: $result") -ForegroundColor $script:config.ErrorColor
    }
}

# Main menu function with enhanced navigation
function Show-Menu {
    param (
        [string]$Path = $PWD,
        [int]$StartIndex = 0
    )
    
    $items = @()
    if ($Path -ne $PWD) {
        $items += @{
            Name = ".."
            Type = "Parent"
            FullPath = (Split-Path $Path -Parent)
        }
    }
    
    # Fast directory scanning
    $childItems = Get-ChildItem $Path -Directory, -File -Filter "*.ps1" |
                 Where-Object { $_.Name -ne 'local-menu.ps1' }
    
    $items += $childItems | ForEach-Object {
        @{
            Name = $_.Name
            Type = if ($_.PSIsContainer) { "Directory" } else { "Script" }
            FullPath = $_.FullName
        }
    }
    
    $selectedIndex = $StartIndex
    $pageSize = $host.UI.RawUI.WindowSize.Height - 12  # Account for header/footer
    $currentPage = [math]::Floor($selectedIndex / $pageSize)
    
    while ($true) {
        Clear-Host
        $dimensions = Get-BoxDimensions
        
        # Header
        Write-Host (Get-CenteredString "+$($dimensions.HorizontalLine)+") -ForegroundColor $script:config.HeaderColor
        Write-Host (Get-CenteredString "|  MysticToolbox Directory Browser  |") -ForegroundColor $script:config.HeaderColor
        Write-Host (Get-CenteredString "| Path: $($Path.Split('\')[-1]) |") -ForegroundColor $script:config.HeaderColor
        Write-Host (Get-CenteredString "+$($dimensions.HorizontalLine)+") -ForegroundColor $script:config.HeaderColor
        Write-Host ""
        
        # Items with pagination
        $startIdx = $currentPage * $pageSize
        $endIdx = [math]::Min($startIdx + $pageSize, $items.Count)
        
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            Show-MenuItem -Item $items[$i] -IsSelected ($i -eq $selectedIndex) -Index $i
        }
        
        # Footer with pagination info
        if ($items.Count -gt $pageSize) {
            Write-Host (Get-CenteredString "Page $(($currentPage + 1)) of $([math]::Ceiling($items.Count / $pageSize))") -ForegroundColor $script:config.FooterColor
        }
        
        Write-Host (Get-CenteredString "+$($dimensions.HorizontalLine)+") -ForegroundColor $script:config.FooterColor
        Write-Host (Get-CenteredString "| ↑↓ Navigate | Enter Select | Esc Back | Q Quit |") -ForegroundColor $script:config.FooterColor
        Write-Host (Get-CenteredString "+$($dimensions.HorizontalLine)+") -ForegroundColor $script:config.FooterColor
        
        # Handle input
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { # Up
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    $currentPage = [math]::Floor($selectedIndex / $pageSize)
                }
            }
            40 { # Down
                if ($selectedIndex -lt ($items.Count - 1)) {
                    $selectedIndex++
                    $currentPage = [math]::Floor($selectedIndex / $pageSize)
                }
            }
            33 { # Page Up
                $selectedIndex = [math]::Max(0, $selectedIndex - $pageSize)
                $currentPage = [math]::Floor($selectedIndex / $pageSize)
            }
            34 { # Page Down
                $selectedIndex = [math]::Min($items.Count - 1, $selectedIndex + $pageSize)
                $currentPage = [math]::Floor($selectedIndex / $pageSize)
            }
            13 { # Enter
                $selected = $items[$selectedIndex]
                switch ($selected.Type) {
                    "Parent" { Show-Menu -Path $selected.FullPath }
                    "Directory" { Show-Menu -Path $selected.FullPath }
                    "Script" {
                        Clear-Host
                        Write-Host (Get-CenteredString "Execute $($selected.Name)?") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "Press Enter to confirm or Esc to cancel") -ForegroundColor Yellow
                        
                        if ($host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 13) {
                            Invoke-ScriptSafely -ScriptPath $selected.FullPath -ScriptName $selected.Name
                            Write-Host "`nPress any key to continue..."
                            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        }
                    }
                }
            }
            27 { # Escape
                if ($Path -ne $PWD) {
                    Show-Menu -Path (Split-Path $Path -Parent)
                }
                else {
                    Clear-Host
                    Write-Host (Get-CenteredString "Exit MysticToolbox?") -ForegroundColor Red
                    Write-Host (Get-CenteredString "Press Enter to confirm or Esc to cancel") -ForegroundColor Yellow
                    
                    if ($host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode -eq 13) {
                        Clear-Host
                        exit
                    }
                }
            }
            81 { # Q key
                Clear-Host
                exit
            }
            default {
                # Number key navigation (1-9)
                if ($key.VirtualKeyCode -ge 49 -and $key.VirtualKeyCode -le 57) {
                    $index = $key.VirtualKeyCode - 49
                    if ($index -lt $items.Count) {
                        $selectedIndex = $index
                    }
                }
            }
        }
    }
}

# Entry point with error handling
try {
    Show-Menu
}
catch {
    Write-Host "`nError: $_" -ForegroundColor $script:config.ErrorColor
    Write-Host "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
