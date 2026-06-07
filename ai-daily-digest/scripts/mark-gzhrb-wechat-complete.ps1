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

function Set-GzhrbWechatComplete {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath,
        [string]$UpdatedBy = 'manual-script'
    )

    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    if ([string]::IsNullOrWhiteSpace($WorkitemPath)) {
        $WorkitemPath = $validation.workitem_path
    }

    if (-not (Test-IsMeaningfulTextFile -Path $validation.optimized_article_path)) {
        throw "Cannot mark wechat complete because optimized article is missing or empty: $($validation.optimized_article_path)"
    }

    if (-not $validation.provenance_state.wechat_execution.valid) {
        throw "Cannot mark wechat complete because provenance is missing or invalid: $($validation.provenance_dir)\wechat-execution.json"
    }

    $workitem = Read-GzhrbWorkitem -WorkitemPath $WorkitemPath
    $timestamp = Get-IsoTimestamp
    $workitem.stage = 'awaiting_wechat_approval'
    $workitem.writing_state.wechat.status = 'completed'
    $workitem.writing_state.wechat.completed_at = $timestamp
    $workitem.writing_state.wechat.updated_at = $timestamp
    $workitem.writing_state.wechat.updated_by = $UpdatedBy
    $workitem.writing_state.wechat.source_path = $validation.optimized_article_path
    $workitem.execution_log = @($workitem.execution_log) + [pscustomobject]@{
        timestamp = $timestamp
        action = 'mark_wechat_complete'
        stage_after = 'awaiting_wechat_approval'
        updated_by = $UpdatedBy
        source_path = $validation.optimized_article_path
        note = 'Validated optimized article and wechat provenance before marking complete.'
    }
    Save-GzhrbWorkitem -Workitem $workitem -WorkitemPath $WorkitemPath

    return [pscustomobject]@{
        stage = $workitem.stage
        workitem_path = $WorkitemPath
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Set-GzhrbWechatComplete -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath -UpdatedBy $UpdatedBy
    $result | ConvertTo-Json -Depth 5
}
