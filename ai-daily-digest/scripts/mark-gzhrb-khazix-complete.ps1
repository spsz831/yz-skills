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

function Set-GzhrbKhazixComplete {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath,
        [string]$UpdatedBy = 'manual-script'
    )

    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    if ([string]::IsNullOrWhiteSpace($WorkitemPath)) {
        $WorkitemPath = $validation.workitem_path
    }

    if (-not (Test-IsMeaningfulTextFile -Path $validation.khazix_draft_path)) {
        throw "Cannot mark khazix complete because draft is missing: $($validation.khazix_draft_path)"
    }

    if (Test-IsPlaceholderKhazixDraft -Path $validation.khazix_draft_path) {
        throw "Cannot mark khazix complete because draft is still a placeholder: $($validation.khazix_draft_path)"
    }

    if (-not $validation.provenance_state.khazix_execution.valid) {
        throw "Cannot mark khazix complete because provenance is missing or invalid: $($validation.provenance_dir)\khazix-execution.json"
    }

    $workitem = Read-GzhrbWorkitem -WorkitemPath $WorkitemPath
    $timestamp = Get-IsoTimestamp
    $workitem.stage = 'awaiting_khazix_approval'
    $workitem.writing_state.khazix.status = 'completed'
    $workitem.writing_state.khazix.completed_at = $timestamp
    $workitem.writing_state.khazix.updated_at = $timestamp
    $workitem.writing_state.khazix.updated_by = $UpdatedBy
    $workitem.writing_state.khazix.source_path = $validation.khazix_draft_path
    $workitem.execution_log = @($workitem.execution_log) + [pscustomobject]@{
        timestamp = $timestamp
        action = 'mark_khazix_complete'
        stage_after = 'awaiting_khazix_approval'
        updated_by = $UpdatedBy
        source_path = $validation.khazix_draft_path
        note = 'Validated non-placeholder khazix draft and khazix provenance before marking complete.'
    }
    Save-GzhrbWorkitem -Workitem $workitem -WorkitemPath $WorkitemPath

    return [pscustomobject]@{
        stage = $workitem.stage
        workitem_path = $WorkitemPath
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Set-GzhrbKhazixComplete -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath -UpdatedBy $UpdatedBy
    $result | ConvertTo-Json -Depth 5
}
