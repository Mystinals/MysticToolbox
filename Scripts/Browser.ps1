# MysticToolbox GitHub Browser
# Version: 2.0

param(
    [string]$InitialPath = "https://api.github.com/repos/Mystinals/MysticToolbox/contents"
)

$script:repoCache = @{}
$script:contentCache = @{}

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

function Get-GitHubContent {
    param (
        [string]$Path
    )
    
    if ($script:repoCache.ContainsKey($Path)) {
        return $script:repoCache[$Path]
    }
    
    try {
        $response = Invoke-RestMethod -Uri $Path -Method Get -Headers @{
            "Accept" = "application/vnd.github.v3+json"
        }
        $script:repoCache[$Path] = $response
        return $response
    }
    catch {
        Write-Host "Error fetching GitHub content: $_" -ForegroundColor Red
        return $null
    }
}

function Get-ScriptContent {
    param (
        [string]$DownloadUrl
    )
    
    if ($script:contentCache.ContainsKey($DownloadUrl)) {
        return $script:contentCache[$DownloadUrl]
    }
    
    try {
        $content = Invoke-RestMethod -Uri $DownloadUrl -Method Get
        $script:contentCache[$DownloadUrl] = $content
        return $content
    }
    catch {
        Write-Host "Error downloading script content: $_" -ForegroundColor Red
        return $null
    }
}

function Show-Menu {
    param (
        [string]$Path = $InitialPath,
        [string]$ParentPath = $null
    )
    
    $items = @()
    if ($ParentPath) {
        $items += @{
            Name = ".."
            Type = "Parent"
            Path = $ParentPath
        }
    }
    
    $content = Get-GitHubContent -Path $Path
    if ($null -eq $content) {
        Write-Host "Unable to fetch repository content. Please check your internet connection." -ForegroundColor Red
        return
    }
    
    foreach ($item in $content) {
        if ($item.type -eq "dir") {
            $items += @{
                Name = $item.name
                Type = "Directory"
                Path = $item.url
            }
        }
        elseif ($item.type -eq "file" -and $item.name -like "*.ps1") {
            $items += @{
                Name = $item.name
                Type = "Script"
                Path = $item.download_url
            }
        }
    }
    
    $selectedIndex = 0
    $exit = $false
    
    while (-not $exit) {
        Clear-Host
        $boxWidth = Get-BoxWidth
        $horizontalLine = "-" * ($boxWidth - 2)
        
        # Display header
        $header = @(
            (Get-CenteredString "+$horizontalLine+"),
            (Get-CenteredString "|$(Get-BoxCenteredText 'MysticToolbox GitHub Browser' ($boxWidth - 2))|"),
            (Get-CenteredString "|$(Get-BoxCenteredText "PowerShell Version: $($PSVersionTable.PSVersion.ToString())" ($boxWidth - 2))|"),
            (Get-CenteredString "+$horizontalLine+")
        )
        
        foreach ($line in $header) {
            Write-Host $line -ForegroundColor Cyan
        }
        
        Write-Host ""
        
        # Display items
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
            }
            
            $itemText = "$prefix $($item.Name)"
            $centeredText = Get-CenteredString $itemText
            
            if ($i -eq $selectedIndex) {
                Write-Host $centeredText -ForegroundColor Black -BackgroundColor White
            }
            else {
                Write-Host $centeredText -ForegroundColor $color
            }
        }
        
        # Display footer
        Write-Host ""
        $footer = @(
            (Get-CenteredString "+$horizontalLine+"),
            (Get-CenteredString "|$(Get-BoxCenteredText 'Navigation: ↑↓ (Move) | Enter (Select) | Esc (Exit)' ($boxWidth - 2))|"),
            (Get-CenteredString "+$horizontalLine+")
        )
        
        foreach ($line in $footer) {
            Write-Host $line -ForegroundColor DarkCyan
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
                    "Parent" { Show-Menu -Path $selected.Path }
                    "Directory" { Show-Menu -Path $selected.Path -ParentPath $Path }
                    "Script" {
                        Clear-Host
                        Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Execute Script?' 38)|") -ForegroundColor Yellow
                        Write-Host (Get-CenteredString "|$(Get-BoxCenteredText $selected.Name 38)|") -ForegroundColor White
                        Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Yellow
                        
                        $confirm = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        if ($confirm.VirtualKeyCode -eq 13) {
                            $scriptContent = Get-ScriptContent -DownloadUrl $selected.Path
                            if ($null -ne $scriptContent) {
                                $tempPath = Join-Path $env:TEMP "MysticTemp_$([Guid]::NewGuid()).ps1"
                                Set-Content -Path $tempPath -Value $scriptContent
                                
                                try {
                                    & $tempPath
                                    Write-Host "`nScript executed successfully." -ForegroundColor Green
                                }
                                catch {
                                    Write-Host "`nError executing script: $_" -ForegroundColor Red
                                }
                                finally {
                                    Remove-Item -Path $tempPath -Force
                                }
                                
                                Write-Host "`nPress any key to continue..."
                                $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                            }
                        }
                    }
                }
            }
            27 { # Escape
                Clear-Host
                Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Red
                Write-Host (Get-CenteredString "|$(Get-BoxCenteredText 'Exit Browser?' 38)|") -ForegroundColor Red
                Write-Host (Get-CenteredString "+$('-' * 40)+") -ForegroundColor Red
                
                $exitChoice = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($exitChoice.VirtualKeyCode -eq 13) {
                    $exit = $true
                    Clear-Host
                }
            }
        }
    }
}

# Cleanup function
$cleanup = {
    if (Test-Path "$env:TEMP\MysticBrowser.ps1") {
        Remove-Item "$env:TEMP\MysticBrowser.ps1" -Force
    }
}

# Register cleanup
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $cleanup

# Start the menu
Show-Menu
