@echo off
setlocal EnableExtensions
title AI杨侦探工作流发布流水线

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "LAUNCHER_PS1=%SCRIPT_DIR%ai-daily-digest-launcher.ps1"
if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  pause
  exit /b 1
)

for %%F in ("%LAUNCHER_PS1%") do (
  if not exist "%%~F" (
    echo [ERROR] Required script not found: %%~F
    pause
    exit /b 1
  )
)

echo [INFO] This launcher now runs the pre-writing half of the publish pipeline:
echo [INFO] digest generation + candidate topics + human topic gate + dual-skill writing workspace preparation.
echo [INFO] It intentionally stops before drafting because formal writing must go through khazix-writer and wechat-article-writer.
echo.

call :RunStage "digest generation + topic gate + writing workspace preparation" "%LAUNCHER_PS1%" -GenerateGzhrb -NoPause
if errorlevel 1 exit /b %errorlevel%

echo.
echo [STOP] Pre-writing pipeline completed.
echo [STOP] Next, use khazix-writer for the first draft and wechat-article-writer for the optimized article.
echo [STOP] After the optimized article exists, resume with:
echo [STOP]   scripts\run-gzhrb-postwriting-pipeline.cmd "E:\WorkCodex\ai-daily-digest\reports\gzhrb\<article-id>.md"
exit /b 0

:RunStage
set "STAGE_NAME=%~1"
set "STAGE_SCRIPT=%~2"
shift
shift

echo.
echo [INFO] Running %STAGE_NAME%...
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%STAGE_SCRIPT%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [ERROR] %STAGE_NAME% failed with exit code %RC%.
  pause
  exit /b %RC%
)
exit /b 0
