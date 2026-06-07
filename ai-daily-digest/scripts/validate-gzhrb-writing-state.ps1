param(
    [string]$ArticlePath,
    [string]$WorkitemPath
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Get-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Read-Utf8TextFile {
    param([Parameter(Mandatory)][string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8TextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Get-ArticleIdFromPath {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
    if ($fileName -eq 'article') {
        $parentDir = Split-Path -Parent $ArticlePath
        return Split-Path -Leaf $parentDir
    }

    return $fileName
}

function Get-DefaultWorkitemPath {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$ProjectDir
    )

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    return Join-Path $ProjectDir "reports\gzhrb\workitems\$articleId.json"
}

function New-ValidationResult {
    param(
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)][bool]$IsReadyForPostwriting,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$NextStep,
        [string]$DeclaredStage,
        [string]$EvidenceStage,
        [bool]$StateMatchesEvidence = $false,
        $WritingState,
        $ApprovalState,
        $ProvenanceState,
        $MissingEvidence,
        [object[]]$ExecutionLogTail = @(),
        [string]$WorkitemPath,
        [string]$KhazixDraftPath,
        [string]$OptimizedArticlePath,
        [string]$ApprovalDir,
        [string]$ProvenanceDir,
        [string]$IllustrationDir,
        [string]$PublishUnitDir
    )

    return [pscustomobject]@{
        stage = $Stage
        declared_stage = $DeclaredStage
        evidence_stage = $EvidenceStage
        state_matches_evidence = $StateMatchesEvidence
        is_ready_for_postwriting = $IsReadyForPostwriting
        reason = $Reason
        next_step = $NextStep
        writing_state = $WritingState
        approval_state = $ApprovalState
        provenance_state = $ProvenanceState
        missing_evidence = $MissingEvidence
        execution_log_tail = @($ExecutionLogTail)
        workitem_path = $WorkitemPath
        khazix_draft_path = $KhazixDraftPath
        optimized_article_path = $OptimizedArticlePath
        approval_dir = $ApprovalDir
        provenance_dir = $ProvenanceDir
        illustration_dir = $IllustrationDir
        publish_unit_dir = $PublishUnitDir
    }
}

function New-PendingWritingState {
    return [ordered]@{
        status = 'pending'
        completed_at = $null
        updated_at = $null
        updated_by = $null
        source_path = $null
    }
}

function Get-DefaultWritingState {
    return [ordered]@{
        khazix = New-PendingWritingState
        wechat = New-PendingWritingState
    }
}

function Get-ExecutionLogTail {
    param(
        [AllowNull()]$ExecutionLog,
        [int]$Count = 5
    )

    $entries = @($ExecutionLog)
    if ($entries.Count -le $Count) {
        return $entries
    }

    return $entries[($entries.Count - $Count)..($entries.Count - 1)]
}

function Read-GzhrbWorkitem {
    param([Parameter(Mandatory)][string]$WorkitemPath)

    $workitem = Read-Utf8TextFile -Path $WorkitemPath | ConvertFrom-Json

    if ($null -eq $workitem.writing_state) {
        $workitem | Add-Member -NotePropertyName writing_state -NotePropertyValue (Get-DefaultWritingState)
    }

    foreach ($name in @('khazix', 'wechat')) {
        if ($null -eq $workitem.writing_state.$name) {
            $workitem.writing_state | Add-Member -NotePropertyName $name -NotePropertyValue (New-PendingWritingState)
            continue
        }

        foreach ($field in @('status', 'completed_at', 'updated_at', 'updated_by', 'source_path')) {
            if ($null -eq $workitem.writing_state.$name.PSObject.Properties[$field]) {
                $workitem.writing_state.$name | Add-Member -NotePropertyName $field -NotePropertyValue $null
            }
        }

        if ([string]::IsNullOrWhiteSpace([string]$workitem.writing_state.$name.status)) {
            $workitem.writing_state.$name.status = 'pending'
        }
    }

    if ($null -eq $workitem.execution_log) {
        $workitem | Add-Member -NotePropertyName execution_log -NotePropertyValue @()
    }

    return $workitem
}

function Save-GzhrbWorkitem {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$WorkitemPath
    )

    $json = $Workitem | ConvertTo-Json -Depth 8
    Write-Utf8TextFile -Path $WorkitemPath -Content $json
}

