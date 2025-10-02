@echo off
REM DevEnv Batch Wrapper - Handles spaces in paths correctly
REM This wrapper finds its own location and calls the PowerShell script

REM Get the directory where this batch file is located (handles spaces)
set "SCRIPT_DIR=%~dp0"

REM Remove trailing backslash
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM If no arguments provided, show interactive mode
if "%~1"=="" (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\devenv-fixed.ps1"
) else (
    REM Call PowerShell script with all arguments properly quoted
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\devenv-fixed.ps1" %*
)