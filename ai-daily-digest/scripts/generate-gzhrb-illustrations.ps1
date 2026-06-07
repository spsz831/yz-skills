param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$IllustrationsRoot,
    [string]$IllustrationGeneratorScriptPath
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Get-DefaultIllustrationGeneratorScriptPath {
    $projectDir = Get-ProjectDir
    $candidatePaths = @()

    if (-not [string]::IsNullOrWhiteSpace($env:ILLUSTRATION_GENERATOR_SCRIPT_PATH)) {
        $candidatePaths += $env:ILLUSTRATION_GENERATOR_SCRIPT_PATH
    }

    $searchRoots = @(
        (Join-Path $projectDir '.cc-switch\skills'),
        'C:\Users\spsz0\.cc-switch\skills',
        'C:\Users\spsz0\.codex\skills'
    )

    foreach ($searchRoot in $searchRoots) {
        if (-not (Test-Path -LiteralPath $searchRoot)) {
            continue
        }

        $discovered = Get-ChildItem -LiteralPath $searchRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'scripts\main.ts' }
        $candidatePaths += $discovered
    }

    foreach ($candidatePath in $candidatePaths) {
        if (-not [string]::IsNullOrWhiteSpace($candidatePath) -and (Test-Path -LiteralPath $candidatePath)) {
            return $candidatePath
        }
    }

    if ($candidatePaths.Count -gt 0) {
        return $candidatePaths[0]
    }

    return Join-Path $projectDir '.cc-switch\skills\<illustration-generator>\scripts\main.ts'
}

function Get-LatestGzhrbArticlePath {
    param([Parameter(Mandatory)][string]$GzhrbDir)

    if (-not (Test-Path -LiteralPath $GzhrbDir)) {
        throw "GZHRB directory not found: $GzhrbDir"
    }

    $latest = Get-ChildItem -LiteralPath $GzhrbDir -Filter 'gzhrb-*.md' -File |
        Sort-Object LastWriteTime, FullName -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "No GZHRB article found in: $GzhrbDir"
    }

    return $latest.FullName
}

function Get-ArticleId {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
    if ($fileName -eq 'article') {
        $parentDir = Split-Path -Parent $ArticlePath
        return Split-Path -Leaf $parentDir
    }

    return $fileName
}

function Get-ArticleIllustrationDir {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$IllustrationsRoot
    )

    if (-not (Test-Path -LiteralPath $ArticlePath)) {
        throw "Article file not found: $ArticlePath"
    }

    if (-not (Test-Path -LiteralPath $IllustrationsRoot)) {
        throw "Illustrations root not found: $IllustrationsRoot"
    }

    $articleDir = Join-Path $IllustrationsRoot (Get-ArticleId -ArticlePath $ArticlePath)
    if (-not (Test-Path -LiteralPath $articleDir)) {
        throw "Article illustration directory not found: $articleDir"
    }

    return $articleDir
}

function Get-ArticleBatchPath {
    param(
        [string]$ArticlePath,
        [string]$GzhrbDir,
        [Parameter(Mandatory)][string]$IllustrationsRoot
    )

    if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
        if ([string]::IsNullOrWhiteSpace($GzhrbDir)) {
            throw 'GzhrbDir is required when ArticlePath is omitted.'
        }

        $ArticlePath = Get-LatestGzhrbArticlePath -GzhrbDir $GzhrbDir
    }

    $articleDir = Get-ArticleIllustrationDir -ArticlePath $ArticlePath -IllustrationsRoot $IllustrationsRoot
    $batchPath = Join-Path $articleDir 'batch.json'

    if (-not (Test-Path -LiteralPath $batchPath)) {
        throw "Batch file not found: $batchPath"
    }

    return $batchPath
}

function Resolve-BunTool {
    param(
        $CommandInfo,
        [string]$NpxCommandPath
    )

    if ($CommandInfo) {
        return [pscustomobject]@{
            CommandPath = $CommandInfo.Source
            Arguments   = @()
        }
    }

    if ([string]::IsNullOrWhiteSpace($NpxCommandPath)) {
        $npxCommand = Get-Command npx.cmd -ErrorAction SilentlyContinue
        if (-not $npxCommand) {
            $npxCommand = Get-Command npx -ErrorAction SilentlyContinue
        }
        if ($npxCommand) {
            $NpxCommandPath = $npxCommand.Source
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($NpxCommandPath)) {
        return [pscustomobject]@{
            CommandPath = $NpxCommandPath
            Arguments   = @('-y', 'bun')
        }
    }

    throw 'Unable to find bun or npx for illustration generation execution.'
}

function Get-ResolvedBunTool {
    $bunCommand = Get-Command bun -ErrorAction SilentlyContinue
    if (-not $bunCommand) {
        $bunCommand = Get-Command bun.cmd -ErrorAction SilentlyContinue
    }

    return Resolve-BunTool -CommandInfo $bunCommand
}

function New-GzhrbIllustrationCommand {
    param(
        [Parameter(Mandatory)][string]$BatchPath,
        [Parameter(Mandatory)][string]$IllustrationGeneratorScriptPath,
        [Parameter(Mandatory)]$BunTool
    )

    $workingDirectory = Split-Path -Parent $BatchPath
    $arguments = @()
    if ($BunTool.Arguments) {
        $arguments += $BunTool.Arguments
    }
    $arguments += @(
        $IllustrationGeneratorScriptPath,
        '--batchfile',
        $BatchPath,
        '--jobs',
        '2',
        '--json'
    )

    return [pscustomobject]@{
        CommandPath      = $BunTool.CommandPath
        Arguments        = $arguments
        WorkingDirectory = $workingDirectory
    }
}

function Invoke-GzhrbIllustrationCommand {
    param([Parameter(Mandatory)]$Invocation)

    Push-Location $Invocation.WorkingDirectory
    try {
        $commandArguments = @($Invocation.Arguments)
        & $Invocation.CommandPath @commandArguments
        if ($LASTEXITCODE -ne 0) {
            throw "GZHRB illustration generation failed. Exit code: $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Start-GzhrbIllustrationGeneration {
    $projectDir = Get-ProjectDir

    if ([string]::IsNullOrWhiteSpace($GzhrbDir)) {
        $GzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    }

    if ([string]::IsNullOrWhiteSpace($IllustrationsRoot)) {
        $IllustrationsRoot = Join-Path $GzhrbDir 'illustrations'
    }

    if ([string]::IsNullOrWhiteSpace($IllustrationGeneratorScriptPath)) {
        $IllustrationGeneratorScriptPath = Get-DefaultIllustrationGeneratorScriptPath
    }

    if (-not (Test-Path -LiteralPath $IllustrationGeneratorScriptPath)) {
        throw "Illustration generator script not found: $IllustrationGeneratorScriptPath"
    }

    $batchPath = Get-ArticleBatchPath -ArticlePath $ArticlePath -GzhrbDir $GzhrbDir -IllustrationsRoot $IllustrationsRoot
    $bunTool = Get-ResolvedBunTool
    $invocation = New-GzhrbIllustrationCommand `
        -BatchPath $batchPath `
        -IllustrationGeneratorScriptPath $IllustrationGeneratorScriptPath `
        -BunTool $bunTool

    Invoke-GzhrbIllustrationCommand -Invocation $invocation
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbIllustrationGeneration
}
