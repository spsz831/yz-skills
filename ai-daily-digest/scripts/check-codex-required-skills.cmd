@echo off
setlocal EnableExtensions
title Check Required Codex Skills

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%check-codex-required-skills.ps1"
set "NO_PAUSE="

if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

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
  echo [ERROR] Required Codex skills check failed with code %RC%.
)

if not defined NO_PAUSE (
  echo.
  pause
)
exit /b %RC%
