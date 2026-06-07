@echo off
setlocal EnableExtensions
title GZHRB Writing State

set "SCRIPT_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "NO_PAUSE="
set "ACTION="
set "ARTICLE_PATH="
set "LIMIT=5"

if /I "%~1"=="--no-pause" (
  set "NO_PAUSE=1"
  shift
)

if "%~1"=="" goto usage_success
set "ACTION=%~1"
shift

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--article" goto parse_article
if /I "%~1"=="--limit" goto parse_limit
if "%ARTICLE_PATH%"=="" set "ARTICLE_PATH=%~1"
shift
goto parse_args

:parse_article
shift
if "%~1"=="" (
  echo [ERROR] Missing value for --article
  goto usage_error
)
set "ARTICLE_PATH=%~1"
shift
goto parse_args

:parse_limit
shift
if "%~1"=="" (
  echo [ERROR] Missing value for --limit
  goto usage_error
)
set "LIMIT=%~1"
shift
goto parse_args

:args_done
set "TARGET_CMD="
set "TARGET_PS1="
set "APPROVAL_STAGE="

if /I "%ACTION%"=="help" goto usage_success
if /I "%ACTION%"=="inspect" set "TARGET_CMD=%SCRIPT_DIR%inspect-gzhrb-writing-state.cmd"
if /I "%ACTION%"=="inspect-json" set "TARGET_PS1=%SCRIPT_DIR%inspect-gzhrb-writing-state.ps1"
if /I "%ACTION%"=="auto-sync" set "TARGET_PS1=%SCRIPT_DIR%gzhrb-writing-state.ps1"
if /I "%ACTION%"=="status-summary" set "TARGET_PS1=%SCRIPT_DIR%gzhrb-writing-state.ps1"
if /I "%ACTION%"=="status-summary-json" set "TARGET_PS1=%SCRIPT_DIR%gzhrb-writing-state.ps1"
if /I "%ACTION%"=="mark-khazix" set "TARGET_CMD=%SCRIPT_DIR%mark-gzhrb-khazix-complete.cmd"
if /I "%ACTION%"=="mark-wechat" set "TARGET_CMD=%SCRIPT_DIR%mark-gzhrb-wechat-complete.cmd"
if /I "%ACTION%"=="approve-topic" (
  set "TARGET_CMD=%SCRIPT_DIR%approve-gzhrb-stage.cmd"
  set "APPROVAL_STAGE=topic_selected"
)
if /I "%ACTION%"=="approve-khazix" (
  set "TARGET_CMD=%SCRIPT_DIR%approve-gzhrb-stage.cmd"
  set "APPROVAL_STAGE=khazix_approved"
)
if /I "%ACTION%"=="approve-wechat" (
  set "TARGET_CMD=%SCRIPT_DIR%approve-gzhrb-stage.cmd"
  set "APPROVAL_STAGE=wechat_approved"
)
if /I "%ACTION%"=="approve-illustrations" (
  set "TARGET_CMD=%SCRIPT_DIR%approve-gzhrb-stage.cmd"
  set "APPROVAL_STAGE=illustrations_approved"
)

if "%TARGET_CMD%"=="" if "%TARGET_PS1%"=="" (
  echo [ERROR] Unknown action: %ACTION%
  goto usage_error
)

if /I not "%ACTION%"=="status-summary" if /I not "%ACTION%"=="status-summary-json" if "%ARTICLE_PATH%"=="" (
  echo [ERROR] Article path is required for action: %ACTION%
  goto usage_error
)

if not exist "%PS_EXE%" (
  echo [ERROR] PowerShell not found: %PS_EXE%
  if not defined NO_PAUSE pause
  exit /b 1
)

if not "%TARGET_PS1%"=="" (
  if not exist "%TARGET_PS1%" (
    echo [ERROR] Target script not found: %TARGET_PS1%
    if not defined NO_PAUSE pause
    exit /b 1
  )
  if /I "%ACTION%"=="inspect-json" (
    "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%TARGET_PS1%' -ArticlePath '%ARTICLE_PATH%'; Get-GzhrbWritingStateValidation -ArticlePath '%ARTICLE_PATH%' | ConvertTo-Json -Depth 8"
  ) else if /I "%ACTION%"=="auto-sync" (
    "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%TARGET_PS1%' -ArticlePath '__bootstrap__'; Invoke-GzhrbWritingStateAutoSync -ArticlePath '%ARTICLE_PATH%' -UpdatedBy 'auto-sync' | ConvertTo-Json -Depth 8"
  ) else if /I "%ACTION%"=="status-summary" (
    "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%TARGET_PS1%'; Get-GzhrbWritingStateStatusSummary -Limit %LIMIT%"
  ) else if /I "%ACTION%"=="status-summary-json" (
    "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -Command ". '%TARGET_PS1%'; Get-GzhrbWritingStateStatusSummaryJson -Limit %LIMIT% | ConvertTo-Json -Depth 8"
  )
  exit /b %ERRORLEVEL%
)

if not exist "%TARGET_CMD%" (
  echo [ERROR] Target command not found: %TARGET_CMD%
  if not defined NO_PAUSE pause
  exit /b 1
)

if defined NO_PAUSE (
  if not "%APPROVAL_STAGE%"=="" (
    call "%TARGET_CMD%" --no-pause -ArticlePath "%ARTICLE_PATH%" -Stage "%APPROVAL_STAGE%"
  ) else (
    call "%TARGET_CMD%" --no-pause "%ARTICLE_PATH%"
  )
) else (
  if not "%APPROVAL_STAGE%"=="" (
    call "%TARGET_CMD%" -ArticlePath "%ARTICLE_PATH%" -Stage "%APPROVAL_STAGE%"
  ) else (
    call "%TARGET_CMD%" "%ARTICLE_PATH%"
  )
)
exit /b %ERRORLEVEL%

:usage_success
echo Usage:
echo   scripts\gzhrb-writing-state.cmd [--no-pause] inspect ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] inspect-json ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] auto-sync ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] status-summary [--limit ^<n^>]
echo   scripts\gzhrb-writing-state.cmd [--no-pause] status-summary-json [--limit ^<n^>]
echo   scripts\gzhrb-writing-state.cmd [--no-pause] mark-khazix ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] mark-wechat ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-topic ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-khazix ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-wechat ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-illustrations ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] inspect --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] inspect-json --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] auto-sync --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] mark-khazix --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] mark-wechat --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-topic --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-khazix --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-wechat --article ^<article-path^>
echo   scripts\gzhrb-writing-state.cmd [--no-pause] approve-illustrations --article ^<article-path^>
if not defined NO_PAUSE (
  echo.
  pause
)
exit /b 0

:usage_error
call :usage_success
exit /b 1
