@echo off
setlocal EnableExtensions
title Mark GZHRB Khazix Complete

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%mark-gzhrb-khazix-complete.ps1"
set "NO_PAUSE="

if /I "%~1"=="--no-pause" (
  set "NO_PAUSE=1"
  shift
)

set "ARG1=%~1"
if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  if not defined NO_PAUSE pause
  exit /b 1
)

if not exist "%PS1%" (
  echo [ERROR] Script not found: %PS1%
  if not defined NO_PAUSE pause
  exit /b 1
)

if "%ARG1%"=="" (
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%PS1%'"
) else (
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%PS1%' -ArticlePath '%ARG1%'; Set-GzhrbKhazixComplete -ArticlePath '%ARG1%' | ConvertTo-Json -Depth 5"
)
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
  echo.
  echo [ERROR] Script exited with code %RC%.
)

if not defined NO_PAUSE (
  echo.
  pause
)

exit /b %RC%
