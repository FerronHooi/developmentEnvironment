# Capture Current VS Code State Script
# This script captures your current VS Code configuration and updates devcontainer.json
# Run this before rebuilding container to preserve all customizations

param(
    [string]$DevContainerPath = ".devcontainer/devcontainer.json",
    [switch]$BackupOriginal = $true,
    [switch]$IncludeUserSettings = $false,
    [switch]$Verbose = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VS Code State Capture Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to log verbose messages
function Write-VerboseLog {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
    }
}

# Function to get current VS Code extensions
function Get-CurrentExtensions {
    Write-Host "Capturing installed extensions..." -ForegroundColor Yellow

    try {
        $extensions = code --list-extensions 2>$null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get VS Code extensions"
        }

        $extensionArray = @()
        foreach ($ext in $extensions) {
            if ($ext.Trim() -ne "") {
                $extensionArray += $ext.Trim()
                Write-VerboseLog "  Found: $ext"
            }
        }

        Write-Host "✓ Found $($extensionArray.Count) extensions" -ForegroundColor Green
        return $extensionArray
    }
    catch {
        Write-Host "✗ Error getting extensions: $_" -ForegroundColor Red
        return @()
    }
}

# Function to get VS Code settings
function Get-VSCodeSettings {
    Write-Host "Capturing VS Code settings..." -ForegroundColor Yellow

    $settings = @{}

    # Get workspace settings if they exist
    $workspaceSettingsPath = Join-Path (Get-Location) ".vscode/settings.json"
    if (Test-Path $workspaceSettingsPath) {
        Write-VerboseLog "  Reading workspace settings from $workspaceSettingsPath"
        try {
            $workspaceSettings = Get-Content $workspaceSettingsPath -Raw | ConvertFrom-Json
            foreach ($prop in $workspaceSettings.PSObject.Properties) {
                $settings[$prop.Name] = $prop.Value
                Write-VerboseLog "    Added workspace setting: $($prop.Name)"
            }
            Write-Host "✓ Found $(($workspaceSettings.PSObject.Properties | Measure-Object).Count) workspace settings" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Could not parse workspace settings: $_" -ForegroundColor Yellow
        }
    }

    # Optionally include user settings
    if ($IncludeUserSettings) {
        $userSettingsPath = Join-Path $env:APPDATA "Code/User/settings.json"
        if (Test-Path $userSettingsPath) {
            Write-VerboseLog "  Reading user settings from $userSettingsPath"
            try {
                $userSettings = Get-Content $userSettingsPath -Raw | ConvertFrom-Json

                # Filter to only include relevant settings (skip UI preferences)
                $relevantPrefixes = @(
                    "python.",
                    "jupyter.",
                    "databricks.",
                    "azure.",
                    "git.",
                    "terminal.",
                    "editor.format",
                    "editor.rulers",
                    "files.auto",
                    "files.exclude"
                )

                foreach ($prop in $userSettings.PSObject.Properties) {
                    $isRelevant = $false
                    foreach ($prefix in $relevantPrefixes) {
                        if ($prop.Name.StartsWith($prefix)) {
                            $isRelevant = $true
                            break
                        }
                    }

                    if ($isRelevant -and -not $settings.ContainsKey($prop.Name)) {
                        $settings[$prop.Name] = $prop.Value
                        Write-VerboseLog "    Added user setting: $($prop.Name)"
                    }
                }
                Write-Host "✓ Found relevant user settings" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠ Could not parse user settings: $_" -ForegroundColor Yellow
            }
        }
    }

    return $settings
}

# Function to get installed packages (Python/Node)
function Get-InstalledPackages {
    Write-Host "Capturing installed packages..." -ForegroundColor Yellow

    $packages = @{
        Python = @()
        Node = @()
    }

    # Check for Python packages
    try {
        $pipList = pip list --format=freeze 2>$null
        if ($LASTEXITCODE -eq 0) {
            $packages.Python = $pipList | Where-Object { $_ -and $_ -notmatch "^#" }
            Write-Host "✓ Found $($packages.Python.Count) Python packages" -ForegroundColor Green
        }
    }
    catch {
        Write-VerboseLog "No Python packages found or pip not available"
    }

    # Check for global npm packages
    try {
        $npmList = npm list -g --depth=0 --json 2>$null | ConvertFrom-Json
        if ($npmList.dependencies) {
            foreach ($dep in $npmList.dependencies.PSObject.Properties) {
                $packages.Node += $dep.Name
            }
            Write-Host "✓ Found $($packages.Node.Count) global Node packages" -ForegroundColor Green
        }
    }
    catch {
        Write-VerboseLog "No Node packages found or npm not available"
    }

    return $packages
}

