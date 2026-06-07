$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'generate-gzhrb-illustrations.ps1'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
}

. $scriptPath

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "Assert-Equal failed: $Message`nExpected: $Expected`nActual: $Actual"
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assert-True failed: $Message"
    }
}

function Assert-ThrowsLike {
    param(
        [scriptblock]$Action,
        [string]$ExpectedMessage,
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -like "*$ExpectedMessage*") {
            return
        }

        throw "Assert-ThrowsLike failed: $Message`nExpected error like: $ExpectedMessage`nActual error: $($_.Exception.Message)"
    }

    throw "Assert-ThrowsLike failed: $Message`nExpected an exception containing: $ExpectedMessage"
}

function New-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Write-TestUtf8File {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (New-Utf8NoBomEncoding))
}

function Read-TestUtf8File {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$tempRoot = Join-Path $env:TEMP ("gzhrb generate test " + [guid]::NewGuid().ToString('N'))

try {
    $tempRoot = Join-Path $tempRoot 'with spaces'
    $gzhrbDir = Join-Path $tempRoot 'reports\gzhrb'
    $illustrationsRoot = Join-Path $gzhrbDir 'illustrations'
    $olderArticlePath = Join-Path $gzhrbDir 'gzhrb-20260415-1600.md'
    $latestArticlePath = Join-Path $gzhrbDir 'gzhrb-20260415-1700.md'
    $latestArticleId = 'gzhrb-20260415-1700'
    $expectedIllustrationDir = Join-Path $illustrationsRoot $latestArticleId
    $expectedBatchPath = Join-Path $expectedIllustrationDir 'batch.json'
    $expectedGeneratorScript = Join-Path $tempRoot 'fake illustration generator\main.ts'
    $articleScopedDir = Join-Path $gzhrbDir "articles\$latestArticleId"
    $articleScopedPath = Join-Path $articleScopedDir 'article.md'

    New-Item -ItemType Directory -Force -Path $expectedIllustrationDir | Out-Null
    New-Item -ItemType Directory -Force -Path $articleScopedDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $expectedGeneratorScript) | Out-Null
    Write-TestUtf8File -Path $olderArticlePath -Content '# Older article'
    Write-TestUtf8File -Path $latestArticlePath -Content '# Latest article'
    Write-TestUtf8File -Path $articleScopedPath -Content '# Scoped article'
    Write-TestUtf8File -Path $expectedBatchPath -Content '{"jobs":2,"tasks":[]}'
    Write-TestUtf8File -Path $expectedGeneratorScript -Content '// fake illustration generator entrypoint'
    (Get-Item -LiteralPath $olderArticlePath).LastWriteTime = [datetime]'2026-04-15T16:00:00'
    (Get-Item -LiteralPath $latestArticlePath).LastWriteTime = [datetime]'2026-04-15T17:00:00'

    $resolvedBatchPath = Get-ArticleBatchPath -ArticlePath $latestArticlePath -IllustrationsRoot $illustrationsRoot
    Assert-Equal $resolvedBatchPath $expectedBatchPath 'Should resolve the article-scoped batch.json path'

    $resolvedIllustrationDir = Get-ArticleIllustrationDir -ArticlePath $latestArticlePath -IllustrationsRoot $illustrationsRoot
    Assert-Equal $resolvedIllustrationDir $expectedIllustrationDir 'Should resolve the article-scoped illustration directory'
    $resolvedScopedIllustrationDir = Get-ArticleIllustrationDir -ArticlePath $articleScopedPath -IllustrationsRoot $illustrationsRoot
    Assert-Equal $resolvedScopedIllustrationDir $expectedIllustrationDir 'Should resolve the parent article id when source path is article.md'

    $tieDir = Join-Path $tempRoot 'tie-gzhrb'
    $firstTiePath = Join-Path $tieDir 'gzhrb-20260415-1710.md'
    $secondTiePath = Join-Path $tieDir 'gzhrb-20260415-1711.md'
    New-Item -ItemType Directory -Force -Path $tieDir | Out-Null
    Write-TestUtf8File -Path $firstTiePath -Content '# First tie article'
    Write-TestUtf8File -Path $secondTiePath -Content '# Second tie article'
    $tieTimestamp = [datetime]'2026-04-15T18:00:00'
    (Get-Item -LiteralPath $firstTiePath).LastWriteTime = $tieTimestamp
    (Get-Item -LiteralPath $secondTiePath).LastWriteTime = $tieTimestamp

    $latestTiePath = Get-LatestGzhrbArticlePath -GzhrbDir $tieDir
    Assert-Equal $latestTiePath $secondTiePath 'Should break latest-article ties deterministically by file path'

    $resolvedLatestBatchPath = Get-ArticleBatchPath -GzhrbDir $gzhrbDir -IllustrationsRoot $illustrationsRoot
    Assert-Equal $resolvedLatestBatchPath $expectedBatchPath 'Should default to the latest GZHRB article when article path is omitted'

    $originalEnvGeneratorPath = $env:ILLUSTRATION_GENERATOR_SCRIPT_PATH
    $env:ILLUSTRATION_GENERATOR_SCRIPT_PATH = $expectedGeneratorScript
    $resolvedDefaultScriptPath = Get-DefaultIllustrationGeneratorScriptPath
    Assert-Equal $resolvedDefaultScriptPath $expectedGeneratorScript 'Should prefer the explicit illustration generator script path when provided'
    $env:ILLUSTRATION_GENERATOR_SCRIPT_PATH = $originalEnvGeneratorPath

    $bunTool = Resolve-BunTool -CommandInfo ([pscustomobject]@{ Source = 'C:\tools\bun.exe' })
    Assert-Equal $bunTool.CommandPath 'C:\tools\bun.exe' 'Should prefer a discovered bun executable'
    Assert-Equal $bunTool.Arguments.Count 0 'Discovered bun executable should not require bootstrap arguments'

    $fallbackBunTool = Resolve-BunTool -CommandInfo $null -NpxCommandPath 'C:\tools\npx.cmd'
    Assert-Equal $fallbackBunTool.CommandPath 'C:\tools\npx.cmd' 'Should fall back to npx when bun is unavailable'
    Assert-Equal $fallbackBunTool.Arguments.Count 2 'npx fallback should add the expected bootstrap arguments'
    Assert-Equal $fallbackBunTool.Arguments[0] '-y' 'npx fallback should pass -y'
    Assert-Equal $fallbackBunTool.Arguments[1] 'bun' 'npx fallback should invoke bun via npx'

    $invocation = New-GzhrbIllustrationCommand `
        -BatchPath $expectedBatchPath `
        -IllustrationGeneratorScriptPath $expectedGeneratorScript `
        -BunTool ([pscustomobject]@{
                CommandPath = 'C:\tools\bun.exe'
                Arguments = @()
            })

    Assert-Equal $invocation.CommandPath 'C:\tools\bun.exe' 'Should build the invocation around the resolved bun executable'
    Assert-Equal $invocation.WorkingDirectory $expectedIllustrationDir 'Should run image generation in the article-scoped illustration directory'
    Assert-Equal $invocation.Arguments[0] $expectedGeneratorScript 'Should invoke the illustration generator entrypoint'
    Assert-True ($invocation.Arguments -contains '--batchfile') 'Should include --batchfile'
    Assert-True ($invocation.Arguments -contains $expectedBatchPath) 'Should include the resolved batch.json path'
    Assert-True ($invocation.Arguments -contains '--jobs') 'Should include --jobs'
    Assert-True ($invocation.Arguments -contains '2') 'Should request two jobs'
    Assert-True ($invocation.Arguments -contains '--json') 'Should request JSON output'

    $fallbackInvocation = New-GzhrbIllustrationCommand `
        -BatchPath $expectedBatchPath `
        -IllustrationGeneratorScriptPath $expectedGeneratorScript `
        -BunTool $fallbackBunTool

    Assert-Equal $fallbackInvocation.CommandPath 'C:\tools\npx.cmd' 'Fallback invocation should execute through npx'
    Assert-Equal $fallbackInvocation.Arguments[0] '-y' 'Fallback invocation should keep the npx bootstrap prefix'
    Assert-Equal $fallbackInvocation.Arguments[1] 'bun' 'Fallback invocation should bootstrap bun through npx'
    Assert-Equal $fallbackInvocation.Arguments[2] $expectedGeneratorScript 'Fallback invocation should still target the illustration generator'

    $stubDir = Join-Path $tempRoot 'stub tools'
    $successStubPath = Join-Path $stubDir 'success stub.cmd'
    $failStubPath = Join-Path $stubDir 'fail stub.cmd'
    $cwdLogPath = Join-Path $stubDir 'cwd log.txt'
    $argsLogPath = Join-Path $stubDir 'args log.txt'
    New-Item -ItemType Directory -Force -Path $stubDir | Out-Null

    $successStubLines = @(
        '@echo off',
        'setlocal EnableExtensions',
        'set "CWD_LOG=%~1"',
        'set "ARGS_LOG=%~2"',
        'shift',
        'shift',
        '> "%CWD_LOG%" echo %CD%',
        'break > "%ARGS_LOG%"',
        ':loop',
        'if "%~1"=="" goto done',
        '>> "%ARGS_LOG%" echo %~1',
        'shift',
        'goto loop',
        ':done',
        'exit /b 0'
    )
    Write-TestUtf8File -Path $successStubPath -Content ([string]::Join("`r`n", $successStubLines))

    $failStubLines = @(
        '@echo off',
        'exit /b 7'
    )
    Write-TestUtf8File -Path $failStubPath -Content ([string]::Join("`r`n", $failStubLines))

    $realInvocation = [pscustomobject]@{
        CommandPath      = $successStubPath
        Arguments        = @(
            $cwdLogPath,
            $argsLogPath,
            $expectedGeneratorScript,
            '--batchfile',
            $expectedBatchPath,
            '--jobs',
            '2',
            '--json'
        )
        WorkingDirectory = $expectedIllustrationDir
    }

    $originalLocation = (Get-Location).ProviderPath
    Invoke-GzhrbIllustrationCommand -Invocation $realInvocation
    Assert-Equal (Get-Location).ProviderPath $originalLocation 'Should restore the original working directory after execution'

    $loggedCwd = (Read-TestUtf8File -Path $cwdLogPath).Trim()
    Assert-Equal $loggedCwd $expectedIllustrationDir 'Should launch the process from the article illustration directory'

    $loggedArgs = @((Get-Content -LiteralPath $argsLogPath))
    Assert-Equal $loggedArgs.Count 6 'Should pass six payload arguments to the stub command'
    Assert-Equal $loggedArgs[0] $expectedGeneratorScript 'Should preserve a script path containing spaces'
    Assert-Equal $loggedArgs[1] '--batchfile' 'Should preserve the --batchfile flag'
    Assert-Equal $loggedArgs[2] $expectedBatchPath 'Should preserve a batch path containing spaces'
    Assert-Equal $loggedArgs[3] '--jobs' 'Should preserve the --jobs flag'
    Assert-Equal $loggedArgs[4] '2' 'Should preserve the jobs value'
    Assert-Equal $loggedArgs[5] '--json' 'Should preserve the --json flag'

    Assert-ThrowsLike {
        Invoke-GzhrbIllustrationCommand -Invocation ([pscustomobject]@{
                CommandPath      = $failStubPath
                Arguments        = @()
                WorkingDirectory = $expectedIllustrationDir
            })
    } 'GZHRB illustration generation failed. Exit code: 7' 'Should throw when the external generation exits non-zero'

    $missingBatchArticlePath = Join-Path $gzhrbDir 'gzhrb-20260415-1800.md'
    $missingBatchDir = Join-Path $illustrationsRoot 'gzhrb-20260415-1800'
    Write-TestUtf8File -Path $missingBatchArticlePath -Content '# Missing batch article'
    New-Item -ItemType Directory -Force -Path $missingBatchDir | Out-Null

    Assert-ThrowsLike {
        Get-ArticleBatchPath -ArticlePath $missingBatchArticlePath -IllustrationsRoot $illustrationsRoot
    } 'Batch file not found:' 'Should fail clearly when batch.json is missing'

    Assert-ThrowsLike {
        Get-ArticleBatchPath -ArticlePath $latestArticlePath -IllustrationsRoot (Join-Path $tempRoot 'missing-illustrations-root')
    } 'Illustrations root not found:' 'Should fail clearly when illustrations root is missing'

    Assert-ThrowsLike {
        Get-ArticleBatchPath -ArticlePath (Join-Path $gzhrbDir 'gzhrb-20260415-1900.md') -IllustrationsRoot $illustrationsRoot
    } 'Article file not found:' 'Should fail clearly when the requested article file is missing'

    Assert-ThrowsLike {
        Get-ArticleBatchPath -ArticlePath $latestArticlePath -IllustrationsRoot (Join-Path $tempRoot 'reports\gzhrb')
    } 'Article illustration directory not found:' 'Should fail clearly when the article directory is missing'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
