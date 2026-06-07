$ErrorActionPreference = 'Stop'

function Get-SkillsFromDeveloperText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeveloperText
    )

    $normalizedText = $DeveloperText.Replace('\r\n', "`r`n").Replace('\n', "`n")

    $sectionStart = $normalizedText.IndexOf('### Available skills')
    if ($sectionStart -lt 0) {
        throw "Developer text does not contain '### Available skills'."
    }

    $sectionEnd = $normalizedText.IndexOf('### How to use skills')
    if ($sectionEnd -lt 0) {
        $sectionEnd = $normalizedText.Length
    }

    $skillsSection = $normalizedText.Substring($sectionStart, $sectionEnd - $sectionStart)
    $matches = [System.Text.RegularExpressions.Regex]::Matches(
        $skillsSection,
        '(?m)^\s*-\s*([^:\r\n]+):\s'
    )

    $skills = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $skills.Add($match.Groups[1].Value)
    }

    if ($skills.Count -eq 0) {
        throw "No skills could be parsed from the '### Available skills' section."
    }

    return ,$skills.ToArray()
}

function Get-LatestCodexSessionPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CodexHome
    )

    $sessionsRoot = Join-Path $CodexHome 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsRoot)) {
        throw "Codex sessions directory not found: $sessionsRoot"
    }

    $candidates = Get-ChildItem -LiteralPath $sessionsRoot -Recurse -Filter 'rollout-*.jsonl' -File |
        Sort-Object FullName -Descending

    if ($null -eq $candidates -or $candidates.Count -eq 0) {
        throw "No Codex session files found under: $sessionsRoot"
    }

    foreach ($candidate in $candidates) {
        try {
            $null = Get-AvailableSkillsFromSession -SessionPath $candidate.FullName
            return $candidate.FullName
        } catch {
            continue
        }
    }

    throw "No Codex session with '### Available skills' found under: $sessionsRoot"
}

function Get-AvailableSkillsFromSession {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SessionPath
    )

    if (-not (Test-Path -LiteralPath $SessionPath)) {
        throw "Codex session file not found: $SessionPath"
    }

    $rawText = Get-Content -Raw -LiteralPath $SessionPath
    if ([string]::IsNullOrWhiteSpace($rawText)) {
        throw "Codex session file is empty: $SessionPath"
    }

    $match = [System.Text.RegularExpressions.Regex]::Match(
        $rawText,
        '(?s)### Available skills.*?(?:### How to use skills|</skills_instructions>)'
    )

    if (-not $match.Success) {
        throw "Could not find a developer message with '### Available skills' in session: $SessionPath"
    }

    return Get-SkillsFromDeveloperText -DeveloperText $match.Value
}

function Test-RequiredSkills {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$AvailableSkills,
        [Parameter(Mandatory = $true)]
        [string[]]$RequiredSkills
    )

    $availableSet = @{}
    foreach ($skill in $AvailableSkills) {
        $availableSet[$skill] = $true
    }

    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($required in $RequiredSkills) {
        if (-not $availableSet.ContainsKey($required)) {
            $missing.Add($required)
        }
    }

    return ,$missing.ToArray()
}

function Invoke-CodexRequiredSkillsCheck {
    param(
        [string]$CodexHome = (Join-Path $HOME '.codex'),
        [string]$SessionPath,
        [string[]]$RequiredSkills = @('khazix-writer', 'wechat-article-writer')
    )

    if ([string]::IsNullOrWhiteSpace($SessionPath)) {
        $SessionPath = Get-LatestCodexSessionPath -CodexHome $CodexHome
    }

    $availableSkills = Get-AvailableSkillsFromSession -SessionPath $SessionPath
    $missingSkills = Test-RequiredSkills -AvailableSkills $availableSkills -RequiredSkills $RequiredSkills

    Write-Host "[INFO] Session: $SessionPath"
    Write-Host "[INFO] Available skills count: $($availableSkills.Count)"

    if ($missingSkills.Count -eq 0) {
        Write-Host "[OK] Required skills are injected into the current Codex session."
        foreach ($required in $RequiredSkills) {
            Write-Host "[OK] $required"
        }
        return 0
    }

    Write-Host "[FAIL] Required skills are missing from the current Codex session."
    foreach ($required in $RequiredSkills) {
        if ($missingSkills -contains $required) {
            Write-Host "[MISSING] $required"
        } else {
            Write-Host "[OK] $required"
        }
    }

    Write-Host "[STOP] Do not treat this window as the formal dual-skill writing environment."
    return 2
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-CodexRequiredSkillsCheck @PSBoundParameters)
}
