@echo off
setlocal EnableExtensions
title Approve GZHRB Stage

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%approve-gzhrb-stage.ps1"
set "NO_PAUSE="

if /I "%~1"=="--no-pause" (
  set "NO_PAUSE=1"
  shift
)

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

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %1 %2 %3 %4 %5 %6 %7 %8 %9
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
