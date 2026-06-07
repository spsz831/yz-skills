$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'validate-gzhrb-writing-state.ps1'

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

function New-TestFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function New-TestJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    New-TestFile -Path $Path -Content ($Value | ConvertTo-Json -Depth 8)
}

function Read-TestJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return $raw | ConvertFrom-Json
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Actual,
        [Parameter(Mandatory)][string]$ExpectedSubstring,
        [string]$Message
    )

    if (-not $Actual.Contains($ExpectedSubstring)) {
        throw "Assert-Contains failed: $Message`nExpected substring: $ExpectedSubstring`nActual: $Actual"
    }
}

function Get-ChineseTopicTitle {
    return ('"\u72ec\u5bb6\uff1a\u5fae\u8f6f\u5c06\u4e8e6\u6708\u5c06\u6240\u6709GitHub Copilot\u8ba2\u9605\u7528\u6237\u8f6c\u4e3a\u57fa\u4e8eToken\u7684\u8ba1\u8d39\u6a21\u5f0f"' | ConvertFrom-Json)
}

function New-TestFixture {
    param([string]$Name)

    $root = Join-Path $env:TEMP ("validate-gzhrb-writing-state-$Name-" + [guid]::NewGuid().ToString('N'))
    $gzhrbDir = Join-Path $root 'reports\gzhrb'
    $workitemDir = Join-Path $gzhrbDir 'workitems'
    $draftDir = Join-Path $gzhrbDir 'drafts'
    $articleRoot = Join-Path $gzhrbDir 'articles'
    $approvalRoot = Join-Path $gzhrbDir 'approvals'
    $provenanceRoot = Join-Path $gzhrbDir 'provenance'
    $illustrationRoot = Join-Path $gzhrbDir 'illustrations'
    $publishUnitRoot = Join-Path $gzhrbDir 'publish-units'

    New-Item -ItemType Directory -Force -Path $gzhrbDir, $workitemDir, $draftDir, $articleRoot, $approvalRoot, $provenanceRoot, $illustrationRoot, $publishUnitRoot | Out-Null

    $articleId = 'gzhrb-20260423-1200-topic'
    $articleIdentityPath = Join-Path $gzhrbDir "$articleId.md"
    $draftPath = Join-Path $draftDir "$articleId-khazix.md"
    $articleDir = Join-Path $articleRoot $articleId
    $optimizedArticlePath = Join-Path $articleDir 'article.md'
    $approvalDir = Join-Path $approvalRoot $articleId
    $provenanceDir = Join-Path $provenanceRoot $articleId
    $illustrationDir = Join-Path $illustrationRoot $articleId
    $publishUnitDir = Join-Path $publishUnitRoot $articleId
    $workitemPath = Join-Path $workitemDir "$articleId.json"

    New-Item -ItemType Directory -Force -Path $articleDir, $approvalDir, $provenanceDir, $illustrationDir, $publishUnitDir | Out-Null
    New-TestFile -Path $articleIdentityPath -Content '# article identity'

    return [pscustomobject]@{
        Root = $root
        ArticleId = $articleId
        ArticlePath = $articleIdentityPath
        WorkitemPath = $workitemPath
        DraftPath = $draftPath
        OptimizedArticlePath = $optimizedArticlePath
        ApprovalDir = $approvalDir
        ProvenanceDir = $provenanceDir
        IllustrationDir = $illustrationDir
        PublishUnitDir = $publishUnitDir
    }
}

function Write-TestWorkitem {
    param(
        [Parameter(Mandatory)]$Fixture,
        [string]$Stage = 'awaiting_topic_approval',
        [array]$ExecutionLog = @(),
        [string]$TopicTitle = 'default-topic'
    )

    $workitem = [ordered]@{
        workflow = 'ai-yang-detective-content-pipeline'
        article_id = $Fixture.ArticleId
        stage = $Stage
        topic = [ordered]@{
            title = $TopicTitle
            summary = 'utf8-summary-check'
        }
        writing_state = [ordered]@{
            khazix = [ordered]@{
                status = 'pending'
                completed_at = $null
                updated_at = $null
                updated_by = $null
                source_path = $null
            }
            wechat = [ordered]@{
                status = 'pending'
                completed_at = $null
                updated_at = $null
                updated_by = $null
                source_path = $null
            }
        }
        paths = [ordered]@{
            khazix_draft = $Fixture.DraftPath
            optimized_article = $Fixture.OptimizedArticlePath
            article_dir = (Split-Path -Parent $Fixture.OptimizedArticlePath)
            approval_dir = $Fixture.ApprovalDir
            provenance_dir = $Fixture.ProvenanceDir
            illustration_dir = $Fixture.IllustrationDir
            publish_unit_dir = $Fixture.PublishUnitDir
        }
        execution_log = $ExecutionLog
    }

    New-TestJson -Path $Fixture.WorkitemPath -Value $workitem
}

