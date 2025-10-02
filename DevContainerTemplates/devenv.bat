@echo off
REM DevEnv Batch Wrapper - Allows calling from CMD or Windows Terminal
REM This wrapper finds its own location and calls the PowerShell script

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Call the PowerShell script with all arguments
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%devenv.ps1" %*