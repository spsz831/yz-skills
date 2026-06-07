$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'check-codex-required-skills.ps1'

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

$developerTextOk = "<skills_instructions>`n### Available skills`n- khazix-writer: test`n- wechat-article-writer: test`n- baoyu-article-illustrator: test`n### How to use skills`n</skills_instructions>"
$developerTextMissing = "<skills_instructions>`n### Available skills`n- baoyu-article-illustrator: test`n- ai-daily-digest: test`n### How to use skills`n</skills_instructions>"

$skillsSection = $developerTextOk.Substring(
    $developerTextOk.IndexOf('### Available skills'),
    $developerTextOk.IndexOf('### How to use skills') - $developerTextOk.IndexOf('### Available skills')
)
$matches = [System.Text.RegularExpressions.Regex]::Matches($skillsSection, '(?m)^- ([^:]+): ')
$parsedSkills = @($matches | ForEach-Object { $_.Groups[1].Value })

Assert-Equal $parsedSkills.Count 3 'Should parse all skills from the developer text section'
Assert-Equal $parsedSkills[0] 'khazix-writer' 'Should keep skill order'
Assert-Equal $parsedSkills[1] 'wechat-article-writer' 'Should parse second required skill'

$missing = Test-RequiredSkills -AvailableSkills $parsedSkills -RequiredSkills @('khazix-writer', 'wechat-article-writer')
Assert-Equal $missing.Count 0 'Should report no missing skills when both are injected'

$skillsSectionMissing = $developerTextMissing.Substring(
    $developerTextMissing.IndexOf('### Available skills'),
    $developerTextMissing.IndexOf('### How to use skills') - $developerTextMissing.IndexOf('### Available skills')
)
$matchesMissing = [System.Text.RegularExpressions.Regex]::Matches($skillsSectionMissing, '(?m)^- ([^:]+): ')
$parsedSkillsMissing = @($matchesMissing | ForEach-Object { $_.Groups[1].Value })

$missing = Test-RequiredSkills -AvailableSkills $parsedSkillsMissing -RequiredSkills @('khazix-writer', 'wechat-article-writer')
Assert-Equal $missing.Count 2 'Should report both required skills missing'
Assert-True ($missing -contains 'khazix-writer') 'Should report missing khazix-writer'
Assert-True ($missing -contains 'wechat-article-writer') 'Should report missing wechat-article-writer'

Write-Host 'All check-codex-required-skills tests passed.'
