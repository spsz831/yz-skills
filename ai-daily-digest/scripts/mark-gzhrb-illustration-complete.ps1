param(
    [Parameter(Mandatory)][string]$ArticlePath,
    [string]$WorkitemPath,
    [string]$UpdatedBy = 'manual-script'
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'validate-gzhrb-writing-state.ps1')

function Get-IsoTimestamp {
    return (Get-Date).ToString('o')
}

function Set-GzhrbIllustrationComplete {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath,
        [string]$UpdatedBy = 'manual-script'
    )

    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    if ([string]::IsNullOrWhiteSpace($WorkitemPath)) {
        $WorkitemPath = $validation.workitem_path
    }

    $illustrationDir = $validation.illustration_dir
    if (-not (Test-Path -LiteralPath $illustrationDir)) {
        throw "Cannot mark illustration complete because illustration directory is missing: $illustrationDir"
    }

    $imageFiles = @(
        Get-ChildItem -LiteralPath $illustrationDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.png', '.jpg', '.jpeg', '.webp', '.gif') }
    )
    if ($imageFiles.Count -eq 0) {
        throw "Cannot mark illustration complete because no generated image files were found in: $illustrationDir"
    }

    if (-not $validation.provenance_state.illustration_execution.valid) {
        throw "Cannot mark illustration complete because provenance is missing or invalid: $($validation.provenance_dir)\illustration-execution.json"
    }

    $workitem = Read-GzhrbWorkitem -WorkitemPath $WorkitemPath
    $timestamp = Get-IsoTimestamp
    $workitem.stage = 'awaiting_illustration_approval'
    $workitem.execution_log = @($workitem.execution_log) + [pscustomobject]@{
        timestamp = $timestamp
        action = 'mark_illustration_complete'
        stage_after = 'awaiting_illustration_approval'
        updated_by = $UpdatedBy
        source_path = $illustrationDir
        note = 'Validated illustration assets and illustration provenance before marking complete.'
    }
    Save-GzhrbWorkitem -Workitem $workitem -WorkitemPath $WorkitemPath

    return [pscustomobject]@{
        stage = $workitem.stage
        workitem_path = $WorkitemPath
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Set-GzhrbIllustrationComplete -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath -UpdatedBy $UpdatedBy
    $result | ConvertTo-Json -Depth 5
}
