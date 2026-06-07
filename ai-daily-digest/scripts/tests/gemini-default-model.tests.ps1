$ErrorActionPreference = 'Stop'

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

$projectDir = Split-Path -Parent $PSScriptRoot
$repoDir = Split-Path -Parent $projectDir

$aiClientPath = Join-Path $projectDir 'lib\ai-client.ts'
$digestPath = Join-Path $projectDir 'digest.ts'
$envExamplePath = Join-Path $repoDir '.env.example'
$launcherPath = Join-Path $projectDir 'ai-daily-digest-launcher.ps1'

$aiClientContent = Get-Content -LiteralPath $aiClientPath -Raw
$digestContent = Get-Content -LiteralPath $digestPath -Raw
$envExampleContent = Get-Content -LiteralPath $envExamplePath -Raw
$launcherContent = Get-Content -LiteralPath $launcherPath -Raw

$expectedGeminiModel = 'gemini-3.1-pro-preview'

$aiClientDefault = [regex]::Match($aiClientContent, "GEMINI_DEFAULT_MODEL\s*=\s*'([^']+)'").Groups[1].Value
$digestHelpDefault = [regex]::Match($digestContent, 'GEMINI_MODEL\s+Optional Gemini model \(default: ([^)]+)\)').Groups[1].Value
$envExampleDefault = [regex]::Match($envExampleContent, 'GEMINI_MODEL=([^\r\n]+)').Groups[1].Value
$launcherDefault = [regex]::Match($launcherContent, "default \{ '([^']+)' \}").Groups[1].Value

Assert-Equal $aiClientDefault $expectedGeminiModel 'ai-client default Gemini model should match the project default'
Assert-Equal $digestHelpDefault $expectedGeminiModel 'digest help text should describe the same Gemini default'
Assert-Equal $envExampleDefault $expectedGeminiModel '.env.example should advertise the same Gemini default'
Assert-Equal $launcherDefault $expectedGeminiModel 'launcher default Gemini model should match the project default'

Write-Host 'All gemini-default-model tests passed.'