function Write-Approval {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$Name
    )

    New-TestJson -Path (Join-Path $Fixture.ApprovalDir "$Name.json") -Value ([ordered]@{
        article_id = $Fixture.ArticleId
        stage = $Name
        approved = $true
        approved_by = 'test'
        approved_at = '2026-04-23T10:00:00+08:00'
    })
}

function Write-Provenance {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$SkillName,
        [Parameter(Mandatory)][string]$OutputPath
    )

    New-TestJson -Path (Join-Path $Fixture.ProvenanceDir $FileName) -Value ([ordered]@{
        article_id = $Fixture.ArticleId
        skill_name = $SkillName
        output_path = $OutputPath
        status = 'completed'
    })
}

function Write-IllustrationAssets {
    param([Parameter(Mandatory)]$Fixture)

    New-TestJson -Path (Join-Path $Fixture.IllustrationDir 'placement.json') -Value ([ordered]@{ slots = @('cover') })
    New-TestJson -Path (Join-Path $Fixture.IllustrationDir 'batch.json') -Value ([ordered]@{ images = @('cover.png') })
    New-TestFile -Path (Join-Path $Fixture.IllustrationDir 'outline.md') -Content '# outline'
    New-Item -ItemType Directory -Force -Path (Join-Path $Fixture.IllustrationDir 'prompts') | Out-Null
    New-TestFile -Path (Join-Path $Fixture.IllustrationDir 'cover.png') -Content 'fake-png'
}

function Write-PublishUnitFiles {
    param([Parameter(Mandatory)]$Fixture)

    New-TestFile -Path (Join-Path $Fixture.PublishUnitDir 'article.md') -Content '# packaged article'
    New-TestFile -Path (Join-Path $Fixture.PublishUnitDir 'titles.txt') -Content 'title-a'
    New-TestFile -Path (Join-Path $Fixture.PublishUnitDir 'intro-lines.txt') -Content 'intro-a'
    New-TestFile -Path (Join-Path $Fixture.PublishUnitDir 'topic-tags.txt') -Content '#tag'
    New-TestJson -Path (Join-Path $Fixture.PublishUnitDir 'package.json') -Value ([ordered]@{ ok = $true })
    New-TestFile -Path (Join-Path $Fixture.PublishUnitDir 'review-checklist.md') -Content '- [ ] review'
    New-Item -ItemType Directory -Force -Path (Join-Path $Fixture.PublishUnitDir 'illustrations') | Out-Null
}

$topicPending = New-TestFixture -Name 'topic-pending'
Write-TestWorkitem -Fixture $topicPending -Stage 'awaiting_topic_approval'
$result = Get-GzhrbWritingStateValidation -ArticlePath $topicPending.ArticlePath -WorkitemPath $topicPending.WorkitemPath
Assert-Equal $result.stage 'awaiting_topic_approval' 'No topic approval should stay in topic approval stage'
Assert-True ($result.missing_evidence.approvals -contains 'topic_selected') 'Should mark missing topic approval evidence'
Assert-True (-not $result.approval_state.topic_selected) 'Topic approval should be false'
Remove-Item -LiteralPath $topicPending.Root -Recurse -Force

$utf8ChineseFixture = New-TestFixture -Name 'utf8-chinese'
$expectedChineseTopicTitle = Get-ChineseTopicTitle
Write-TestWorkitem -Fixture $utf8ChineseFixture -Stage 'awaiting_topic_approval' -TopicTitle $expectedChineseTopicTitle
$result = Get-GzhrbWritingStateValidation -ArticlePath $utf8ChineseFixture.ArticlePath -WorkitemPath $utf8ChineseFixture.WorkitemPath
$workitem = Read-GzhrbWorkitem -WorkitemPath $utf8ChineseFixture.WorkitemPath
Assert-Equal $workitem.topic.title $expectedChineseTopicTitle 'UTF-8 Chinese topic title should round-trip correctly in workitem JSON'
Assert-Equal $result.stage 'awaiting_topic_approval' 'Chinese workitem should still validate normally'
Remove-Item -LiteralPath $utf8ChineseFixture.Root -Recurse -Force

