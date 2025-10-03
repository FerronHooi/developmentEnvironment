# DevEnv - Self-locating DevContainer deployment script
# Usage: devenv "C:\Path\To\Your\Project"
# This script automatically finds its own location, so you can move DevContainerTemplates anywhere

param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$ProjectPath = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "minimal", "data-science", "web", "custom")]
    [string]$Profile = "full",

    [switch]$CreateEnv = $true,
    [switch]$Open = $false,
    [switch]$Force = $false,
    [switch]$Help = $false
)

# Error handler to keep window open
trap {
    Write-Host ""
    Write-Host "Error occurred: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Show help if requested or no project path provided
if ($Help -or [string]::IsNullOrWhiteSpace($ProjectPath)) {
    Write-Host ""
    Write-Host "DevEnv - DevContainer Environment Setup" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        Write-Host "ERROR: No project path specified!" -ForegroundColor Red
        Write-Host ""
    }

    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  devenv <ProjectPath> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  devenv C:\MyProject" -ForegroundColor White
    Write-Host "  devenv ." -ForegroundColor Gray -NoNewline
    Write-Host "                       # Current directory" -ForegroundColor DarkGray
    Write-Host "  devenv C:\MyProject -Profile minimal" -ForegroundColor White
    Write-Host "  devenv C:\MyProject -Open" -ForegroundColor Gray -NoNewline
    Write-Host "     # Opens VS Code after" -ForegroundColor DarkGray
    Write-Host "  devenv C:\MyProject -Force" -ForegroundColor Gray -NoNewline
    Write-Host "    # Overwrites existing" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Profiles:" -ForegroundColor Yellow
    Write-Host "  full         - All 45+ extensions (default)" -ForegroundColor White
    Write-Host "  minimal      - Essential extensions only" -ForegroundColor White
    Write-Host "  data-science - Python, Jupyter, Databricks" -ForegroundColor White
    Write-Host "  web          - Node.js, React, API development" -ForegroundColor White
    Write-Host "  custom       - Define your own" -ForegroundColor White
    Write-Host ""

    # Interactive mode if no path provided
    if ([string]::IsNullOrWhiteSpace($ProjectPath) -and -not $Help) {
        Write-Host "Enter project path or press Enter to exit:" -ForegroundColor Yellow
        $inputPath = Read-Host "Project Path"

        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            Write-Host "Exiting..." -ForegroundColor Gray
            exit 0
        }

        $ProjectPath = $inputPath
    } else {
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }
}

# Get the directory where this script is located (.devcontainer folder)
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# The .devcontainer folder IS the source we want to copy
$DEVCONTAINER_SOURCE_PATH = $SCRIPT_DIR

# Remove any quotes from the project path
$ProjectPath = $ProjectPath.Trim('"', "'")

