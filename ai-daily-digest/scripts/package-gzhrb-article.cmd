@echo off
setlocal EnableExtensions
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%package-gzhrb-article.ps1"

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  exit /b 1
)

if not exist "%PS1%" (
  echo [ERROR] Script not found: %PS1%
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
exit /b %ERRORLEVEL%