$khazixMissingProvenance = New-TestFixture -Name 'khazix-missing-provenance'
Write-TestWorkitem -Fixture $khazixMissingProvenance -Stage 'awaiting_khazix_execution'
Write-Approval -Fixture $khazixMissingProvenance -Name 'topic-selected'
New-TestFile -Path $khazixMissingProvenance.DraftPath -Content '# khazix draft'
$result = Get-GzhrbWritingStateValidation -ArticlePath $khazixMissingProvenance.ArticlePath -WorkitemPath $khazixMissingProvenance.WorkitemPath
Assert-Equal $result.stage 'awaiting_khazix_execution' 'Missing khazix provenance should block khazix execution stage'
Assert-True ($result.missing_evidence.provenance -contains 'khazix_execution') 'Should mark missing khazix provenance'
Assert-True (-not $result.provenance_state.khazix_execution.valid) 'Khazix provenance should be invalid'
Remove-Item -LiteralPath $khazixMissingProvenance.Root -Recurse -Force

$khazixAwaitingApproval = New-TestFixture -Name 'khazix-awaiting-approval'
Write-TestWorkitem -Fixture $khazixAwaitingApproval -Stage 'awaiting_khazix_approval'
Write-Approval -Fixture $khazixAwaitingApproval -Name 'topic-selected'
New-TestFile -Path $khazixAwaitingApproval.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $khazixAwaitingApproval -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $khazixAwaitingApproval.DraftPath
$result = Get-GzhrbWritingStateValidation -ArticlePath $khazixAwaitingApproval.ArticlePath -WorkitemPath $khazixAwaitingApproval.WorkitemPath
Assert-Equal $result.stage 'awaiting_khazix_approval' 'Khazix should wait for approval after execution evidence is complete'
Assert-True ($result.missing_evidence.approvals -contains 'khazix_approved') 'Should mark missing khazix approval'
Assert-True (-not $result.approval_state.khazix_approved) 'Khazix approval should be false'
Remove-Item -LiteralPath $khazixAwaitingApproval.Root -Recurse -Force

$wechatMissingProvenance = New-TestFixture -Name 'wechat-missing-provenance'
Write-TestWorkitem -Fixture $wechatMissingProvenance -Stage 'awaiting_wechat_execution'
Write-Approval -Fixture $wechatMissingProvenance -Name 'topic-selected'
Write-Approval -Fixture $wechatMissingProvenance -Name 'khazix-approved'
New-TestFile -Path $wechatMissingProvenance.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $wechatMissingProvenance -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $wechatMissingProvenance.DraftPath
New-TestFile -Path $wechatMissingProvenance.OptimizedArticlePath -Content '# wechat article'
$result = Get-GzhrbWritingStateValidation -ArticlePath $wechatMissingProvenance.ArticlePath -WorkitemPath $wechatMissingProvenance.WorkitemPath
Assert-Equal $result.stage 'awaiting_wechat_execution' 'Missing wechat provenance should block wechat execution stage'
Assert-True ($result.missing_evidence.provenance -contains 'wechat_execution') 'Should mark missing wechat provenance'
Assert-True (-not $result.provenance_state.wechat_execution.valid) 'Wechat provenance should be invalid'
Remove-Item -LiteralPath $wechatMissingProvenance.Root -Recurse -Force

$wechatAwaitingApproval = New-TestFixture -Name 'wechat-awaiting-approval'
Write-TestWorkitem -Fixture $wechatAwaitingApproval -Stage 'awaiting_wechat_approval'
Write-Approval -Fixture $wechatAwaitingApproval -Name 'topic-selected'
Write-Approval -Fixture $wechatAwaitingApproval -Name 'khazix-approved'
New-TestFile -Path $wechatAwaitingApproval.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $wechatAwaitingApproval -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $wechatAwaitingApproval.DraftPath
New-TestFile -Path $wechatAwaitingApproval.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $wechatAwaitingApproval -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $wechatAwaitingApproval.OptimizedArticlePath
$result = Get-GzhrbWritingStateValidation -ArticlePath $wechatAwaitingApproval.ArticlePath -WorkitemPath $wechatAwaitingApproval.WorkitemPath
Assert-Equal $result.stage 'awaiting_wechat_approval' 'Wechat should wait for approval after execution evidence is complete'
Assert-True ($result.missing_evidence.approvals -contains 'wechat_approved') 'Should mark missing wechat approval'
Remove-Item -LiteralPath $wechatAwaitingApproval.Root -Recurse -Force

