@echo off
setlocal EnableExtensions
title AI杨侦探工作流 + 写作工作单

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

echo [INFO] This launcher will run: digest generation + topic gate + writing workspace preparation.
echo [INFO] 将连续执行：日报生成 + 人工选题 + 双 skill 写作工作单准备。
echo [INFO] It will stop before article drafting so khazix-writer and wechat-article-writer can take over.
echo.

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -GenerateGzhrb
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [ERROR] Combined flow exited with code %RC%.
  pause
)
exit /b %RC%
