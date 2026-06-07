$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'approve-gzhrb-stage.ps1'

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

function Assert-ThrowsContains {
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [Parameter(Mandatory)][string]$ExpectedText,
        [string]$Message
    )

    $thrown = $false
    try {
        & $ScriptBlock
    } catch {
        $thrown = $true
        if (-not $_.Exception.Message.Contains($ExpectedText)) {
            throw "Assert-ThrowsContains failed: $Message`nExpected message to contain: $ExpectedText`nActual: $($_.Exception.Message)"
        }
    }

    if (-not $thrown) {
        throw "Assert-ThrowsContains failed: $Message`nExpected scriptblock to throw."
    }
}

function Write-TestFile {
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

function Read-TestJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return $raw | ConvertFrom-Json
}

function Get-ChineseTopicTitle {
    return ('"\u72ec\u5bb6\uff1a\u5fae\u8f6f\u5c06\u4e8e6\u6708\u5c06\u6240\u6709GitHub Copilot\u8ba2\u9605\u7528\u6237\u8f6c\u4e3a\u57fa\u4e8eToken\u7684\u8ba1\u8d39\u6a21\u5f0f"' | ConvertFrom-Json)
}

function New-TestFixture {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Stage,
        [string]$TopicTitle = 'default-topic'
    )

    $root = Join-Path $env:TEMP ("approve-gzhrb-stage-$Name-" + [guid]::NewGuid().ToString('N'))
    $articleId = "gzhrb-test-$Name-" + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $articleDir = Join-Path $root "reports\gzhrb\articles\$articleId"
    $articlePath = Join-Path $articleDir 'article.md'
    $draftPath = Join-Path $root "reports\gzhrb\drafts\$articleId-khazix.md"
    $workitemPath = Join-Path $root "reports\gzhrb\workitems\$articleId.json"
    $approvalDir = Join-Path $root "reports\gzhrb\approvals\$articleId"
    $provenanceDir = Join-Path $root "reports\gzhrb\provenance\$articleId"
    $illustrationDir = Join-Path $root "reports\gzhrb\illustrations\$articleId"
    $publishUnitDir = Join-Path $root "reports\gzhrb\publish-units\$articleId"

    New-Item -ItemType Directory -Force -Path $articleDir, (Split-Path -Parent $draftPath), (Split-Path -Parent $workitemPath), $approvalDir, $provenanceDir, $illustrationDir, $publishUnitDir | Out-Null
    Write-TestFile -Path $articlePath -Content '# article'

    $workitem = [ordered]@{
        stage = $Stage
        article_id = $articleId
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
            khazix_draft = $draftPath
            optimized_article = $articlePath
            approval_dir = $approvalDir
            provenance_dir = $provenanceDir
            illustration_dir = $illustrationDir
            publish_unit_dir = $publishUnitDir
        }
        execution_log = @()
    } | ConvertTo-Json -Depth 8

    Write-TestFile -Path $workitemPath -Content $workitem

    return [pscustomobject]@{
        Root = $root
        ArticleId = $articleId
        ArticlePath = $articlePath
        DraftPath = $draftPath
        WorkitemPath = $workitemPath
        ApprovalDir = $approvalDir
        ProvenanceDir = $provenanceDir
        IllustrationDir = $illustrationDir
    }
}

function Write-TestProvenance {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$SkillName,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $payload = [ordered]@{
        article_id = $Fixture.ArticleId
        skill_name = $SkillName
        session_id = 'test-session'
        input_path = $Fixture.ArticlePath
        output_path = $OutputPath
        started_at = '2026-04-23T12:00:00+08:00'
        completed_at = '2026-04-23T12:05:00+08:00'
        status = 'completed'
        note = 'fixture provenance'
    } | ConvertTo-Json -Depth 6

    Write-TestFile -Path (Join-Path $Fixture.ProvenanceDir $FileName) -Content $payload
}

function Write-IllustrationEvidence {
    param([Parameter(Mandatory)]$Fixture)

    Write-TestFile -Path (Join-Path $Fixture.IllustrationDir 'placement.json') -Content '{"placements":[]}'
    Write-TestFile -Path (Join-Path $Fixture.IllustrationDir 'batch.json') -Content '{"batch":[]}'
    Write-TestFile -Path (Join-Path $Fixture.IllustrationDir 'outline.md') -Content '# outline'
    New-Item -ItemType Directory -Force -Path (Join-Path $Fixture.IllustrationDir 'prompts') | Out-Null
    Write-TestFile -Path (Join-Path $Fixture.IllustrationDir 'img-01.png') -Content 'fake-image'
}

$topicFixture = New-TestFixture -Name 'topic' -Stage 'awaiting_topic_approval'
$topicResult = Set-GzhrbStageApproval -ArticlePath $topicFixture.ArticlePath -WorkitemPath $topicFixture.WorkitemPath -Stage 'topic_selected' -ApprovedBy 'tester' -Note 'approve topic'
Assert-Equal $topicResult.stage 'awaiting_khazix_execution' 'topic_selected should move to awaiting_khazix_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $topicFixture.ApprovalDir 'topic-selected.json')) 'topic approval file should exist'
$topicWorkitem = Read-TestJsonFile -Path $topicFixture.WorkitemPath
Assert-Equal $topicWorkitem.stage 'awaiting_khazix_execution' 'Workitem should persist topic approval transition'
Assert-Equal $topicWorkitem.execution_log.Count 1 'topic_selected should append one execution log entry'
Remove-Item -LiteralPath $topicFixture.Root -Recurse -Force