$illustrationAwaitingExecution = New-TestFixture -Name 'illustration-awaiting-execution'
Write-TestWorkitem -Fixture $illustrationAwaitingExecution -Stage 'awaiting_illustration_execution'
Write-Approval -Fixture $illustrationAwaitingExecution -Name 'topic-selected'
Write-Approval -Fixture $illustrationAwaitingExecution -Name 'khazix-approved'
Write-Approval -Fixture $illustrationAwaitingExecution -Name 'wechat-approved'
New-TestFile -Path $illustrationAwaitingExecution.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $illustrationAwaitingExecution -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $illustrationAwaitingExecution.DraftPath
New-TestFile -Path $illustrationAwaitingExecution.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $illustrationAwaitingExecution -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $illustrationAwaitingExecution.OptimizedArticlePath
$result = Get-GzhrbWritingStateValidation -ArticlePath $illustrationAwaitingExecution.ArticlePath -WorkitemPath $illustrationAwaitingExecution.WorkitemPath
Assert-Equal $result.stage 'awaiting_illustration_execution' 'Missing illustration assets should block illustration execution stage'
Assert-True ($result.missing_evidence.files -contains 'illustration_placement') 'Should mark missing illustration placement file'
Assert-True ($result.missing_evidence.provenance -contains 'illustration_execution') 'Should mark missing illustration provenance'
Remove-Item -LiteralPath $illustrationAwaitingExecution.Root -Recurse -Force

$illustrationReadyForPublish = New-TestFixture -Name 'illustration-ready-for-publish'
Write-TestWorkitem -Fixture $illustrationReadyForPublish -Stage 'awaiting_illustration_execution'
Write-Approval -Fixture $illustrationReadyForPublish -Name 'topic-selected'
Write-Approval -Fixture $illustrationReadyForPublish -Name 'khazix-approved'
Write-Approval -Fixture $illustrationReadyForPublish -Name 'wechat-approved'
New-TestFile -Path $illustrationReadyForPublish.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $illustrationReadyForPublish -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $illustrationReadyForPublish.DraftPath
New-TestFile -Path $illustrationReadyForPublish.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $illustrationReadyForPublish -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $illustrationReadyForPublish.OptimizedArticlePath
Write-IllustrationAssets -Fixture $illustrationReadyForPublish
Write-Provenance -Fixture $illustrationReadyForPublish -FileName 'illustration-execution.json' -SkillName 'baoyu-article-illustrator' -OutputPath $illustrationReadyForPublish.IllustrationDir
$result = Get-GzhrbWritingStateValidation -ArticlePath $illustrationReadyForPublish.ArticlePath -WorkitemPath $illustrationReadyForPublish.WorkitemPath
Assert-Equal $result.stage 'ready_for_publish_unit' 'Illustration execution should flow directly into publish-unit preparation'
Assert-True ($result.missing_evidence.files -contains 'publish_unit_article') 'Should move directly to publish-unit missing files after illustration execution'
Remove-Item -LiteralPath $illustrationReadyForPublish.Root -Recurse -Force

$readyForPublishUnit = New-TestFixture -Name 'ready-for-publish-unit'
Write-TestWorkitem -Fixture $readyForPublishUnit -Stage 'ready_for_publish_unit'
Write-Approval -Fixture $readyForPublishUnit -Name 'topic-selected'
Write-Approval -Fixture $readyForPublishUnit -Name 'khazix-approved'
Write-Approval -Fixture $readyForPublishUnit -Name 'wechat-approved'
Write-Approval -Fixture $readyForPublishUnit -Name 'illustrations-approved'
New-TestFile -Path $readyForPublishUnit.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $readyForPublishUnit -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $readyForPublishUnit.DraftPath
New-TestFile -Path $readyForPublishUnit.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $readyForPublishUnit -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $readyForPublishUnit.OptimizedArticlePath
Write-IllustrationAssets -Fixture $readyForPublishUnit
Write-Provenance -Fixture $readyForPublishUnit -FileName 'illustration-execution.json' -SkillName 'baoyu-article-illustrator' -OutputPath $readyForPublishUnit.IllustrationDir
$result = Get-GzhrbWritingStateValidation -ArticlePath $readyForPublishUnit.ArticlePath -WorkitemPath $readyForPublishUnit.WorkitemPath
Assert-Equal $result.stage 'ready_for_publish_unit' 'Without publish unit files, state should be ready_for_publish_unit'
Assert-True ($result.missing_evidence.files -contains 'publish_unit_article') 'Should mark missing publish unit files'
Assert-True $result.is_ready_for_postwriting 'Ready-for-publish-unit should be considered ready for postwriting operations'
Remove-Item -LiteralPath $readyForPublishUnit.Root -Recurse -Force