function Test-IsPlaceholderKhazixDraft {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $content = Read-Utf8TextFile -Path $Path
    return $content.Contains('khazix-writer 初稿占位文件')
}

function Test-IsMeaningfulTextFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $content = Read-Utf8TextFile -Path $Path
    return -not [string]::IsNullOrWhiteSpace($content)
}

function New-DefaultApprovalState {
    return [ordered]@{
        topic_selected = $false
        khazix_approved = $false
        wechat_approved = $false
        illustrations_approved = $false
    }
}

function New-DefaultProvenanceCheck {
    return [ordered]@{
        exists = $false
        valid = $false
        file = $null
        skill_name_match = $false
        status_match = $false
        output_path_match = $false
    }
}

function New-DefaultProvenanceState {
    return [ordered]@{
        khazix_execution = New-DefaultProvenanceCheck
        wechat_execution = New-DefaultProvenanceCheck
        illustration_execution = New-DefaultProvenanceCheck
    }
}

function New-MissingEvidence {
    return [ordered]@{
        files = @()
        provenance = @()
        approvals = @()
    }
}

function Resolve-WorkitemPathField {
    param(
        [Parameter(Mandatory)]$Workitem,
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$Fallback
    )

    if ($null -ne $Workitem.paths -and $null -ne $Workitem.paths.$FieldName -and -not [string]::IsNullOrWhiteSpace([string]$Workitem.paths.$FieldName)) {
        return [string]$Workitem.paths.$FieldName
    }

    return $Fallback
}

function Test-PathEquals {
    param(
        [string]$Left,
        [string]$Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }

    try {
        $leftResolved = [System.IO.Path]::GetFullPath($Left)
        $rightResolved = [System.IO.Path]::GetFullPath($Right)
        return [string]::Equals($leftResolved, $rightResolved, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return [string]::Equals($Left, $Right, [System.StringComparison]::OrdinalIgnoreCase)
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        return Read-Utf8TextFile -Path $Path | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Test-ApprovalFile {
    param([Parameter(Mandatory)][string]$Path)

    $approval = Read-JsonFile -Path $Path
    if ($null -eq $approval) {
        return $false
    }

    if ($null -eq $approval.approved) {
        return $true
    }

    if ($approval.approved -is [bool]) {
        return [bool]$approval.approved
    }

    return [string]::Equals([string]$approval.approved, 'true', [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ProvenanceValidation {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedSkillName,
        [string]$ExpectedOutputPath,
        [bool]$RequireOutputPathMatch = $true
    )

    $state = [ordered]@{
        exists = $false
        valid = $false
        file = $Path
        skill_name_match = $false
        status_match = $false
        output_path_match = $false
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]$state
    }

    $state.exists = $true
    $content = Read-JsonFile -Path $Path
    if ($null -eq $content) {
        return [pscustomobject]$state
    }

    $state.skill_name_match = [string]::Equals([string]$content.skill_name, $ExpectedSkillName, [System.StringComparison]::OrdinalIgnoreCase)
    $state.status_match = [string]::Equals([string]$content.status, 'completed', [System.StringComparison]::OrdinalIgnoreCase)

    if (-not $RequireOutputPathMatch) {
        $state.output_path_match = $true
    } else {
        $state.output_path_match = Test-PathEquals -Left ([string]$content.output_path) -Right $ExpectedOutputPath
    }

    $state.valid = $state.skill_name_match -and $state.status_match -and $state.output_path_match
    return [pscustomobject]$state
}

function Test-IllustrationAssets {
    param([Parameter(Mandatory)][string]$IllustrationDir)

    $placementPath = Join-Path $IllustrationDir 'placement.json'
    $batchPath = Join-Path $IllustrationDir 'batch.json'
    $outlinePath = Join-Path $IllustrationDir 'outline.md'
    $promptsDir = Join-Path $IllustrationDir 'prompts'

    $imagePatterns = @('*.png', '*.jpg', '*.jpeg', '*.webp', '*.gif')
    $images = @()
    if (Test-Path -LiteralPath $IllustrationDir) {
        foreach ($pattern in $imagePatterns) {
            $images += Get-ChildItem -LiteralPath $IllustrationDir -File -Filter $pattern -ErrorAction SilentlyContinue
        }
    }

    return [ordered]@{
        placement = Test-Path -LiteralPath $placementPath
        batch = Test-Path -LiteralPath $batchPath
        outline = Test-IsMeaningfulTextFile -Path $outlinePath
        prompts = Test-Path -LiteralPath $promptsDir
        images = ($images.Count -gt 0)
    }
}

function Test-PublishUnitCompleted {
    param([Parameter(Mandatory)][string]$PublishUnitDir)

    $result = [ordered]@{
        publish_unit_article = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'article.md')
        publish_unit_titles = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'titles.txt')
        publish_unit_intro_lines = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'intro-lines.txt')
        publish_unit_topic_tags = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'topic-tags.txt')
        publish_unit_package = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'package.json')
        publish_unit_review_checklist = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'review-checklist.md')
        publish_unit_illustrations_dir = Test-Path -LiteralPath (Join-Path $PublishUnitDir 'illustrations')
    }

    $allPresent = $true
    foreach ($key in $result.Keys) {
        if (-not $result[$key]) {
            $allPresent = $false
            break
        }
    }

    return [ordered]@{
        completed = $allPresent
        details = $result
    }
}