# Resolve project path (handle relative paths and ".")
if ($ProjectPath -eq ".") {
    $ProjectPath = Get-Location
} else {
    # Try to resolve the path
    $resolvedPath = $null
    try {
        $resolvedPath = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
    } catch {
        # Path doesn't exist yet
    }

    if ($resolvedPath) {
        $ProjectPath = $resolvedPath
    } else {
        # Path doesn't exist, ask to create
        Write-Host ""
        Write-Host "Project path doesn't exist: $ProjectPath" -ForegroundColor Yellow
        $response = Read-Host "Create it? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            try {
                New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
                $ProjectPath = Resolve-Path $ProjectPath
                Write-Host "Created: $ProjectPath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to create directory: $_" -ForegroundColor Red
                Write-Host "Press any key to exit..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                exit 1
            }
        } else {
            Write-Host "Cancelled" -ForegroundColor Yellow
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 0
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DevEnv - Quick Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[Project] $ProjectPath" -ForegroundColor White
Write-Host "[Source] $DEVCONTAINER_SOURCE_PATH" -ForegroundColor Gray
Write-Host "[Profile] $Profile" -ForegroundColor Gray
Write-Host ""

# Check if .devcontainer source exists
if (-not (Test-Path $DEVCONTAINER_SOURCE_PATH)) {
    Write-Host "ERROR: .devcontainer source not found at: $DEVCONTAINER_SOURCE_PATH" -ForegroundColor Red
    Write-Host "  This script must be in the developmentEnvironment/.devcontainer folder" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current directory: $SCRIPT_DIR" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# IMPORTANT: Update .gitignore FIRST (before copying) to prevent Git from tracking as submodule
# This must happen before the .devcontainer folder exists in the project
$gitignorePath = Join-Path -Path $ProjectPath -ChildPath ".gitignore"
$gitignoreEntries = @(
    "",
    "# DevContainer and IDE files (auto-added by devenv)",
    ".devcontainer/",
    ".vscode/",
    ".gitattributes"
)

Write-Host "Updating .gitignore first (prevents submodule tracking)..." -ForegroundColor Yellow

if (Test-Path -Path $gitignorePath) {
    # Read existing .gitignore
    $existingContent = Get-Content -Path $gitignorePath -Raw

    # Check if entries already exist
    $needsUpdate = $false

    if ($existingContent -notmatch '\.devcontainer/?') {
        $needsUpdate = $true
    }
    if ($existingContent -notmatch '\.vscode/?') {
        $needsUpdate = $true
    }
    if ($existingContent -notmatch '\.gitattributes') {
        $needsUpdate = $true
    }

    if ($needsUpdate) {
        # Add entries to existing .gitignore
        $gitignoreEntries | Out-File -FilePath $gitignorePath -Append -Encoding UTF8
        Write-Host "  Updated .gitignore:" -ForegroundColor Green
        Write-Host "    + .devcontainer/" -ForegroundColor Green
        Write-Host "    + .vscode/" -ForegroundColor Green
        Write-Host "    + .gitattributes" -ForegroundColor Green
    } else {
        Write-Host "  = .gitignore already has entries" -ForegroundColor Gray
    }
} else {
    # Create new .gitignore with entries
    $gitignoreEntries | Out-File -FilePath $gitignorePath -Encoding UTF8
    Write-Host "  Created .gitignore:" -ForegroundColor Green
    Write-Host "    + .devcontainer/" -ForegroundColor Green
    Write-Host "    + .vscode/" -ForegroundColor Green
    Write-Host "    + .gitattributes" -ForegroundColor Green
}

# Check if .devcontainer already exists in target
$targetDevContainer = Join-Path $ProjectPath ".devcontainer"
if ((Test-Path $targetDevContainer) -and -not $Force) {
    Write-Host ""
    Write-Host "WARNING: .devcontainer already exists!" -ForegroundColor Yellow
    Write-Host "Options:" -ForegroundColor White
    Write-Host "  Y - Overwrite (delete existing)" -ForegroundColor White
    Write-Host "  B - Backup existing and continue" -ForegroundColor White
    Write-Host "  N - Cancel" -ForegroundColor White
    $response = Read-Host "Choice (Y/B/N)"

    switch ($response.ToUpper()) {
        'Y' {
            Remove-Item -Recurse -Force $targetDevContainer
            Write-Host "  Removed existing .devcontainer" -ForegroundColor Yellow
        }
        'B' {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $backupPath = "$targetDevContainer.backup.$timestamp"
            Move-Item $targetDevContainer $backupPath
            Write-Host "  Backed up to: $(Split-Path -Leaf $backupPath)" -ForegroundColor Green
        }
        default {
            Write-Host "  Cancelled" -ForegroundColor Yellow
            Write-Host "Press any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 0
        }
    }
}

# Copy entire .devcontainer folder
Write-Host ""
Write-Host "Copying .devcontainer folder..." -ForegroundColor Yellow
try {
    # Use robocopy for efficient directory copying on Windows
    $robocopyArgs = @(
        $DEVCONTAINER_SOURCE_PATH,
        $targetDevContainer,
        "/E",  # Copy subdirectories, including empty ones
        "/NFL", # No file list
        "/NDL", # No directory list
        "/NJH", # No job header
        "/NJS", # No job summary
        "/NC",  # No class
        "/NS",  # No size
        "/NP"   # No progress
    )

    $result = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow

    # Robocopy exit codes: 0-7 are success codes, 8+ are errors
    if ($result.ExitCode -ge 8) {
        throw "Robocopy failed with exit code: $($result.ExitCode)"
    }

    Write-Host "  + Copied .devcontainer folder successfully" -ForegroundColor Green

    # Count what was copied
    $copiedItems = Get-ChildItem -Path $targetDevContainer -Recurse -File | Measure-Object
    Write-Host "  Copied $($copiedItems.Count) files" -ForegroundColor Cyan
} catch {
    Write-Host "  ! Error copying .devcontainer: $_" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Copy .gitattributes to project root to fix line ending issues
$gitAttributesSource = Join-Path -Path $targetDevContainer -ChildPath "base-template\project.gitattributes"
$gitAttributesDest = Join-Path -Path $ProjectPath -ChildPath ".gitattributes"

if (Test-Path -Path $gitAttributesSource) {
    if (Test-Path -Path $gitAttributesDest) {
        Write-Host ""
        Write-Host "WARNING: .gitattributes already exists in project root" -ForegroundColor Yellow
        Write-Host "  Keeping existing file (to preserve custom settings)" -ForegroundColor Gray
    } else {
        try {
            Copy-Item -Path $gitAttributesSource -Destination $gitAttributesDest -Force
            Write-Host ""
            Write-Host "Git line ending fixes:" -ForegroundColor Yellow
            Write-Host "  + .gitattributes copied to project root" -ForegroundColor Green
            Write-Host "  This ensures consistent line endings between Windows/Linux" -ForegroundColor Gray
        } catch {
            Write-Host "  ! Error copying .gitattributes: $_" -ForegroundColor Red
        }
    }
}

# .gitignore was already updated before copying to prevent submodule tracking

# Apply extension profile
if ($Profile -ne "full") {
    Write-Host ""
    Write-Host "Applying profile: $Profile" -ForegroundColor Yellow

    $devContainerJson = Join-Path $targetDevContainer "base-template\.devcontainer\devcontainer.json"
    $config = Get-Content $devContainerJson -Raw | ConvertFrom-Json

    $extensions = switch ($Profile) {
        "minimal" {
            @(
                "ms-vscode-remote.remote-containers",
                "ms-python.python",
                "ms-python.vscode-pylance",
                "ms-azuretools.vscode-docker",
                "donjayamanne.githistory"
            )
        }
        "data-science" {
            @(
                "ms-vscode-remote.remote-containers",
                "ms-python.python",
                "ms-python.vscode-pylance",
                "ms-toolsai.jupyter",
                "databricks.databricks",
                "dvirtz.parquet-viewer"
            )
        }
        "web" {
            @(
                "ms-vscode-remote.remote-containers",
                "dbaeumer.vscode-eslint",
                "esbenp.prettier-vscode",
                "ms-azuretools.vscode-docker"
            )
        }
        default { $config.customizations.vscode.extensions }
    }

    if ($Profile -ne "custom") {
        $config.customizations.vscode.extensions = $extensions
        $config | ConvertTo-Json -Depth 10 | Out-File $devContainerJson -Encoding UTF8
        Write-Host "  Applied $($extensions.Count) extensions" -ForegroundColor Green
    }
}

# Create .env file
if ($CreateEnv) {
    $envPath = Join-Path $targetDevContainer "base-template\.devcontainer\.env"
    if (-not (Test-Path $envPath)) {
        $envExample = Join-Path $targetDevContainer "base-template\.devcontainer\.env.example"
        if (Test-Path $envExample) {
            Copy-Item $envExample $envPath

            # Auto-populate project name
            $projectName = Split-Path $ProjectPath -Leaf
            $envContent = Get-Content $envPath -Raw
            $envContent = $envContent -replace 'PROJECT_NAME=my-project', "PROJECT_NAME=$projectName"

            # Try to get git config
            try {
                $gitName = git config --global user.name 2>$null
                $gitEmail = git config --global user.email 2>$null
                if ($gitName) {
                    $envContent = $envContent -replace 'GIT_USER_NAME=Your Name', "GIT_USER_NAME=$gitName"
                }
                if ($gitEmail) {
                    $envContent = $envContent -replace 'GIT_USER_EMAIL=your.email@example.com', "GIT_USER_EMAIL=$gitEmail"
                }
            } catch {}

            $envContent | Out-File $envPath -Encoding UTF8
            Write-Host "  + .env file created" -ForegroundColor Green
        }
    } else {
        Write-Host "  = .env exists (kept)" -ForegroundColor Gray
    }
}

# Quick analysis
Write-Host ""
Write-Host "Project Analysis:" -ForegroundColor Cyan

if (Test-Path (Join-Path $ProjectPath "requirements.txt")) {
    Write-Host "  * Python project (requirements.txt)" -ForegroundColor White
}
if (Test-Path (Join-Path $ProjectPath "package.json")) {
    Write-Host "  * Node.js project (package.json)" -ForegroundColor White
}
if (Test-Path (Join-Path $ProjectPath "databricks.yml")) {
    Write-Host "  * Databricks project" -ForegroundColor White
}
if (Test-Path (Join-Path $ProjectPath ".git")) {
    Write-Host "  * Git repository" -ForegroundColor White
}

# Clean up unwanted Git changes (keep only .gitignore and .gitattributes)
if (Test-Path (Join-Path $ProjectPath ".git")) {
    Write-Host ""
    Write-Host "Cleaning up unwanted file changes..." -ForegroundColor Yellow

    # Save current directory
    $originalDir = Get-Location
    Set-Location $ProjectPath

    try {
        # Stage the files we want to keep
        git add .gitignore 2>$null
        if (Test-Path .gitattributes) {
            git add .gitattributes 2>$null
        }

        # Reset all other files to their original state (excluding staged files)
        git checkout -- . 2>$null

        Write-Host "  + Reverted unwanted changes (kept .gitignore/.gitattributes)" -ForegroundColor Green
    } catch {
        Write-Host "  ! Could not clean up changes: $_" -ForegroundColor Yellow
    } finally {
        # Return to original directory
        Set-Location $originalDir
    }
}

# Success message
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  SUCCESS: DevContainer deployed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Next steps
Write-Host "Next steps:" -ForegroundColor Cyan

if ($Open) {
    Write-Host "  Opening VS Code..." -ForegroundColor Yellow
    code $ProjectPath
    Write-Host "  1. Wait for VS Code to open" -ForegroundColor White
    Write-Host "  2. Press Ctrl+Shift+P" -ForegroundColor White
    Write-Host "  3. Run: Dev Containers: Reopen in Container" -ForegroundColor White
} else {
    Write-Host "  1. Open VS Code:" -ForegroundColor White
    Write-Host "     code `"$ProjectPath`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  2. Reopen in Container:" -ForegroundColor White
    Write-Host "     Ctrl+Shift+P -> Dev Containers: Reopen in Container" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  3. Configure credentials:" -ForegroundColor White
Write-Host "     Edit: .devcontainer\base-template\.devcontainer\.env" -ForegroundColor Gray

Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")