param(
    [string]$ArticlePath,
    [string]$WorkitemPath
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir { Split-Path -Parent $PSScriptRoot }
function Get-Utf8NoBomEncoding { New-Object System.Text.UTF8Encoding($false) }
function Read-Utf8TextFile([string]$Path) { [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) }
function Write-Utf8TextFile([string]$Path, [string]$Content) { [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding)) }

function Get-ArticleIdFromPath([string]$Path) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($name -eq 'article') { return Split-Path -Leaf (Split-Path -Parent $Path) }
    return $name
}

function Get-DefaultWorkitemPath([string]$Path, [string]$ProjectDir) {
    Join-Path $ProjectDir "reports\gzhrb\workitems\$(Get-ArticleIdFromPath $Path).json"
}

function New-PendingWritingState {
    [ordered]@{ status = 'pending'; completed_at = $null; updated_at = $null; updated_by = $null; source_path = $null }
}

function Get-DefaultWritingState {
    [ordered]@{
        wechat_draft = New-PendingWritingState
        wechat_refine = New-PendingWritingState
        humanizer = New-PendingWritingState
    }
}

function Read-GzhrbWorkitem([string]$WorkitemPath) {
    $workitem = Read-Utf8TextFile $WorkitemPath | ConvertFrom-Json
    if ($null -eq $workitem.writing_state) { $workitem | Add-Member writing_state (Get-DefaultWritingState) }
    foreach ($name in @('wechat_draft', 'wechat_refine', 'humanizer')) {
        if ($null -eq $workitem.writing_state.$name) { $workitem.writing_state | Add-Member $name (New-PendingWritingState); continue }
        foreach ($field in @('status', 'completed_at', 'updated_at', 'updated_by', 'source_path')) {
            if ($null -eq $workitem.writing_state.$name.PSObject.Properties[$field]) { $workitem.writing_state.$name | Add-Member $field $null }
        }
        if ([string]::IsNullOrWhiteSpace([string]$workitem.writing_state.$name.status)) { $workitem.writing_state.$name.status = 'pending' }
    }
    if ($null -eq $workitem.execution_log) { $workitem | Add-Member execution_log @() }
    return $workitem
}

function Save-GzhrbWorkitem($Workitem, [string]$WorkitemPath) { Write-Utf8TextFile $WorkitemPath ($Workitem | ConvertTo-Json -Depth 10) }
function Test-IsMeaningfulTextFile([string]$Path) { (Test-Path -LiteralPath $Path -PathType Leaf) -and (-not [string]::IsNullOrWhiteSpace((Read-Utf8TextFile $Path))) }
function Test-IsPlaceholderWechatDraft([string]$Path) { (Test-Path -LiteralPath $Path) -and (Read-Utf8TextFile $Path).Contains('wechat-article-writer 初稿占位文件') }
function Test-IsPlaceholderKhazixDraft([string]$Path) { Test-IsPlaceholderWechatDraft $Path }
function Test-PathEquals([string]$Left, [string]$Right) {
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) { return $false }
    [string]::Equals([System.IO.Path]::GetFullPath($Left), [System.IO.Path]::GetFullPath($Right), [System.StringComparison]::OrdinalIgnoreCase)
}
function Read-JsonFile([string]$Path) { if (Test-Path -LiteralPath $Path) { try { return Read-Utf8TextFile $Path | ConvertFrom-Json } catch { } }; return $null }
function Test-ApprovalFile([string]$Path) { $x = Read-JsonFile $Path; if ($null -eq $x) { return $false }; if ($null -eq $x.approved) { return $true }; return ([string]$x.approved -eq 'True' -or [string]$x.approved -eq 'true') }

function Get-ProvenanceValidation([string]$Path, [string]$ExpectedSkillName, [string]$ExpectedOutputPath, [bool]$RequireOutputPathMatch = $true) {
    $state = [ordered]@{ exists = $false; valid = $false; file = $Path; skill_name_match = $false; status_match = $false; output_path_match = $false }
    $content = Read-JsonFile $Path
    if ($null -eq $content) { return [pscustomobject]$state }
    $state.exists = $true
    $state.skill_name_match = [string]$content.skill_name -eq $ExpectedSkillName
    $state.status_match = [string]$content.status -eq 'completed'
    $state.output_path_match = if (-not $RequireOutputPathMatch) { $true } else { Test-PathEquals ([string]$content.output_path) $ExpectedOutputPath }
    $state.valid = $state.skill_name_match -and $state.status_match -and $state.output_path_match
    return [pscustomobject]$state
}