function Add-MissingEvidenceItem {
    param(
        [Parameter(Mandatory)]$MissingEvidence,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Key
    )

    $items = @($MissingEvidence.$Category)
    if ($items -contains $Key) {
        return
    }

    $MissingEvidence.$Category = @($items + $Key)
}

function Get-ReasonAndNextStep {
    param([Parameter(Mandatory)][string]$Stage)

    switch ($Stage) {
        'missing_workitem' {
            return [ordered]@{
                reason = 'Formal writing workitem is missing.'
                next_step = 'Create or restore the writing workitem before running validation.'
            }
        }
        'awaiting_topic_approval' {
            return [ordered]@{
                reason = 'Topic approval evidence is missing.'
                next_step = 'Add topic-selected approval before entering khazix execution.'
            }
        }
        'awaiting_khazix_execution' {
            return [ordered]@{
                reason = 'Khazix execution evidence is incomplete (file and/or provenance missing).'
                next_step = 'Complete khazix draft and khazix provenance evidence.'
            }
        }
        'awaiting_khazix_approval' {
            return [ordered]@{
                reason = 'Khazix execution evidence exists, but khazix approval is missing.'
                next_step = 'Approve khazix output before entering wechat execution.'
            }
        }
        'awaiting_wechat_execution' {
            return [ordered]@{
                reason = 'Wechat execution evidence is incomplete (file and/or provenance missing).'
                next_step = 'Complete optimized article and wechat provenance evidence.'
            }
        }
        'awaiting_wechat_approval' {
            return [ordered]@{
                reason = 'Wechat execution evidence exists, but wechat approval is missing.'
                next_step = 'Approve wechat output before entering illustration execution.'
            }
        }
        'awaiting_illustration_execution' {
            return [ordered]@{
                reason = 'Illustration execution evidence is incomplete (assets and/or provenance missing).'
                next_step = 'Complete illustration assets and illustration provenance evidence.'
            }
        }
        'ready_for_publish_unit' {
            return [ordered]@{
                reason = 'Writing and illustration execution are complete. Publish-unit files are still incomplete.'
                next_step = 'Generate publish-unit files and assets to reach completed stage.'
            }
        }
        'completed' {
            return [ordered]@{
                reason = 'Publish-unit output is complete.'
                next_step = 'Proceed to manual final review and publication.'
            }
        }
        default {
            return [ordered]@{
                reason = 'Unknown stage.'
                next_step = 'Inspect workitem and evidence files manually.'
            }
        }
    }
}

