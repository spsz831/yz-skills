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

    if ($validation.evidence_stage -eq 'awaiting_topic_approval' -or $validation.evidence_stage -eq 'awaiting_khazix_execution') {
        return [pscustomobject]@{
            article_path = $ArticlePath
            actions = @()
            final_declared_stage = $validation.declared_stage
            final_evidence_stage = $validation.evidence_stage
            state_matches_evidence = $validation.state_matches_evidence
            reason = 'No sync was applied because khazix evidence is not ready yet.'
        }
    }

    if ($validation.writing_state.khazix.status -ne 'completed') {
        [void]$actions.Add('mark-khazix')
        Set-GzhrbKhazixComplete -ArticlePath $ArticlePath -UpdatedBy $UpdatedBy | Out-Null
        $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath
    }

    if (
        ($validation.evidence_stage -in @(
            'awaiting_wechat_approval',
            'awaiting_illustration_execution',
            'awaiting_illustration_approval',
            'ready_for_publish_unit',
            'completed'
        )) -and
        ($validation.writing_state.wechat.status -ne 'completed')
    ) {
        [void]$actions.Add('mark-wechat')
        Set-GzhrbWechatComplete -ArticlePath $ArticlePath -UpdatedBy $UpdatedBy | Out-Null
        $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath
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
        $lines += "- $articleId | declared=$($validation.declared_stage) | evidence=$($validation.evidence_stage) | khazix=$($validation.writing_state.khazix.status) | wechat=$($validation.writing_state.wechat.status) | ready=$($validation.is_ready_for_postwriting)"
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
            khazix_status = $validation.writing_state.khazix.status
            wechat_status = $validation.writing_state.wechat.status
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