$completedFixture = New-TestFixture -Name 'completed'
Write-TestWorkitem -Fixture $completedFixture -Stage 'completed'
Write-Approval -Fixture $completedFixture -Name 'topic-selected'
Write-Approval -Fixture $completedFixture -Name 'khazix-approved'
Write-Approval -Fixture $completedFixture -Name 'wechat-approved'
Write-Approval -Fixture $completedFixture -Name 'illustrations-approved'
New-TestFile -Path $completedFixture.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $completedFixture -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $completedFixture.DraftPath
New-TestFile -Path $completedFixture.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $completedFixture -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $completedFixture.OptimizedArticlePath
Write-IllustrationAssets -Fixture $completedFixture
Write-Provenance -Fixture $completedFixture -FileName 'illustration-execution.json' -SkillName 'baoyu-article-illustrator' -OutputPath $completedFixture.IllustrationDir
Write-PublishUnitFiles -Fixture $completedFixture
$result = Get-GzhrbWritingStateValidation -ArticlePath $completedFixture.ArticlePath -WorkitemPath $completedFixture.WorkitemPath
Assert-Equal $result.stage 'completed' 'Complete publish unit should move to completed stage'
Assert-Equal $result.evidence_stage 'completed' 'Evidence stage should be completed'
Assert-True ($result.missing_evidence.files.Count -eq 0) 'Completed stage should have no missing files'
Assert-True ($result.missing_evidence.provenance.Count -eq 0) 'Completed stage should have no missing provenance'
Assert-True ($result.missing_evidence.approvals.Count -eq 0) 'Completed stage should have no missing approvals'
Remove-Item -LiteralPath $completedFixture.Root -Recurse -Force

$stateScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'gzhrb-writing-state.ps1'
if (-not (Test-Path -LiteralPath $stateScriptPath)) {
    throw "Script not found: $stateScriptPath"
}

. $stateScriptPath

$statusSummaryFixture = New-TestFixture -Name 'status-summary'
Write-TestWorkitem -Fixture $statusSummaryFixture -Stage 'completed'
Write-Approval -Fixture $statusSummaryFixture -Name 'topic-selected'
Write-Approval -Fixture $statusSummaryFixture -Name 'khazix-approved'
Write-Approval -Fixture $statusSummaryFixture -Name 'wechat-approved'
New-TestFile -Path $statusSummaryFixture.DraftPath -Content '# khazix draft'
Write-Provenance -Fixture $statusSummaryFixture -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $statusSummaryFixture.DraftPath
New-TestFile -Path $statusSummaryFixture.OptimizedArticlePath -Content '# wechat article'
Write-Provenance -Fixture $statusSummaryFixture -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $statusSummaryFixture.OptimizedArticlePath
Write-IllustrationAssets -Fixture $statusSummaryFixture
Write-Provenance -Fixture $statusSummaryFixture -FileName 'illustration-execution.json' -SkillName 'baoyu-article-illustrator' -OutputPath $statusSummaryFixture.IllustrationDir
Write-PublishUnitFiles -Fixture $statusSummaryFixture

$originalGetProjectDir = ${function:Get-ProjectDir}
${function:Get-ProjectDir} = { return $statusSummaryFixture.Root }

try {
    $summaryText = Get-GzhrbWritingStateStatusSummary -Limit 1
    Assert-Contains $summaryText 'Recent GZHRB writing states:' 'Status summary should render a header'
    Assert-Contains $summaryText $statusSummaryFixture.ArticleId 'Status summary should include the article id without relying on Split-Path -LeafBase'

    $summaryJson = Get-GzhrbWritingStateStatusSummaryJson -Limit 1
    Assert-Equal $summaryJson.count 1 'Status summary JSON should return one item'
    Assert-Equal $summaryJson.items[0].article_id $statusSummaryFixture.ArticleId 'Status summary JSON should preserve article id extraction'
}
finally {
    ${function:Get-ProjectDir} = $originalGetProjectDir
    Remove-Item -LiteralPath $statusSummaryFixture.Root -Recurse -Force
}

Write-Host 'All validate-gzhrb-writing-state tests passed.'