$khazixFixture = New-TestFixture -Name 'khazix' -Stage 'awaiting_khazix_approval'
Write-TestFile -Path $khazixFixture.DraftPath -Content '# khazix draft'
Write-TestProvenance -Fixture $khazixFixture -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $khazixFixture.DraftPath
$khazixResult = Set-GzhrbStageApproval -ArticlePath $khazixFixture.ArticlePath -WorkitemPath $khazixFixture.WorkitemPath -Stage 'khazix_approved' -ApprovedBy 'tester'
Assert-Equal $khazixResult.stage 'awaiting_wechat_execution' 'khazix_approved should move to awaiting_wechat_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $khazixFixture.ApprovalDir 'khazix-approved.json')) 'khazix approval file should exist'
Remove-Item -LiteralPath $khazixFixture.Root -Recurse -Force

$khazixChineseFixture = New-TestFixture -Name 'khazix-chinese' -Stage 'awaiting_khazix_approval' -TopicTitle (Get-ChineseTopicTitle)
Write-TestFile -Path $khazixChineseFixture.DraftPath -Content '# khazix draft'
Write-TestProvenance -Fixture $khazixChineseFixture -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $khazixChineseFixture.DraftPath
$khazixChineseResult = Set-GzhrbStageApproval -ArticlePath $khazixChineseFixture.ArticlePath -WorkitemPath $khazixChineseFixture.WorkitemPath -Stage 'khazix_approved' -ApprovedBy 'tester'
Assert-Equal $khazixChineseResult.stage 'awaiting_wechat_execution' 'Chinese khazix approval should move to awaiting_wechat_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $khazixChineseFixture.ApprovalDir 'khazix-approved.json')) 'Chinese khazix approval file should exist'
Remove-Item -LiteralPath $khazixChineseFixture.Root -Recurse -Force

$wechatFixture = New-TestFixture -Name 'wechat' -Stage 'awaiting_wechat_approval'
Write-TestFile -Path $wechatFixture.ArticlePath -Content '# optimized article'
Write-TestProvenance -Fixture $wechatFixture -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $wechatFixture.ArticlePath
$wechatResult = Set-GzhrbStageApproval -ArticlePath $wechatFixture.ArticlePath -WorkitemPath $wechatFixture.WorkitemPath -Stage 'wechat_approved' -ApprovedBy 'tester'
Assert-Equal $wechatResult.stage 'awaiting_illustration_execution' 'wechat_approved should move to awaiting_illustration_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $wechatFixture.ApprovalDir 'wechat-approved.json')) 'wechat approval file should exist'
Remove-Item -LiteralPath $wechatFixture.Root -Recurse -Force

$illustrationFixture = New-TestFixture -Name 'illustrations' -Stage 'awaiting_illustration_approval'
Write-IllustrationEvidence -Fixture $illustrationFixture
Write-TestProvenance -Fixture $illustrationFixture -FileName 'illustration-execution.json' -SkillName 'baoyu-article-illustrator' -OutputPath $illustrationFixture.IllustrationDir
$illustrationResult = Set-GzhrbStageApproval -ArticlePath $illustrationFixture.ArticlePath -WorkitemPath $illustrationFixture.WorkitemPath -Stage 'illustrations_approved' -ApprovedBy 'tester'
Assert-Equal $illustrationResult.stage 'ready_for_publish_unit' 'illustrations_approved should move to ready_for_publish_unit'
Assert-True (Test-Path -LiteralPath (Join-Path $illustrationFixture.ApprovalDir 'illustrations-approved.json')) 'illustrations approval file should exist'
Remove-Item -LiteralPath $illustrationFixture.Root -Recurse -Force

$invalidStageFixture = New-TestFixture -Name 'invalid-stage' -Stage 'awaiting_topic_approval'
Assert-ThrowsContains -ScriptBlock {
    Set-GzhrbStageApproval -ArticlePath $invalidStageFixture.ArticlePath -WorkitemPath $invalidStageFixture.WorkitemPath -Stage 'khazix_approved' -ApprovedBy 'tester' | Out-Null
} -ExpectedText 'Current stage does not allow approval' -Message 'Illegal stage transition should fail'
Remove-Item -LiteralPath $invalidStageFixture.Root -Recurse -Force

$missingEvidenceFixture = New-TestFixture -Name 'missing-evidence' -Stage 'awaiting_wechat_approval'
Assert-ThrowsContains -ScriptBlock {
    Set-GzhrbStageApproval -ArticlePath $missingEvidenceFixture.ArticlePath -WorkitemPath $missingEvidenceFixture.WorkitemPath -Stage 'wechat_approved' -ApprovedBy 'tester' | Out-Null
} -ExpectedText 'Missing required execution evidence' -Message 'Missing wechat execution evidence should fail'
Remove-Item -LiteralPath $missingEvidenceFixture.Root -Recurse -Force

Write-Host 'All approve-gzhrb-stage tests passed.'
