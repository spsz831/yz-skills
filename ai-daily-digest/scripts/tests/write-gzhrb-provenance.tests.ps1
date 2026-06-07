$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'write-gzhrb-provenance.ps1'

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

function New-TestFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

$tempRoot = Join-Path $env:TEMP ("write-gzhrb-provenance-" + [guid]::NewGuid().ToString('N'))
$articleDir = Join-Path $tempRoot 'reports\gzhrb\articles\gzhrb-test-20260423-1200-topic'
$articlePath = Join-Path $articleDir 'article.md'
$draftPath = Join-Path $tempRoot 'reports\gzhrb\drafts\gzhrb-test-20260423-1200-topic-khazix.md'

New-TestFile -Path $articlePath -Content '# article'
New-TestFile -Path $draftPath -Content '# khazix draft'

$result = Write-GzhrbProvenance `
    -ArticlePath $articlePath `
    -SkillName 'khazix-writer' `
    -InputPath $articlePath `
    -OutputPath $draftPath `
    -SessionId 'session-abc' `
    -Status 'completed' `
    -Note 'formal skill execution'

Assert-True (Test-Path -LiteralPath $result.path) 'Should create provenance file'
Assert-Equal ([System.IO.Path]::GetFileName($result.path)) 'khazix-execution.json' 'Should map khazix writer to khazix execution file'

$payload = Get-Content -Raw -LiteralPath $result.path | ConvertFrom-Json
Assert-Equal $payload.article_id 'gzhrb-test-20260423-1200-topic' 'Should persist article id'
Assert-Equal $payload.skill_name 'khazix-writer' 'Should persist skill name'
Assert-Equal $payload.session_id 'session-abc' 'Should persist session id'
Assert-Equal $payload.input_path $articlePath 'Should persist input path'
Assert-Equal $payload.output_path $draftPath 'Should persist output path'
Assert-Equal $payload.status 'completed' 'Should persist status'
Assert-Equal $payload.note 'formal skill execution' 'Should persist note'
Assert-True (-not [string]::IsNullOrWhiteSpace($payload.started_at)) 'Should persist started_at'
Assert-True (-not [string]::IsNullOrWhiteSpace($payload.completed_at)) 'Should persist completed_at'

$illustrationResult = Write-GzhrbProvenance `
    -ArticlePath $articlePath `
    -SkillName 'baoyu-article-illustrator' `
    -InputPath $articlePath `
    -OutputPath (Join-Path $tempRoot 'reports\gzhrb\illustrations\gzhrb-test-20260423-1200-topic') `
    -SessionId 'session-xyz' `
    -Status 'completed'

Assert-Equal ([System.IO.Path]::GetFileName($illustrationResult.path)) 'illustration-execution.json' 'Should map illustration skill to illustration execution file'

Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Host 'All write-gzhrb-provenance tests passed.'