function Test-IllustrationAssets([string]$Dir) {
    $images = if (Test-Path -LiteralPath $Dir) { @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.png','.jpg','.jpeg','.webp','.gif') }) } else { @() }
    [ordered]@{
        placement = Test-Path (Join-Path $Dir 'placement.json')
        batch = Test-Path (Join-Path $Dir 'batch.json')
        outline = Test-IsMeaningfulTextFile (Join-Path $Dir 'outline.md')
        prompts = Test-Path (Join-Path $Dir 'prompts')
        images = $images.Count -gt 0
    }
}

function Test-PublishUnitCompleted([string]$Dir) {
    $names = @('article.md','titles.txt','intro-lines.txt','topic-tags.txt','package.json','review-checklist.md')
    $details = [ordered]@{}
    foreach ($name in $names) { $details["publish_unit_$($name.Replace('.','_').Replace('-','_'))"] = Test-Path (Join-Path $Dir $name) }
    $details.publish_unit_illustrations_dir = Test-Path (Join-Path $Dir 'illustrations')
    [ordered]@{ completed = (@($details.Values | Where-Object { -not $_ }).Count -eq 0); details = $details }
}

function New-ValidationResult($Stage, [bool]$Ready, [string]$Reason, [string]$NextStep, $Workitem, $Missing, $Provenance, $Approval, [string]$WorkitemPath, [string]$DraftPath, [string]$ArticleOutputPath, [string]$ApprovalDir, [string]$ProvenanceDir, [string]$IllustrationDir, [string]$PublishUnitDir) {
    [pscustomobject]@{
        stage = $Stage; declared_stage = [string]$Workitem.stage; evidence_stage = $Stage; state_matches_evidence = ([string]$Workitem.stage -eq $Stage)
        is_ready_for_postwriting = $Ready; reason = $Reason; next_step = $NextStep; writing_state = $Workitem.writing_state
        approval_state = $Approval; provenance_state = $Provenance; missing_evidence = $Missing; execution_log_tail = @($Workitem.execution_log | Select-Object -Last 5)
        workitem_path = $WorkitemPath; wechat_draft_path = $DraftPath; khazix_draft_path = $DraftPath; optimized_article_path = $ArticleOutputPath
        approval_dir = $ApprovalDir; provenance_dir = $ProvenanceDir; illustration_dir = $IllustrationDir; publish_unit_dir = $PublishUnitDir
    }
}

function Get-GzhrbWritingStateValidation {
    param([Parameter(Mandatory)][string]$ArticlePath, [string]$WorkitemPath)
    $projectDir = Get-ProjectDir
    if (-not (Test-Path -LiteralPath $ArticlePath)) { throw "Article not found: $ArticlePath" }
    if ([string]::IsNullOrWhiteSpace($WorkitemPath)) { $WorkitemPath = Get-DefaultWorkitemPath $ArticlePath $projectDir }
    if (-not (Test-Path -LiteralPath $WorkitemPath)) {
        return [pscustomobject]@{ stage='missing_workitem'; evidence_stage='missing_workitem'; declared_stage='missing_workitem'; is_ready_for_postwriting=$false; reason='Formal writing workitem is missing.'; next_step='Create the writing workitem first.'; workitem_path=$WorkitemPath }
    }
    $w = Read-GzhrbWorkitem $WorkitemPath
    $isLiteWorkflow = [string]$w.workflow_version -eq '2-lite'
    $id = if ($w.article_id) { [string]$w.article_id } else { Get-ArticleIdFromPath $ArticlePath }
    $root = Join-Path $projectDir 'reports\gzhrb'
    $draft = if ($w.paths.wechat_draft) { [string]$w.paths.wechat_draft } elseif ($w.paths.khazix_draft) { [string]$w.paths.khazix_draft } else { Join-Path $root "drafts\$id-wechat-draft.md" }
    $article = if ($w.paths.optimized_article) { [string]$w.paths.optimized_article } else { Join-Path $root "articles\$id\article.md" }
    $approvalDir = if ($w.paths.approval_dir) { [string]$w.paths.approval_dir } else { Join-Path $root "approvals\$id" }
    $provenanceDir = if ($w.paths.provenance_dir) { [string]$w.paths.provenance_dir } else { Join-Path $root "provenance\$id" }
    $illustrationDir = if ($w.paths.illustration_dir) { [string]$w.paths.illustration_dir } else { Join-Path $root "illustrations\$id" }
    $publishDir = if ($w.paths.publish_unit_dir) { [string]$w.paths.publish_unit_dir } else { Join-Path $root "publish-units\$id" }

    # Read new evidence first; fall back to legacy evidence for historical workitems.
    $draftProvPath = Join-Path $provenanceDir 'wechat-draft-execution.json'
    $draftProv = Get-ProvenanceValidation $draftProvPath 'wechat-article-writer' $draft
    $refineProv = Get-ProvenanceValidation (Join-Path $provenanceDir 'wechat-refine-execution.json') 'wechat-article-writer' $article
    $humanizerProv = Get-ProvenanceValidation (Join-Path $provenanceDir 'humanizer-execution.json') 'humanizer-zh' $article
    $legacyDraftProv = Get-ProvenanceValidation (Join-Path $provenanceDir 'khazix-execution.json') 'khazix-writer' $draft
    $legacyWechatProv = Get-ProvenanceValidation (Join-Path $provenanceDir 'wechat-execution.json') 'wechat-article-writer' $article
    $useLegacy = (-not $draftProv.valid -and $legacyDraftProv.valid)
    if ($useLegacy) { $draftProv = $legacyDraftProv; $refineProv = $legacyWechatProv; $humanizerProv = [pscustomobject]@{ valid=$true; exists=$false; file=$null; skill_name_match=$false; status_match=$false; output_path_match=$true } }
    $topicApproved = Test-ApprovalFile (Join-Path $approvalDir 'topic-selected.json')
    $draftApproved = (Test-ApprovalFile (Join-Path $approvalDir 'wechat-draft-approved.json')) -or (Test-ApprovalFile (Join-Path $approvalDir 'khazix-approved.json'))
    $writingApproved = (Test-ApprovalFile (Join-Path $approvalDir 'writing-approved.json')) -or (Test-ApprovalFile (Join-Path $approvalDir 'wechat-approved.json'))
    $approval = [ordered]@{ topic_selected=$topicApproved; wechat_draft_approved=$draftApproved; writing_approved=$writingApproved; wechat_approved=$writingApproved; khazix_approved=(Test-ApprovalFile (Join-Path $approvalDir 'khazix-approved.json')); illustrations_approved=(Test-ApprovalFile (Join-Path $approvalDir 'illustrations-approved.json')) }
    $prov = [ordered]@{ wechat_draft_execution=$draftProv; wechat_refine_execution=$refineProv; humanizer_execution=$humanizerProv; wechat_execution=$legacyWechatProv; khazix_execution=$legacyDraftProv; illustration_execution=(Get-ProvenanceValidation (Join-Path $provenanceDir 'illustration-execution.json') 'baoyu-article-illustrator' $illustrationDir $false) }
    $missing = [ordered]@{ files=@(); provenance=@(); approvals=@() }

    $stage='completed'; $reason='Publish-unit output is complete.'; $next='Proceed to manual final review and publication.'; $ready=$true
    if (-not $topicApproved) { $stage='awaiting_topic_approval'; $reason='Topic approval evidence is missing.'; $next='Approve the selected topic before writing.'; $ready=$false; $missing.approvals += 'topic_selected' }
    elseif ($isLiteWorkflow -and -not (Test-IsMeaningfulTextFile $article)) { $stage='awaiting_writing_execution'; $reason='Final article is missing or empty.'; $next='Write or refine the article, verify its facts, and save it to article.md; use writing skills when useful.'; $ready=$false; $missing.files += 'optimized_article' }
    elseif ($isLiteWorkflow -and -not $writingApproved) { $stage='awaiting_writing_approval'; $reason='Final writing approval is missing.'; $next='Perform the single manual final review and create writing-approved.json.'; $ready=$false; $missing.approvals += 'writing_approved' }
    elseif ($isLiteWorkflow) {
        $assets = Test-IllustrationAssets $illustrationDir
        $illustrationProv = $prov.illustration_execution.valid
        if ((@($assets.Values | Where-Object { -not $_ }).Count -gt 0) -or -not $illustrationProv) { $stage='awaiting_illustration_execution'; $reason='Illustration assets or provenance are incomplete.'; $next='Plan, generate, archive and record illustration execution.'; $missing.files += @($assets.Keys | Where-Object { -not $assets[$_] }); if (-not $illustrationProv) { $missing.provenance += 'illustration_execution' } }
        else { $publish = Test-PublishUnitCompleted $publishDir; if (-not $publish.completed) { $stage='ready_for_publish_unit'; $reason='Writing and illustration evidence are complete; publish unit is incomplete.'; $next='Generate and review the final publish unit.'; foreach ($k in $publish.details.Keys) { if (-not $publish.details[$k]) { $missing.files += $k } } } }
    }
    elseif ((-not (Test-IsMeaningfulTextFile $draft)) -or (Test-IsPlaceholderWechatDraft $draft) -or (-not $draftProv.valid)) { $stage='awaiting_wechat_draft_execution'; $reason='Wechat first-draft file or provenance is incomplete.'; $next='Run wechat-article-writer and record wechat-draft-execution.json.'; $ready=$false; $missing.files += 'wechat_draft'; if (-not $draftProv.valid) { $missing.provenance += 'wechat_draft_execution' } }
    elseif (-not $draftApproved) { $stage='awaiting_wechat_draft_approval'; $reason='Wechat first draft is ready, but human inspection approval is missing.'; $next='Review the first draft and approve it before second refinement.'; $ready=$false; $missing.approvals += 'wechat_draft_approved' }
    elseif (-not (Test-IsMeaningfulTextFile $article) -or -not $refineProv.valid) { $stage='awaiting_wechat_refinement_execution'; $reason='Wechat refinement output or provenance is incomplete.'; $next='Run the second wechat-article-writer refinement into article.md.'; $ready=$false; $missing.files += 'optimized_article'; if (-not $refineProv.valid) { $missing.provenance += 'wechat_refine_execution' } }
    elseif (-not $humanizerProv.valid) { $stage='awaiting_humanizer_execution'; $reason='Humanizer execution evidence is missing.'; $next='Run humanizer-zh on article.md and record humanizer-execution.json.'; $ready=$false; $missing.provenance += 'humanizer_execution' }
    elseif (-not $writingApproved) { $stage='awaiting_writing_approval'; $reason='Final writing approval is missing.'; $next='Perform manual final review and create writing-approved.json.'; $ready=$false; $missing.approvals += 'writing_approved' }
    else {
        $assets = Test-IllustrationAssets $illustrationDir
        $illustrationProv = $prov.illustration_execution.valid
        if ((@($assets.Values | Where-Object { -not $_ }).Count -gt 0) -or -not $illustrationProv) { $stage='awaiting_illustration_execution'; $reason='Illustration assets or provenance are incomplete.'; $next='Plan, generate, archive and record illustration execution.'; $missing.files += @($assets.Keys | Where-Object { -not $assets[$_] }); if (-not $illustrationProv) { $missing.provenance += 'illustration_execution' } }
        else { $publish = Test-PublishUnitCompleted $publishDir; if (-not $publish.completed) { $stage='ready_for_publish_unit'; $reason='Writing and illustration evidence are complete; publish unit is incomplete.'; $next='Generate and review the final publish unit.'; foreach ($k in $publish.details.Keys) { if (-not $publish.details[$k]) { $missing.files += $k } } } }
    }
    return New-ValidationResult $stage $ready $reason $next $w $missing $prov $approval $WorkitemPath $draft $article $approvalDir $provenanceDir $illustrationDir $publishDir
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $WorkitemPath
    $result | ConvertTo-Json -Depth 8
    if ($result.is_ready_for_postwriting) { exit 0 }; exit 2
}