# Function to update devcontainer.json
function Update-DevContainerJson {
    param(
        [string]$Path,
        [array]$Extensions,
        [hashtable]$Settings,
        [hashtable]$Packages
    )

    Write-Host ""
    Write-Host "Updating devcontainer.json..." -ForegroundColor Yellow

    # Backup original file
    if ($BackupOriginal -and (Test-Path $Path)) {
        $backupPath = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $Path $backupPath
        Write-Host "✓ Backed up to: $backupPath" -ForegroundColor Green
    }

    # Read existing devcontainer.json
    try {
        $devContainer = Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "✗ Could not read $Path" -ForegroundColor Red
        return
    }

    # Update extensions
    if ($Extensions.Count -gt 0) {
        if (-not $devContainer.customizations) {
            $devContainer | Add-Member -NotePropertyName "customizations" -NotePropertyValue @{} -Force
        }
        if (-not $devContainer.customizations.vscode) {
            $devContainer.customizations | Add-Member -NotePropertyName "vscode" -NotePropertyValue @{} -Force
        }

        # Merge extensions (avoid duplicates)
        $existingExtensions = @()
        if ($devContainer.customizations.vscode.extensions) {
            $existingExtensions = $devContainer.customizations.vscode.extensions
        }

        $allExtensions = @()
        $extensionSet = @{}

        # Add existing extensions
        foreach ($ext in $existingExtensions) {
            if (-not $extensionSet.ContainsKey($ext.ToLower())) {
                $allExtensions += $ext
                $extensionSet[$ext.ToLower()] = $true
            }
        }

        # Add new extensions
        $addedCount = 0
        foreach ($ext in $Extensions) {
            if (-not $extensionSet.ContainsKey($ext.ToLower())) {
                $allExtensions += $ext
                $extensionSet[$ext.ToLower()] = $true
                $addedCount++
                Write-VerboseLog "  Adding extension: $ext"
            }
        }

        $devContainer.customizations.vscode.extensions = $allExtensions | Sort-Object
        Write-Host "✓ Updated extensions (added $addedCount new)" -ForegroundColor Green
    }

    # Update settings
    if ($Settings.Count -gt 0) {
        if (-not $devContainer.customizations.vscode.settings) {
            $devContainer.customizations.vscode | Add-Member -NotePropertyName "settings" -NotePropertyValue @{} -Force
        }

        $addedSettings = 0
        foreach ($key in $Settings.Keys) {
            # Don't overwrite environment variable references
            $currentValue = $devContainer.customizations.vscode.settings.$key
            if ($currentValue -and $currentValue -match '\$\{.*\}') {
                Write-VerboseLog "  Skipping $key (contains variable reference)"
                continue
            }

            $devContainer.customizations.vscode.settings | Add-Member -NotePropertyName $key -NotePropertyValue $Settings[$key] -Force
            $addedSettings++
            Write-VerboseLog "  Adding setting: $key"
        }

        Write-Host "✓ Updated settings (added/modified $addedSettings)" -ForegroundColor Green
    }

    # Add Python packages to postCreateCommand if needed
    if ($Packages.Python.Count -gt 0) {
        $requirementsPath = Join-Path (Split-Path $Path) "requirements.captured.txt"
        $Packages.Python | Out-File $requirementsPath -Encoding UTF8
        Write-Host "✓ Saved Python packages to requirements.captured.txt" -ForegroundColor Green
        Write-Host "  Add 'pip install -r .devcontainer/requirements.captured.txt' to postCreateCommand" -ForegroundColor Yellow
    }

    # Save updated devcontainer.json with proper formatting
    try {
        $jsonString = $devContainer | ConvertTo-Json -Depth 10

        # Format the JSON nicely
        $jsonString = $jsonString -replace '  "', '    "' # Increase indentation
        $jsonString = $jsonString -replace '": {', '": {' # Keep object braces
        $jsonString = $jsonString -replace '": \[', '": [' # Keep array brackets

        # Add comments back for better readability
        $jsonString = $jsonString -replace '"customizations":', "`n  // VS Code specific configurations`n  `"customizations`":"
        $jsonString = $jsonString -replace '"extensions":', "`n      // Extensions to install in the container`n      `"extensions`":"
        $jsonString = $jsonString -replace '"settings":', "`n      // Settings that apply to the container`n      `"settings`":"
        $jsonString = $jsonString -replace '"remoteEnv":', "`n  // Environment variables`n  `"remoteEnv`":"
        $jsonString = $jsonString -replace '"mounts":', "`n  // Mount points for credentials and configurations`n  `"mounts`":"

        $jsonString | Out-File $Path -Encoding UTF8
        Write-Host "✓ Successfully updated $Path" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Error saving devcontainer.json: $_" -ForegroundColor Red
    }
}

# Function to create a state snapshot file
function Save-StateSnapshot {
    param(
        [array]$Extensions,
        [hashtable]$Settings,
        [hashtable]$Packages
    )

    $snapshotPath = Join-Path (Split-Path $DevContainerPath) "state-snapshot.json"

    $snapshot = @{
        CaptureDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        MachineName = $env:COMPUTERNAME
        Extensions = $Extensions
        Settings = $Settings
        Packages = $Packages
    }

    $snapshot | ConvertTo-Json -Depth 10 | Out-File $snapshotPath -Encoding UTF8
    Write-Host "✓ Saved state snapshot to: $snapshotPath" -ForegroundColor Green
}

# Main execution
try {
    # Check if devcontainer.json exists
    if (-not (Test-Path $DevContainerPath)) {
        Write-Host "✗ devcontainer.json not found at: $DevContainerPath" -ForegroundColor Red
        Write-Host "  Please run this script from your project root or specify -DevContainerPath" -ForegroundColor Yellow
        exit 1
    }

    # Capture current state
    $currentExtensions = Get-CurrentExtensions
    $currentSettings = Get-VSCodeSettings
    $currentPackages = Get-InstalledPackages

    # Update devcontainer.json
    Update-DevContainerJson -Path $DevContainerPath `
                           -Extensions $currentExtensions `
                           -Settings $currentSettings `
                           -Packages $currentPackages

    # Save snapshot for reference
    Save-StateSnapshot -Extensions $currentExtensions `
                      -Settings $currentSettings `
                      -Packages $currentPackages

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  State Capture Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Review the changes in devcontainer.json" -ForegroundColor White
    Write-Host "2. Commit the changes to git" -ForegroundColor White
    Write-Host "3. Rebuild the container: Ctrl+Shift+P > 'Dev Containers: Rebuild Container'" -ForegroundColor White
    Write-Host ""
    Write-Host "Your configuration is now preserved! 🎉" -ForegroundColor Green
}
catch {
    Write-Host "✗ An error occurred: $_" -ForegroundColor Red
    exit 1
}