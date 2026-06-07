param(
    [string]$ArticlePath,
    [string]$WorkitemPath,
    [string]$Stage,
    [string]$ApprovedBy = 'manual-approval',
    [string]$Note
)

$ErrorActionPreference = 'Stop'

$boundArticlePath = $ArticlePath
$boundWorkitemPath = $WorkitemPath
$boundStage = $Stage
$boundApprovedBy = $ApprovedBy
$boundNote = $Note

. (Join-Path $PSScriptRoot 'validate-gzhrb-writing-state.ps1')

function Get-IsoTimestamp {
    return (Get-Date).ToString('o')
}

function Get-GzhrbApprovalArticleId {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
    if ($fileName -eq 'article') {
        $parentDir = Split-Path -Parent $ArticlePath
        return Split-Path -Leaf $parentDir
    }

    return $fileName
}

function Get-GzhrbApprovalWorkitemPath {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath
    )

    if (-not [string]::IsNullOrWhiteSpace($WorkitemPath)) {
        return $WorkitemPath
    }

    $projectDir = Get-ProjectDir
    $articleId = Get-GzhrbApprovalArticleId -ArticlePath $ArticlePath
    return Join-Path $projectDir "reports\gzhrb\workitems\$articleId.json"
}

function Resolve-GzhrbNormalizedPath {
    param(
        [string]$Path,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectDir $Path))
}

function Assert-GzhrbCurrentStage {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$ExpectedStage,
        [Parameter(Mandatory)][string]$Stage
    )

    $currentStage = [string]$Workitem.stage
    if ($currentStage -ne $ExpectedStage) {
        throw "Current stage does not allow approval '$Stage'. Expected '$ExpectedStage' but got '$currentStage'."
    }
}

function Get-GzhrbStageConfig {
    param([Parameter(Mandatory)][string]$Stage)

    $normalized = $Stage.Trim().ToLowerInvariant()
    switch ($normalized) {
        'topic_selected' {
            return [pscustomobject]@{
                stage = 'topic_selected'
                approval_file = 'topic-selected.json'
                expected_stage = 'awaiting_topic_approval'
                next_stage = 'awaiting_khazix_execution'
                action = 'approve_topic_selected'
                evidence = 'none'
            }
        }
        'khazix_approved' {
            return [pscustomobject]@{
                stage = 'khazix_approved'
                approval_file = 'khazix-approved.json'
                expected_stage = 'awaiting_khazix_approval'
                next_stage = 'awaiting_wechat_execution'
                action = 'approve_khazix_approved'
                evidence = 'khazix'
            }
        }
        'wechat_approved' {
            return [pscustomobject]@{
                stage = 'wechat_approved'
                approval_file = 'wechat-approved.json'
                expected_stage = 'awaiting_wechat_approval'
                next_stage = 'awaiting_illustration_execution'
                action = 'approve_wechat_approved'
                evidence = 'wechat'
            }
        }
        'illustrations_approved' {
            return [pscustomobject]@{
                stage = 'illustrations_approved'
                approval_file = 'illustrations-approved.json'
                expected_stage = 'awaiting_illustration_approval'
                next_stage = 'ready_for_publish_unit'
                action = 'approve_illustrations_approved'
                evidence = 'illustrations'
            }
        }
        default {
            throw "Unsupported approval stage: $Stage"
        }
    }
}

