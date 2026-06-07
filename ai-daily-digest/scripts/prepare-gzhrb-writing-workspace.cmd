@echo off
setlocal EnableExtensions
title Prepare GZHRB Writing Workspace

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%prepare-gzhrb-writing-workspace.ps1"

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  pause
  exit /b 1
)

if not exist "%PS1%" (
  echo [ERROR] Script not found: %PS1%
  pause
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [ERROR] Script exited with code %RC%.
  pause
)
exit /b %RC%

