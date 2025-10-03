# Install DevEnv Command Globally
# This script adds the .devcontainer/install folder to your PATH

param(
    [switch]$CurrentUserOnly = $true,
    [switch]$Uninstall = $false
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DevEnv Global Command Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the current script directory
$INSTALL_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if we're in the right place
if (-not (Test-Path (Join-Path $INSTALL_DIR "devenv.ps1"))) {
    Write-Host "Error: devenv.ps1 not found in current directory" -ForegroundColor Red
    Write-Host "  Please run this script from the .devcontainer/install folder" -ForegroundColor Yellow
    exit 1
}

# Get current PATH
$pathTarget = [System.EnvironmentVariableTarget]::User
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$scope = "current user"

if ($Uninstall) {
    # Remove from PATH
    Write-Host "Removing DevEnv from PATH..." -ForegroundColor Yellow

    if ($currentPath -like "*$INSTALL_DIR*") {
        # Remove this directory from PATH
        $pathArray = $currentPath -split ';' | Where-Object {
            $_ -ne $INSTALL_DIR -and $_ -ne "$INSTALL_DIR\"
        }
        $newPath = $pathArray -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, $pathTarget)

        Write-Host "Removed from PATH ($scope)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Please restart your terminal for changes to take effect" -ForegroundColor Yellow
    } else {
        Write-Host "DevEnv was not in PATH" -ForegroundColor Gray
    }
} else {
    # Install - Add to PATH
    Write-Host "Installing DevEnv command..." -ForegroundColor Yellow
    Write-Host "  Location: $INSTALL_DIR" -ForegroundColor Gray
    Write-Host "  Scope: $scope" -ForegroundColor Gray
    Write-Host ""

    # Check if already in PATH
    if ($currentPath -like "*$INSTALL_DIR*") {
        Write-Host "Already in PATH - updating location" -ForegroundColor Yellow

        # Remove old entry
        $pathArray = $currentPath -split ';' | Where-Object {
            $_ -ne $INSTALL_DIR -and $_ -ne "$INSTALL_DIR\"
        }
        $currentPath = $pathArray -join ';'
    }

    # Add to PATH
    $newPath = $currentPath + ";" + $INSTALL_DIR
    [Environment]::SetEnvironmentVariable("Path", $newPath, $pathTarget)

    Write-Host "DevEnv installed successfully!" -ForegroundColor Green
    Write-Host ""

    # Create PowerShell profile function
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent

    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $functionContent = @"

# DevEnv function for better parameter handling
function devenv {
    & "$INSTALL_DIR\devenv.ps1" `@args
}
"@

    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        if ($profileContent -notmatch "devenv") {
            Add-Content -Path $profilePath -Value $functionContent
            Write-Host "Added devenv function to PowerShell profile" -ForegroundColor Green
        }
    } else {
        $functionContent | Out-File $profilePath -Encoding UTF8
        Write-Host "Created PowerShell profile with devenv function" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now use DevEnv from anywhere:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  PowerShell:" -ForegroundColor Yellow
    Write-Host "    devenv C:\MyProject" -ForegroundColor White
    Write-Host "    devenv ." -ForegroundColor White
    Write-Host ""
    Write-Host "  Command Prompt:" -ForegroundColor Yellow
    Write-Host "    devenv.bat C:\MyProject" -ForegroundColor White
    Write-Host ""
    Write-Host "  With options:" -ForegroundColor Yellow
    Write-Host "    devenv C:\MyProject -Profile minimal -Open" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Restart your terminal for PATH changes to take effect" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Tips:" -ForegroundColor Cyan
    Write-Host "  - You can move the .devcontainer folder anywhere" -ForegroundColor Gray
    Write-Host "  - Just run install-devenv.ps1 again after moving" -ForegroundColor Gray
    Write-Host "  - Use 'devenv -Help' to see all options" -ForegroundColor Gray
}

# Test the installation
Write-Host ""
$testCommand = Read-Host "Test the command now? (Y/N)"
if ($testCommand -eq 'Y' -or $testCommand -eq 'y') {
    Write-Host ""
    Write-Host "Testing: devenv -Help" -ForegroundColor Cyan
    & "$INSTALL_DIR\devenv.ps1" -Help
}

# Keep window open to see results
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")