function Assert-GzhrbExecutionProvenance {
    param(
        [Parameter(Mandatory)][string]$ProvenancePath,
        [Parameter(Mandatory)][string]$RequiredSkillName,
        [Parameter(Mandatory)][string]$EvidenceLabel,
        [string]$RequiredOutputPath,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    if (-not (Test-Path -LiteralPath $ProvenancePath)) {
        throw "Missing required execution evidence for stage '$EvidenceLabel': $ProvenancePath"
    }

    $payload = Read-Utf8TextFile -Path $ProvenancePath | ConvertFrom-Json
    if ([string]$payload.skill_name -ne $RequiredSkillName) {
        throw "Missing required execution evidence for stage '$EvidenceLabel': skill_name must be '$RequiredSkillName' in $ProvenancePath"
    }

    if ([string]$payload.status -ne 'completed') {
        throw "Missing required execution evidence for stage '$EvidenceLabel': status must be 'completed' in $ProvenancePath"
    }

    if (-not [string]::IsNullOrWhiteSpace($RequiredOutputPath)) {
        $expectedOutput = Resolve-GzhrbNormalizedPath -Path $RequiredOutputPath -ProjectDir $ProjectDir
        $actualOutput = Resolve-GzhrbNormalizedPath -Path ([string]$payload.output_path) -ProjectDir $ProjectDir
        if ($expectedOutput -ne $actualOutput) {
            throw "Missing required execution evidence for stage '$EvidenceLabel': output_path mismatch in $ProvenancePath"
        }
    }
}

function Assert-GzhrbKhazixEvidence {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$ProvenanceDir,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    $draftPath = [string]$Workitem.paths.khazix_draft
    if (-not (Test-IsMeaningfulTextFile -Path $draftPath)) {
        throw "Missing required execution evidence for stage 'khazix_approved': khazix draft is missing or empty: $draftPath"
    }

    if (Test-IsPlaceholderKhazixDraft -Path $draftPath) {
        throw "Missing required execution evidence for stage 'khazix_approved': khazix draft is still a placeholder: $draftPath"
    }

    Assert-GzhrbExecutionProvenance `
        -ProvenancePath (Join-Path $ProvenanceDir 'khazix-execution.json') `
        -RequiredSkillName 'khazix-writer' `
        -EvidenceLabel 'khazix_approved' `
        -RequiredOutputPath $draftPath `
        -ProjectDir $ProjectDir
}

function Assert-GzhrbWechatEvidence {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$ProvenanceDir,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    $optimizedPath = [string]$Workitem.paths.optimized_article
    if (-not (Test-IsMeaningfulTextFile -Path $optimizedPath)) {
        throw "Missing required execution evidence for stage 'wechat_approved': optimized article is missing or empty: $optimizedPath"
    }

    Assert-GzhrbExecutionProvenance `
        -ProvenancePath (Join-Path $ProvenanceDir 'wechat-execution.json') `
        -RequiredSkillName 'wechat-article-writer' `
        -EvidenceLabel 'wechat_approved' `
        -RequiredOutputPath $optimizedPath `
        -ProjectDir $ProjectDir
}

function Assert-GzhrbIllustrationEvidence {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$ProvenanceDir,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    $illustrationDir = [string]$Workitem.paths.illustration_dir
    $requiredFiles = @('placement.json', 'batch.json', 'outline.md')
    foreach ($name in $requiredFiles) {
        $requiredPath = Join-Path $illustrationDir $name
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Missing required execution evidence for stage 'illustrations_approved': required illustration artifact not found: $requiredPath"
        }
    }

    $promptsDir = Join-Path $illustrationDir 'prompts'
    if (-not (Test-Path -LiteralPath $promptsDir -PathType Container)) {
        throw "Missing required execution evidence for stage 'illustrations_approved': prompts directory not found: $promptsDir"
    }

    $imageFiles = @(
        Get-ChildItem -LiteralPath $illustrationDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.png', '.jpg', '.jpeg', '.webp', '.gif') }
    )
    if ($imageFiles.Count -eq 0) {
        throw "Missing required execution evidence for stage 'illustrations_approved': no generated image files found in $illustrationDir"
    }

    Assert-GzhrbExecutionProvenance `
        -ProvenancePath (Join-Path $ProvenanceDir 'illustration-execution.json') `
        -RequiredSkillName 'baoyu-article-illustrator' `
        -EvidenceLabel 'illustrations_approved' `
        -ProjectDir $ProjectDir
}