function Get-GzhrbWritingStateValidation {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$WorkitemPath
    )

    $projectDir = Get-ProjectDir

    if (-not (Test-Path -LiteralPath $ArticlePath)) {
        throw "Article not found: $ArticlePath"
    }

    if ([string]::IsNullOrWhiteSpace($WorkitemPath)) {
        $WorkitemPath = Get-DefaultWorkitemPath -ArticlePath $ArticlePath -ProjectDir $projectDir
    }

    if (-not (Test-Path -LiteralPath $WorkitemPath)) {
        $missingEvidence = New-MissingEvidence
        Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'workitem'
        $reasonNext = Get-ReasonAndNextStep -Stage 'missing_workitem'
        return New-ValidationResult `
            -Stage 'missing_workitem' `
            -IsReadyForPostwriting:$false `
            -Reason "$($reasonNext.reason) Path: $WorkitemPath" `
            -NextStep $reasonNext.next_step `
            -DeclaredStage 'missing_workitem' `
            -EvidenceStage 'missing_workitem' `
            -StateMatchesEvidence:$true `
            -WritingState (Get-DefaultWritingState) `
            -ApprovalState (New-DefaultApprovalState) `
            -ProvenanceState (New-DefaultProvenanceState) `
            -MissingEvidence $missingEvidence `
            -ExecutionLogTail @() `
            -WorkitemPath $WorkitemPath
    }

    $workitem = Read-GzhrbWorkitem -WorkitemPath $WorkitemPath
    $articleId = if (-not [string]::IsNullOrWhiteSpace([string]$workitem.article_id)) { [string]$workitem.article_id } else { Get-ArticleIdFromPath -ArticlePath $ArticlePath }
    $gzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    $declaredStage = [string]$workitem.stage
    $khazixDraftPath = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'khazix_draft' -Fallback (Join-Path $gzhrbDir "drafts\$articleId-khazix.md")
    $optimizedArticlePath = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'optimized_article' -Fallback (Join-Path $gzhrbDir "articles\$articleId\article.md")
    $approvalDir = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'approval_dir' -Fallback (Join-Path $gzhrbDir "approvals\$articleId")
    $provenanceDir = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'provenance_dir' -Fallback (Join-Path $gzhrbDir "provenance\$articleId")
    $illustrationDir = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'illustration_dir' -Fallback (Join-Path $gzhrbDir "illustrations\$articleId")
    $publishUnitDir = Resolve-WorkitemPathField -Workitem $workitem -FieldName 'publish_unit_dir' -Fallback (Join-Path $gzhrbDir "publish-units\$articleId")

    $executionLogTail = Get-ExecutionLogTail -ExecutionLog $workitem.execution_log

    $approvalState = New-DefaultApprovalState
    $approvalState.topic_selected = Test-ApprovalFile -Path (Join-Path $approvalDir 'topic-selected.json')
    $approvalState.khazix_approved = Test-ApprovalFile -Path (Join-Path $approvalDir 'khazix-approved.json')
    $approvalState.wechat_approved = Test-ApprovalFile -Path (Join-Path $approvalDir 'wechat-approved.json')
    $approvalState.illustrations_approved = Test-ApprovalFile -Path (Join-Path $approvalDir 'illustrations-approved.json')

    $provenanceState = New-DefaultProvenanceState
    $provenanceState.khazix_execution = Get-ProvenanceValidation `
        -Path (Join-Path $provenanceDir 'khazix-execution.json') `
        -ExpectedSkillName 'khazix-writer' `
        -ExpectedOutputPath $khazixDraftPath `
        -RequireOutputPathMatch:$true
    $provenanceState.wechat_execution = Get-ProvenanceValidation `
        -Path (Join-Path $provenanceDir 'wechat-execution.json') `
        -ExpectedSkillName 'wechat-article-writer' `
        -ExpectedOutputPath $optimizedArticlePath `
        -RequireOutputPathMatch:$true
    $provenanceState.illustration_execution = Get-ProvenanceValidation `
        -Path (Join-Path $provenanceDir 'illustration-execution.json') `
        -ExpectedSkillName 'baoyu-article-illustrator' `
        -ExpectedOutputPath $illustrationDir `
        -RequireOutputPathMatch:$false

    $missingEvidence = New-MissingEvidence
    $hasKhazixDraft = Test-IsMeaningfulTextFile -Path $khazixDraftPath
    $isPlaceholderKhazixDraft = if ($hasKhazixDraft) { Test-IsPlaceholderKhazixDraft -Path $khazixDraftPath } else { $false }
    $khazixDraftReady = $hasKhazixDraft -and -not $isPlaceholderKhazixDraft

    $wechatArticleReady = Test-IsMeaningfulTextFile -Path $optimizedArticlePath
    $illustrationAssets = Test-IllustrationAssets -IllustrationDir $illustrationDir
    $publishUnitState = Test-PublishUnitCompleted -PublishUnitDir $publishUnitDir

    $evidenceStage = 'completed'

    if (-not $approvalState.topic_selected) {
        Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'approvals' -Key 'topic_selected'
        $evidenceStage = 'awaiting_topic_approval'
    } else {
        if (-not $khazixDraftReady) {
            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'khazix_draft'
        }
        if (-not $provenanceState.khazix_execution.valid) {
            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'provenance' -Key 'khazix_execution'
        }

        if ($missingEvidence.files -contains 'khazix_draft' -or $missingEvidence.provenance -contains 'khazix_execution') {
            $evidenceStage = 'awaiting_khazix_execution'
        } else {
            if (-not $approvalState.khazix_approved) {
                Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'approvals' -Key 'khazix_approved'
                $evidenceStage = 'awaiting_khazix_approval'
            } else {
                if (-not $wechatArticleReady) {
                    Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'wechat_article'
                }
                if (-not $provenanceState.wechat_execution.valid) {
                    Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'provenance' -Key 'wechat_execution'
                }

                if ($missingEvidence.files -contains 'wechat_article' -or $missingEvidence.provenance -contains 'wechat_execution') {
                    $evidenceStage = 'awaiting_wechat_execution'
                } else {
                    if (-not $approvalState.wechat_approved) {
                        Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'approvals' -Key 'wechat_approved'
                        $evidenceStage = 'awaiting_wechat_approval'
                    } else {
                        if (-not $illustrationAssets.placement) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'illustration_placement'
                        }
                        if (-not $illustrationAssets.batch) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'illustration_batch'
                        }
                        if (-not $illustrationAssets.outline) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'illustration_outline'
                        }
                        if (-not $illustrationAssets.prompts) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'illustration_prompts'
                        }
                        if (-not $illustrationAssets.images) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key 'illustration_images'
                        }
                        if (-not $provenanceState.illustration_execution.valid) {
                            Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'provenance' -Key 'illustration_execution'
                        }

                        $hasIllustrationExecutionMissing = ($missingEvidence.files | Where-Object { $_ -like 'illustration_*' }).Count -gt 0 -or ($missingEvidence.provenance -contains 'illustration_execution')
                        if ($hasIllustrationExecutionMissing) {
                            $evidenceStage = 'awaiting_illustration_execution'
                        } else {
                            foreach ($entry in $publishUnitState.details.GetEnumerator()) {
                                if (-not $entry.Value) {
                                    Add-MissingEvidenceItem -MissingEvidence $missingEvidence -Category 'files' -Key $entry.Key
                                }
                            }

                            if (-not $publishUnitState.completed) {
                                $evidenceStage = 'ready_for_publish_unit'
                            } else {
                                $evidenceStage = 'completed'
                            }
                        }
                    }
                }
            }
        }
    }

    $stateMatchesEvidence = ($declaredStage -eq $evidenceStage)
    $reasonNext = Get-ReasonAndNextStep -Stage $evidenceStage
    $isReadyForPostwriting = $evidenceStage -in @(
        'awaiting_illustration_execution',
        'ready_for_publish_unit',
        'completed'
    )

    return New-ValidationResult `
        -Stage $evidenceStage `
        -IsReadyForPostwriting:$isReadyForPostwriting `
        -Reason $reasonNext.reason `
        -NextStep $reasonNext.next_step `
        -DeclaredStage $declaredStage `
        -EvidenceStage $evidenceStage `
        -StateMatchesEvidence:$stateMatchesEvidence `
        -WritingState $workitem.writing_state `
        -ApprovalState $approvalState `
        -ProvenanceState $provenanceState `
        -MissingEvidence $missingEvidence `
        -ExecutionLogTail $executionLogTail `
        -WorkitemPath $WorkitemPath `
        -KhazixDraftPath $khazixDraftPath `
        -OptimizedArticlePath $optimizedArticlePath `
        -ApprovalDir $approvalDir `
        -ProvenanceDir $provenanceDir `
        -IllustrationDir $illustrationDir `
        -PublishUnitDir $publishUnitDir
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    $result | ConvertTo-Json -Depth 5
    if ($result.is_ready_for_postwriting) {
        exit 0
    }

    exit 2
}
