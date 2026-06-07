@echo off
setlocal EnableExtensions EnableDelayedExpansion
title GZHRB Post-Writing Pipeline

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PS1=%SCRIPT_DIR%run-gzhrb-postwriting-pipeline.ps1"
set "INSPECT_PS1=%SCRIPT_DIR%inspect-gzhrb-writing-state.ps1"
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

if "%~1"=="" (
  echo [ERROR] Article path is required.
  echo Example:
  echo   scripts\run-gzhrb-postwriting-pipeline.cmd "E:\WorkCodex\ai-daily-digest\reports\gzhrb\gzhrb-20260421-1328-kimi-k2-6-u53d1-u5e03-u5e76-u5f00-u6e90.md"
  if not defined NO_PAUSE pause
  exit /b 1
)

if exist "%INSPECT_PS1%" (
  echo.
  echo [INFO] Inspecting writing state before post-writing ...
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%INSPECT_PS1%" -ArticlePath "%~1"
  set "INSPECT_RC=%ERRORLEVEL%"
  if not "!INSPECT_RC!"=="0" (
    echo.
    echo [ERROR] Writing-state inspection failed with code !INSPECT_RC!.
    if not defined NO_PAUSE pause
    exit /b !INSPECT_RC!
  )
)

echo.
echo [INFO] Starting post-writing pipeline ...
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ArticlePath "%~1"
set "RC=%ERRORLEVEL%"
if not "!RC!"=="0" (
  echo.
  echo [ERROR] Script exited with code !RC!.
  if not defined NO_PAUSE pause
)

if not defined NO_PAUSE (
  echo.
  pause
)

exit /b !RC!
