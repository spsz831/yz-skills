@echo off
setlocal EnableExtensions
title AI Content Workflow Launcher
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%ai-daily-digest-launcher.ps1"

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  pause
  exit /b 1
)

if not exist "%PS1%" (
  echo [ERROR] Launcher script not found: %PS1%
  pause
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [ERROR] Launcher exited with code %RC%.
  pause
)
exit /b %RC%
