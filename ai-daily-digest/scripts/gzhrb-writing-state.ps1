param(
    [string]$ArticlePath,
    [int]$Limit = 5,
    [string]$UpdatedBy = 'auto-sync',
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$boundArticlePath = $ArticlePath
$boundLimit = $Limit
$boundUpdatedBy = $UpdatedBy
$boundAction = $Action

. (Join-Path $PSScriptRoot 'validate-gzhrb-writing-state.ps1')
. (Join-Path $PSScriptRoot 'mark-gzhrb-khazix-complete.ps1') -ArticlePath '__bootstrap__'
. (Join-Path $PSScriptRoot 'mark-gzhrb-wechat-complete.ps1') -ArticlePath '__bootstrap__'
. (Join-Path $PSScriptRoot 'approve-gzhrb-stage.ps1')

$ArticlePath = $boundArticlePath
$Limit = $boundLimit
$UpdatedBy = $boundUpdatedBy
$Action = $boundAction

function Invoke-GzhrbWritingStateAutoSync {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$UpdatedBy = 'auto-sync'
    )

    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath
    if ($validation.stage -eq 'missing_workitem') {
        throw "Cannot auto-sync because formal workitem is missing: $($validation.workitem_path)"
    }

    $actions = New-Object System.Collections.Generic.List[string]

    # Keep historical khazix workitems usable while the default path moves to 2-lite.
    if ($null -ne $validation.writing_state.khazix -and
        [string]$validation.writing_state.khazix.status -ne 'completed' -and
        $validation.provenance_state.khazix_execution.valid) {
        Set-GzhrbKhazixComplete -ArticlePath $ArticlePath -WorkitemPath $validation.workitem_path -UpdatedBy $UpdatedBy | Out-Null
        [void]$actions.Add('mark_khazix_complete')
    }

    if ($validation.evidence_stage -in @('awaiting_topic_approval','awaiting_wechat_draft_execution','awaiting_wechat_draft_approval','awaiting_wechat_refinement_execution','awaiting_humanizer_execution','awaiting_writing_approval')) {
        return [pscustomobject]@{
            article_path = $ArticlePath
            actions = @()
            final_declared_stage = $validation.declared_stage
            final_evidence_stage = $validation.evidence_stage
            state_matches_evidence = $validation.state_matches_evidence
            reason = 'No sync was applied because the modern writing evidence is not ready yet.'
        }
    }

    return [pscustomobject]@{
        article_path = $ArticlePath
        actions = @($actions)
        final_declared_stage = $validation.declared_stage
        final_evidence_stage = $validation.evidence_stage
        state_matches_evidence = $validation.state_matches_evidence
        reason = if ($actions.Count -eq 0) { 'No sync was needed.' } else { 'Applied explicit state sync from file evidence.' }
    }
}

function Get-PathLeafBaseSafe {
    param([Parameter(Mandatory)][string]$Path)

    return [System.IO.Path]::GetFileNameWithoutExtension($Path)
}

function Get-GzhrbWritingStateStatusSummary {
    param(
        [int]$Limit = 5
    )

    $projectDir = Get-ProjectDir
    $gzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    $articleFiles = Get-GzhrbArticleFiles -GzhrbDir $gzhrbDir -Limit $Limit

    $lines = @(
        'Recent GZHRB writing states:'
    )

    foreach ($file in $articleFiles) {
        $validation = Get-GzhrbWritingStateValidation -ArticlePath $file.FullName
        $articleId = Get-PathLeafBaseSafe -Path $validation.workitem_path
        $lines += "- $articleId | declared=$($validation.declared_stage) | evidence=$($validation.evidence_stage) | draft=$($validation.writing_state.wechat_draft.status) | refine=$($validation.writing_state.wechat_refine.status) | humanizer=$($validation.writing_state.humanizer.status) | ready=$($validation.is_ready_for_postwriting)"
    }

    if ($articleFiles.Count -eq 0) {
        $lines += '- <none>'
    }

    return ($lines -join "`n")
}

function Get-GzhrbWritingStateStatusSummaryJson {
    param(
        [int]$Limit = 5
    )

    $projectDir = Get-ProjectDir
    $gzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    $articleFiles = Get-GzhrbArticleFiles -GzhrbDir $gzhrbDir -Limit $Limit

    $items = foreach ($file in $articleFiles) {
        $validation = Get-GzhrbWritingStateValidation -ArticlePath $file.FullName
        [pscustomobject]@{
            article_id = Get-PathLeafBaseSafe -Path $validation.workitem_path
            article_path = $file.FullName
            declared_stage = $validation.declared_stage
            evidence_stage = $validation.evidence_stage
            state_matches_evidence = $validation.state_matches_evidence
            wechat_draft_status = $validation.writing_state.wechat_draft.status
            wechat_refine_status = $validation.writing_state.wechat_refine.status
            humanizer_status = $validation.writing_state.humanizer.status
            is_ready_for_postwriting = $validation.is_ready_for_postwriting
            next_step = $validation.next_step
        }
    }

    return [pscustomobject]@{
        limit = $Limit
        count = @($items).Count
        items = @($items)
    }
}

