# Software Installation Menu
Add-Type -AssemblyName System.Windows.Forms
Add-Type -MemberDefinition @"
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, int mode);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr GetStdHandle(int handle);
"@ -Name a -Namespace w

# Disable console quick edit mode to prevent flickering
$handle = [w.a]::GetStdHandle(-11) # STD_OUTPUT_HANDLE
[w.a]::SetConsoleMode($handle, 0x0080) # ENABLE_MOUSE_INPUT

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "Gray"
Clear-Host

$script:consoleWidth = $Host.UI.RawUI.WindowSize.Width
$script:consoleHeight = $Host.UI.RawUI.WindowSize.Height
$script:viewportTop = 0  # Track scrolling position
$script:itemsPerPage = $consoleHeight - 8  # Reserve space for header and footer

# Use temp directory for downloaded files
$tempDir = [System.IO.Path]::GetTempPath()
$jsonPath = Join-Path $tempDir "software-list.json"
$scriptPath = Join-Path $tempDir "software-list.json"

# Read and parse the JSON file
try {
    # GitHub raw file URLs
    $jsonUrl = "https://raw.githubusercontent.com/Mystinals/MysticToolbox/main/Windows/Softwares/software-list.json"
    
    # Download JSON file
    Invoke-WebRequest -Uri $jsonUrl -OutFile $jsonPath -ErrorAction Stop

    $jsonContent = Get-Content -Path $jsonPath -Raw -ErrorAction Stop
    $jsonData = $jsonContent | ConvertFrom-Json

    # Flatten sections into software array with section information
    $software = @()
    $totalSections = 0
    foreach ($section in $jsonData.sections) {
        $totalSections++
        foreach ($app in $section.software) {
            $software += @{
                Name = $app.name
                ID = $app.id
                Section = $section.name
                Selected = $false
                Action = $null
                Status = "Unknown"
                LastInstallStatus = $null
                ErrorMessage = $null
            }
        }
    }
} catch {
    Write-Host "Error reading software list: $_" -ForegroundColor Red
    Write-Host "Unable to download software-list.json" -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

function Draw-Header {
    $title = "Software Installation Menu"
    $lineWidth = [Math]::Min($consoleWidth - 4, 80)
    $leftPadding = [math]::Floor(($consoleWidth - $lineWidth) / 2)
    
    # Use standard ASCII characters instead of Unicode
    $line = "-" * [math]::Floor(($lineWidth - $title.Length - 4) / 2) + "| " + $title + " |" + "-" * [math]::Ceiling(($lineWidth - $title.Length - 4) / 2)

    $Host.UI.RawUI.CursorPosition = @{X=$leftPadding; Y=1}
    Write-Host $line -ForegroundColor Cyan
}

function Draw-Footer {
    param (
        [int]$row,
        [int]$totalItems,
        [int]$viewportTop,
        [int]$itemsPerPage
    )

    $lineWidth = [Math]::Min($consoleWidth - 4, 80)
    $leftPadding = [math]::Floor(($consoleWidth - $lineWidth) / 2)
    $line = "-" * $lineWidth

    $Host.UI.RawUI.CursorPosition = @{X=0; Y=$consoleHeight-4}
    Write-Host (" " * $leftPadding) -NoNewline
    Write-Host $line -ForegroundColor Cyan

    # Controls
    $controls = @(
        @{ Text = "[Up/Down] Navigate"; Color = "Gray" }
        @{ Text = "[i] Install"; Color = "Green" }
        @{ Text = "[u] Uninstall"; Color = "Red" }
        @{ Text = "[r] Refresh"; Color = "Yellow" }
        @{ Text = "[Enter] Process"; Color = "Gray" }
        @{ Text = "[Esc] Exit"; Color = "Gray" }
    )

    $totalLength = ($controls | ForEach-Object { $_.Text.Length } | Measure-Object -Sum).Sum
    $spacing = [math]::Floor(($lineWidth - $totalLength) / ($controls.Count + 1))

    $Host.UI.RawUI.CursorPosition = @{X=$leftPadding; Y=$consoleHeight-2}
    foreach ($control in $controls) {
        Write-Host $control.Text -NoNewline -ForegroundColor $control.Color
        if ($control -ne $controls[-1]) {
            Write-Host (" " * $spacing) -NoNewline
        }
    }

    # Scrolling information
    $currentPage = [math]::Floor($viewportTop / $itemsPerPage) + 1
    $totalPages = [math]::Ceiling($totalItems / $itemsPerPage)
    $scrollInfo = "Page {0}/{1}" -f $currentPage, $totalPages
    $Host.UI.RawUI.CursorPosition = @{X=$leftPadding + $lineWidth - $scrollInfo.Length; Y=$consoleHeight-3}
    Write-Host $scrollInfo -ForegroundColor Gray
}

function Show-Menu {
    param (
        [int]$selectedIndex
    )

    # Suppress cursor
    [Console]::CursorVisible = $false

    # Layout constants
    $menuWidth = 80
    $nameWidth = 40
    $statusWidth = 20
    $prefixWidth = 5
    $leftMargin = [math]::Floor(($consoleWidth - $menuWidth) / 2)

    # Get unique sections
    $sections = @()
    $software | ForEach-Object {
        if ($sections -notcontains $_.Section) {
            $sections += $_.Section
        }
    }

    # Improved scrolling logic
    # Adjust viewport to ensure selected item is visible
    $visibleSectionItems = 0
    $itemIndex = 0
    $sectionStartIndices = @{}

    foreach ($section in $sections) {
        $sectionSoftware = @($software | Where-Object { $_.Section -eq $section })
        $sectionStartIndices[$section] = $itemIndex

        # If selected index is within this section's range
        if ($selectedIndex -ge $itemIndex -and $selectedIndex -lt ($itemIndex + $sectionSoftware.Count)) {
            # Adjust viewport to show this section
            $script:viewportTop = [math]::Max(0, $itemIndex - 3)
        }

        $itemIndex += $sectionSoftware.Count + 2  # +2 for section header and spacing
    }

    # Clear display area (excluding header and footer)
    for ($y = 3; $y -lt ($consoleHeight - 5); $y++) {
        $Host.UI.RawUI.CursorPosition = @{X=0; Y=$y}
        Write-Host (" " * $consoleWidth) -NoNewline
    }

    # Reset row tracking
    $currentRow = 0
    $row = 4  # Start after header
    $displayedItems = 0

    foreach ($section in $sections) {
        $sectionSoftware = @($software | Where-Object { $_.Section -eq $section })
        $sectionStartIndex = $sectionStartIndices[$section]

        # Section header
        if ($currentRow -ge $viewportTop -and $currentRow -lt ($viewportTop + $itemsPerPage)) {
            $sectionText = "--- $section ---"
            $headerPadding = [math]::Floor(($menuWidth - $sectionText.Length) / 2)
            $Host.UI.RawUI.CursorPosition = @{X=$leftMargin + $headerPadding; Y=$row}
            Write-Host $sectionText -ForegroundColor Cyan
            $row++
        }
        $currentRow++

        foreach ($item in $sectionSoftware) {
            $index = [array]::IndexOf($software, $item)

            # Check if this item should be displayed
            if ($currentRow -ge $viewportTop -and $currentRow -lt ($viewportTop + $itemsPerPage)) {
                # Selection prefix
                $prefix = if ($item.Action -eq 'install') { "[√]" }
                         elseif ($item.Action -eq 'uninstall') { "[X]" }
                         else { "[ ]" }

                # Status color
                $statusColor = switch ($item.Status) {
                    "Installed" { "Green" }
                    "Not Installed" { "Gray" }
                    "Installing..." { "Yellow" }
                    "Uninstalling..." { "Red" }
                    "Install Error" { "Red" }
                    "Install Success" { "Green" }
                    default { "Yellow" }
                }

                # Format the line with proper spacing
                $prefixDisplay = $prefix.PadRight($prefixWidth)
                $nameDisplay = $item.Name.PadRight($nameWidth - $prefixWidth)
                $statusDisplay = "[$($item.Status)]".PadLeft($statusWidth)

                $Host.UI.RawUI.CursorPosition = @{X=$leftMargin; Y=$row}
                
                # Replace ternary operator with if-else
                $prefixColor = if ($item.Action -eq 'uninstall') { 'Red' } else { 'Green' }
                Write-Host $prefixDisplay -NoNewline -ForegroundColor $prefixColor

                if ($index -eq $selectedIndex) {
                    Write-Host $nameDisplay -NoNewline -ForegroundColor Black -BackgroundColor White
                } else {
                    Write-Host $nameDisplay -NoNewline
                }

                Write-Host $statusDisplay -ForegroundColor $statusColor

                if ($item.ErrorMessage) {
                    $row++
                    $Host.UI.RawUI.CursorPosition = @{X=$leftMargin + $prefixWidth; Y=$row}
                    Write-Host $item.ErrorMessage -ForegroundColor Red
                }
                $row++
                $displayedItems++
            }
            $currentRow++
        }

        # Add space between sections if there's room
        if ($currentRow -ge $viewportTop -and $currentRow -lt ($viewportTop + $itemsPerPage)) {
            $row++
        }
        $currentRow++
    }

    Draw-Footer $row $software.Count $viewportTop $itemsPerPage
}

function Check-InstalledSoftware {
    # Clear previous job data
    Remove-Job -State Completed -ErrorAction SilentlyContinue

    # Start a job for each software item to check its status in parallel
    foreach ($item in $software) {
        $item.Status = "Checking..."
        $item.ErrorMessage = $null

        Start-Job -ScriptBlock {
            param ($id)
            $checkResult = winget list --id $id --accept-source-agreements 2>$null
            if ($checkResult -match $id) {
                return "Installed"
            } else {
                return "Not Installed"
            }
        } -ArgumentList $item.ID | Out-Null
    }

    # Wait for all jobs to complete and update the status
    while (Get-Job -State Running) {
        Start-Sleep -Milliseconds 100
    }

    $jobs = Get-Job | Receive-Job
    for ($i = 0; $i -lt $software.Count; $i++) {
        $software[$i].Status = $jobs[$i]
    }

    # Clean up completed jobs
    Remove-Job -State Completed -ErrorAction SilentlyContinue
}

# The rest of your script remains the same...

function Process-SelectedSoftware {
    $selectedCount = ($software | Where-Object { $_.Action -ne $null }).Count
    if ($selectedCount -eq 0) {
        Write-Host "`n`tNo software selected for processing.`n" -ForegroundColor Red
        Start-Sleep -Seconds 2
        return
    }

    foreach ($item in $software | Where-Object { $_.Action -eq 'install' }) {
        $item.Status = "Installing..."
        $item.ErrorMessage = $null
        Show-Menu $selectedIndex

        try {
            # Added --silent flag to reduce user interactions
            $result = winget install --id $item.ID --accept-source-agreements --accept-package-agreements --silent 2>&1
            if ($result -match "Successfully installed") {
                $item.Status = "Install Success"
                $item.Action = $null
                $item.ErrorMessage = $null
            } else {
                $item.Status = "Install Error"
                $item.ErrorMessage = "Error: " + ($result | Select-Object -Last 1)
            }
        } catch {
            $item.Status = "Install Error"
            $item.ErrorMessage = "Error: " + $_.Exception.Message
        }
        Show-Menu $selectedIndex
    }

    foreach ($item in $software | Where-Object { $_.Action -eq 'uninstall' }) {
        $item.Status = "Uninstalling..."
        $item.ErrorMessage = $null
        Show-Menu $selectedIndex

        try {
            # Added --silent flag to reduce user interactions
            $result = winget uninstall --id $item.ID --silent 2>&1
            if ($result -match "Successfully uninstalled") {
                $item.Status = "Not Installed"
                $item.Action = $null
                $item.ErrorMessage = $null
            } else {
                $item.Status = "Uninstall Error"
                $item.ErrorMessage = "Error: " + ($result | Select-Object -Last 1)
            }
        } catch {
            $item.Status = "Uninstall Error"
            $item.ErrorMessage = "Error: " + $_.Exception.Message
        }
        Show-Menu $selectedIndex
    }

    Start-Sleep -Seconds 2
    Check-InstalledSoftware
}

# Initial setup
$Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size(500, 9999)
$Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($consoleWidth, $consoleHeight)

Draw-Header
$selectedIndex = 0
Show-Menu $selectedIndex

while ($true) {
    if ([Console]::KeyAvailable) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                if ($selectedIndex -gt 0) {
                    $selectedIndex--
                    # Adjust viewport if needed
                    if ($selectedIndex -lt $viewportTop) {
                        $script:viewportTop = $selectedIndex
                    }
                }
            }
            40 { # Down arrow
                if ($selectedIndex -lt ($software.Count - 1)) {
                    $selectedIndex++
                    # Adjust viewport if needed
                    if ($selectedIndex -ge ($viewportTop + $itemsPerPage)) {
                        $script:viewportTop = $selectedIndex - $itemsPerPage + 1
                    }
                }
            }
            73 { # 'i' key
                if ($software[$selectedIndex].Action -eq 'install') {
                    $software[$selectedIndex].Action = $null
                } else {
                    $software[$selectedIndex].Action = 'install'
                }
            }
            85 { # 'u' key
                if ($software[$selectedIndex].Action -eq 'uninstall') {
                    $software[$selectedIndex].Action = $null
                } else {
                    $software[$selectedIndex].Action = 'uninstall'
                }
            }
            82 { # 'r' key
                foreach ($item in $software) {
                    $item.Status = "Checking..."
                    $item.ErrorMessage = $null
                }
                Show-Menu $selectedIndex
                Check-InstalledSoftware
            }
            13 { Process-SelectedSoftware }
            27 { Clear-Host; exit }
        }
        Show-Menu $selectedIndex
    }
}
