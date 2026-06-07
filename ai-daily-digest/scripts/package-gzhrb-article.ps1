param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$ApiBase,
    [string]$ApiKey,
    [string]$Model,
    [string]$WireApi
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Import-EnvFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.TrimStart().StartsWith('#')) { continue }

        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) { continue }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim().Trim('"').Trim("'")
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $existing = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ([string]::IsNullOrWhiteSpace($existing)) {
            [Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
}

function Initialize-Env {
    $projectDir = Get-ProjectDir
    Import-EnvFile -Path (Join-Path $projectDir '.env')
    Import-EnvFile -Path (Join-Path $projectDir '.env.local')
}

function Resolve-OpenAIWireApi {
    param(
        [string]$WireApi,
        [string]$ApiBase
    )

    if (-not [string]::IsNullOrWhiteSpace($WireApi)) {
        return $WireApi
    }

    $normalizedBase = $ApiBase
    if (-not [string]::IsNullOrWhiteSpace($normalizedBase)) {
        $normalizedBase = $normalizedBase.Trim().ToLowerInvariant()
        if ($normalizedBase.Contains('rawchat.cn/codex')) {
            return 'responses'
        }
    }

    return 'chat'
}

function Start-GzhrbArticlePackaging {
    Initialize-Env

    $projectDir = Get-ProjectDir

    if ([string]::IsNullOrWhiteSpace($GzhrbDir)) {
        $GzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    }
    if ([string]::IsNullOrWhiteSpace($ApiBase)) {
        $ApiBase = if ($env:OPENAI_API_BASE) { $env:OPENAI_API_BASE } else { 'https://api.openai.com/v1' }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $ApiKey = $env:OPENAI_API_KEY
    }
    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = if ($env:OPENAI_MODEL) { $env:OPENAI_MODEL } else { 'gpt-5.4' }
    }
    if ([string]::IsNullOrWhiteSpace($WireApi)) {
        $WireApi = Resolve-OpenAIWireApi -WireApi $env:OPENAI_WIRE_API -ApiBase $ApiBase
    }

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw 'Missing OPENAI_API_KEY.'
    }

    $packagerTs = Join-Path $projectDir 'scripts\package-gzhrb-article.ts'
    if (-not (Test-Path -LiteralPath $packagerTs)) {
        throw "Packaging script not found: $packagerTs"
    }

    $env:OPENAI_API_BASE = $ApiBase
    $env:OPENAI_API_KEY = $ApiKey
    $env:OPENAI_MODEL = $Model
    $env:OPENAI_WIRE_API = $WireApi

    Push-Location $projectDir
    try {
        $npxCmd = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
        if (-not $npxCmd) {
            $npxCmd = (Get-Command npx -ErrorAction Stop).Source
        }

        $arguments = @('-y', 'bun', $packagerTs, '--gzhrb-dir', $GzhrbDir)
        if (-not [string]::IsNullOrWhiteSpace($ArticlePath)) {
            $arguments += @('--article', $ArticlePath)
        }

        & $npxCmd @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "GZHRB packaging failed. Exit code: $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbArticlePackaging
}