function Assert-GzhrbStageEvidence {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)]$StageConfig,
        [Parameter(Mandatory)][string]$ProvenanceDir,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    switch ($StageConfig.evidence) {
        'none' { return }
        'khazix' {
            Assert-GzhrbKhazixEvidence -Workitem $Workitem -ProvenanceDir $ProvenanceDir -ProjectDir $ProjectDir
            return
        }
        'wechat' {
            Assert-GzhrbWechatEvidence -Workitem $Workitem -ProvenanceDir $ProvenanceDir -ProjectDir $ProjectDir
            return
        }
        'illustrations' {
            Assert-GzhrbIllustrationEvidence -Workitem $Workitem -ProvenanceDir $ProvenanceDir -ProjectDir $ProjectDir
            return
        }
        default {
            throw "Unsupported evidence config for stage: $($StageConfig.stage)"
        }
    }
}

function Set-GzhrbStageApproval {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath,
        [Parameter(Mandatory)][string]$Stage,
        [string]$ApprovedBy = 'manual-approval',
        [string]$Note
    )

    if (-not (Test-Path -LiteralPath $ArticlePath)) {
        throw "Article not found: $ArticlePath"
    }

    $projectDir = Get-ProjectDir
    $workitemPathToUse = Get-GzhrbApprovalWorkitemPath -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    if (-not (Test-Path -LiteralPath $workitemPathToUse)) {
        throw "Workitem not found: $workitemPathToUse"
    }

    $workitem = Read-GzhrbWorkitem -WorkitemPath $workitemPathToUse
    $articleId = if (-not [string]::IsNullOrWhiteSpace([string]$workitem.article_id)) {
        [string]$workitem.article_id
    } else {
        Get-GzhrbApprovalArticleId -ArticlePath $ArticlePath
    }

    $approvalDir = [string]$workitem.paths.approval_dir
    if ([string]::IsNullOrWhiteSpace($approvalDir)) {
        $approvalDir = Join-Path $projectDir "reports\gzhrb\approvals\$articleId"
    }

    $provenanceDir = [string]$workitem.paths.provenance_dir
    if ([string]::IsNullOrWhiteSpace($provenanceDir)) {
        $provenanceDir = Join-Path $projectDir "reports\gzhrb\provenance\$articleId"
    }

    $stageConfig = Get-GzhrbStageConfig -Stage $Stage
    Assert-GzhrbCurrentStage -Workitem $workitem -ExpectedStage $stageConfig.expected_stage -Stage $stageConfig.stage
    Assert-GzhrbStageEvidence -Workitem $workitem -StageConfig $stageConfig -ProvenanceDir $provenanceDir -ProjectDir $projectDir

    New-Item -ItemType Directory -Force -Path $approvalDir | Out-Null
    $approvalPath = Join-Path $approvalDir $stageConfig.approval_file
    $timestamp = Get-IsoTimestamp

    $approvalPayload = [ordered]@{
        article_id = $articleId
        stage = $stageConfig.stage
        approved = $true
        approved_by = $ApprovedBy
        approved_at = $timestamp
        note = $Note
    }
    Write-Utf8TextFile -Path $approvalPath -Content ($approvalPayload | ConvertTo-Json -Depth 6)

    $previousStage = [string]$workitem.stage
    $workitem.stage = $stageConfig.next_stage
    $workitem.execution_log = @($workitem.execution_log) + [pscustomobject]@{
        timestamp = $timestamp
        action = $stageConfig.action
        stage_before = $previousStage
        stage_after = $stageConfig.next_stage
        updated_by = $ApprovedBy
        approval_path = $approvalPath
        note = $Note
    }

    Save-GzhrbWorkitem -Workitem $workitem -WorkitemPath $workitemPathToUse

    return [pscustomobject]@{
        article_id = $articleId
        stage = $workitem.stage
        approved_stage = $stageConfig.stage
        approval_path = $approvalPath
        workitem_path = $workitemPathToUse
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Set-GzhrbStageApproval `
        -ArticlePath $boundArticlePath `
        -WorkitemPath $boundWorkitemPath `
        -Stage $boundStage `
        -ApprovedBy $boundApprovedBy `
        -Note $boundNote | ConvertTo-Json -Depth 6
}
