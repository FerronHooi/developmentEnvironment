# DevEnv - Self-locating DevContainer deployment script
# Usage: devenv "C:\Path\To\Your\Project"
# This script automatically finds its own location, so you can move DevContainerTemplates anywhere

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "minimal", "data-science", "web", "custom")]
    [string]$Profile = "full",

    [switch]$CreateEnv = $true,
    [switch]$Open = $false,
    [switch]$Force = $false,
    [switch]$Help = $false
)

# Show help if requested
if ($Help) {
    Write-Host ""
    Write-Host "DevEnv - DevContainer Environment Setup" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  devenv <ProjectPath> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  devenv `"C:\MyProject`"" -ForegroundColor White
    Write-Host "  devenv `".`"                       # Current directory" -ForegroundColor White
    Write-Host "  devenv `"C:\MyProject`" -Profile minimal" -ForegroundColor White
    Write-Host "  devenv `"C:\MyProject`" -Open     # Opens VS Code after" -ForegroundColor White
    Write-Host "  devenv `"C:\MyProject`" -Force    # Overwrites existing" -ForegroundColor White
    Write-Host ""
    Write-Host "Profiles:" -ForegroundColor Yellow
    Write-Host "  full         - All 45+ extensions (default)" -ForegroundColor White
    Write-Host "  minimal      - Essential extensions only" -ForegroundColor White
    Write-Host "  data-science - Python, Jupyter, Databricks" -ForegroundColor White
    Write-Host "  web          - Node.js, React, API development" -ForegroundColor White
    Write-Host "  custom       - Define your own" -ForegroundColor White
    Write-Host ""
    exit 0
}

# Get the directory where this script is located
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Find the template directory (relative to script location)
$TEMPLATE_PATH = Join-Path $SCRIPT_DIR "base-template"

# Resolve project path (handle relative paths and ".")
if ($ProjectPath -eq ".") {
    $ProjectPath = Get-Location
} else {
    $ProjectPath = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
    if (-not $ProjectPath) {
        # If path doesn't exist, try to create it
        $response = Read-Host "Project path doesn't exist. Create it? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
            $ProjectPath = Resolve-Path $ProjectPath
        } else {
            Write-Host "✗ Project path not found: $ProjectPath" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DevEnv - Quick Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Project: $ProjectPath" -ForegroundColor White
Write-Host "📦 Template: $TEMPLATE_PATH" -ForegroundColor Gray
Write-Host "🎨 Profile: $Profile" -ForegroundColor Gray
Write-Host ""

# Check if template exists
if (-not (Test-Path $TEMPLATE_PATH)) {
    Write-Host "✗ Template not found at: $TEMPLATE_PATH" -ForegroundColor Red
    Write-Host "  This script must be in the DevContainerTemplates folder" -ForegroundColor Yellow
    exit 1
}

# Check if .devcontainer already exists
$targetDevContainer = Join-Path $ProjectPath ".devcontainer"
if ((Test-Path $targetDevContainer) -and -not $Force) {
    Write-Host "⚠ .devcontainer already exists!" -ForegroundColor Yellow
    $response = Read-Host "Overwrite? (Y/N/B for backup)"

    switch ($response.ToUpper()) {
        'Y' {
            Remove-Item -Recurse -Force $targetDevContainer
            Write-Host "  Removed existing .devcontainer" -ForegroundColor Yellow
        }
        'B' {
            $backupPath = "$targetDevContainer.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item $targetDevContainer $backupPath
            Write-Host "  ✓ Backed up to: $(Split-Path -Leaf $backupPath)" -ForegroundColor Green
        }
        default {
            Write-Host "  Cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
}

# Create .devcontainer directory
Write-Host "Creating .devcontainer..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $targetDevContainer -Force | Out-Null

# Copy files
$files = @(
    "devcontainer.json",
    "Dockerfile",
    "postCreateCommand.sh",
    ".env.example",
    ".gitignore",
    "capture-current-state.ps1"
)

foreach ($file in $files) {
    $source = Join-Path $TEMPLATE_PATH ".devcontainer" $file
    $dest = Join-Path $targetDevContainer $file

    if (Test-Path $source) {
        Copy-Item $source $dest -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
    }
}

# Apply extension profile
if ($Profile -ne "full") {
    $devContainerJson = Join-Path $targetDevContainer "devcontainer.json"
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

    $config.customizations.vscode.extensions = $extensions
    $config | ConvertTo-Json -Depth 10 | Out-File $devContainerJson -Encoding UTF8
    Write-Host "  ✓ Applied $Profile profile" -ForegroundColor Green
}

# Create .env file
if ($CreateEnv) {
    $envPath = Join-Path $targetDevContainer ".env"
    if (-not (Test-Path $envPath)) {
        $envExample = Join-Path $targetDevContainer ".env.example"
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
            Write-Host "  ✓ Created .env file" -ForegroundColor Green
        }
    } else {
        Write-Host "  ℹ .env exists (kept existing)" -ForegroundColor Gray
    }
}

# Quick analysis
Write-Host ""
Write-Host "Project Analysis:" -ForegroundColor Cyan
$characteristics = @()

if (Test-Path (Join-Path $ProjectPath "requirements.txt")) {
    $characteristics += "🐍 Python (requirements.txt)"
}
if (Test-Path (Join-Path $ProjectPath "package.json")) {
    $characteristics += "📦 Node.js (package.json)"
}
if (Test-Path (Join-Path $ProjectPath "databricks.yml")) {
    $characteristics += "🔥 Databricks"
}
if (Test-Path (Join-Path $ProjectPath ".git")) {
    $characteristics += "📚 Git repository"
}

if ($characteristics.Count -gt 0) {
    foreach ($char in $characteristics) {
        Write-Host "  $char" -ForegroundColor White
    }
} else {
    Write-Host "  📁 Empty project" -ForegroundColor Gray
}

# Success message
Write-Host ""
Write-Host "✅ DevContainer deployed successfully!" -ForegroundColor Green
Write-Host ""

# Open VS Code if requested
if ($Open) {
    Write-Host "Opening in VS Code..." -ForegroundColor Cyan
    code $ProjectPath
} else {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. cd `"$ProjectPath`"" -ForegroundColor White
    Write-Host "  2. code ." -ForegroundColor White
    Write-Host "  3. Reopen in Container (Ctrl+Shift+P)" -ForegroundColor White
}

Write-Host ""
Write-Host "💡 Tip: Edit .devcontainer/.env for credentials" -ForegroundColor Gray