function Get-GzhrbArticleFiles {
    param(
        [Parameter(Mandatory)][string]$GzhrbDir,
        [int]$Limit = 5
    )

    $articleFiles = @()
    $articlesDir = Join-Path $GzhrbDir 'articles'
    if (Test-Path -LiteralPath $articlesDir) {
        $articleFiles = @(
            Get-ChildItem -LiteralPath $articlesDir -Recurse -File -Filter 'article.md' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First $Limit
        )
    }

    if (@($articleFiles).Count -eq 0) {
        $articleFiles = @(
            Get-ChildItem -LiteralPath $GzhrbDir -File -Filter 'gzhrb-*.md' |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First $Limit
        )
    }

    return @($articleFiles)
}

function Invoke-GzhrbStageApproval {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$Stage,
        [string]$ApprovedBy = 'manual-approval'
    )

    return Set-GzhrbStageApproval -ArticlePath $ArticlePath -Stage $Stage -ApprovedBy $ApprovedBy
}

function Set-GzhrbModernWritingComplete {
    param([Parameter(Mandatory)][string]$ArticlePath, [Parameter(Mandatory)][ValidateSet('wechat_draft','wechat_refine','humanizer')][string]$Stage, [string]$UpdatedBy = 'manual-script')
    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath
    $workitem = Read-GzhrbWorkitem -WorkitemPath $validation.workitem_path
    $timestamp = (Get-Date).ToString('o')
    $stateName = $Stage
    $evidence = switch ($Stage) {
        'wechat_draft' { $validation.provenance_state.wechat_draft_execution.valid }
        'wechat_refine' { $validation.provenance_state.wechat_refine_execution.valid -and (Test-IsMeaningfulTextFile $validation.optimized_article_path) }
        'humanizer' { $validation.provenance_state.humanizer_execution.valid -and (Test-IsMeaningfulTextFile $validation.optimized_article_path) }
    }
    if (-not $evidence) { throw "Cannot mark $Stage complete because required output or provenance is missing." }
    $nextStage = switch ($Stage) {
        'wechat_draft' { 'awaiting_wechat_draft_approval' }
        'wechat_refine' { 'awaiting_humanizer_execution' }
        'humanizer' { 'awaiting_writing_approval' }
    }
    $sourcePath = if ($Stage -eq 'wechat_draft') { $validation.wechat_draft_path } else { $validation.optimized_article_path }
    $workitem.stage = $nextStage
    $workitem.writing_state.$stateName.status = 'completed'
    $workitem.writing_state.$stateName.completed_at = $timestamp
    $workitem.writing_state.$stateName.updated_at = $timestamp
    $workitem.writing_state.$stateName.updated_by = $UpdatedBy
    $workitem.writing_state.$stateName.source_path = $sourcePath
    $workitem.execution_log = @($workitem.execution_log) + [pscustomobject]@{ timestamp=$timestamp; action="mark_$Stage`_complete"; stage_after=$nextStage; updated_by=$UpdatedBy; source_path=$sourcePath }
    Save-GzhrbWorkitem -Workitem $workitem -WorkitemPath $validation.workitem_path
    [pscustomobject]@{ stage=$nextStage; workitem_path=$validation.workitem_path }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not [string]::IsNullOrWhiteSpace($Action)) {
        switch ($Action.ToLowerInvariant()) {
            'status-summary' {
                Get-GzhrbWritingStateStatusSummary -Limit $Limit
                exit 0
            }
            'status-summary-json' {
                Get-GzhrbWritingStateStatusSummaryJson -Limit $Limit | ConvertTo-Json -Depth 8
                exit 0
            }
            'auto-sync' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
                    throw 'ArticlePath is required for auto-sync action.'
                }
                Invoke-GzhrbWritingStateAutoSync -ArticlePath $ArticlePath -UpdatedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'approve-topic' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
                    throw 'ArticlePath is required for approve-topic action.'
                }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'topic_selected' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'approve-wechat-draft' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) { throw 'ArticlePath is required for approve-wechat-draft action.' }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'wechat_draft_approved' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'approve-writing' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) { throw 'ArticlePath is required for approve-writing action.' }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'writing_approved' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'mark-wechat-draft' { Set-GzhrbModernWritingComplete -ArticlePath $ArticlePath -Stage 'wechat_draft' -UpdatedBy $UpdatedBy | ConvertTo-Json -Depth 8; exit 0 }
            'mark-wechat-refine' { Set-GzhrbModernWritingComplete -ArticlePath $ArticlePath -Stage 'wechat_refine' -UpdatedBy $UpdatedBy | ConvertTo-Json -Depth 8; exit 0 }
            'mark-humanizer' { Set-GzhrbModernWritingComplete -ArticlePath $ArticlePath -Stage 'humanizer' -UpdatedBy $UpdatedBy | ConvertTo-Json -Depth 8; exit 0 }
            'approve-khazix' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
                    throw 'ArticlePath is required for approve-khazix action.'
                }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'khazix_approved' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'approve-wechat' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
                    throw 'ArticlePath is required for approve-wechat action.'
                }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'wechat_approved' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            'approve-illustrations' {
                if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
                    throw 'ArticlePath is required for approve-illustrations action.'
                }
                Invoke-GzhrbStageApproval -ArticlePath $ArticlePath -Stage 'illustrations_approved' -ApprovedBy $UpdatedBy | ConvertTo-Json -Depth 8
                exit 0
            }
            default {
                throw "Unknown action for gzhrb-writing-state.ps1: $Action"
            }
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($ArticlePath)) {
        Invoke-GzhrbWritingStateAutoSync -ArticlePath $ArticlePath -UpdatedBy $UpdatedBy | ConvertTo-Json -Depth 8
    } else {
        Get-GzhrbWritingStateStatusSummary -Limit $Limit
    }
}
