$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'gzhrb-writing-state.cmd'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
}

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

function New-TestWorkitemJson {
    param(
        [Parameter(Mandatory)][string]$DraftPath,
        [Parameter(Mandatory)][string]$ArticlePath,
        [string]$ArticleId,
        [string]$Stage = 'awaiting_topic_approval',
        [string]$ApprovalDir,
        [string]$ProvenanceDir,
        [string]$IllustrationDir,
        [string]$PublishUnitDir
    )

    return ([ordered]@{
        stage = $Stage
        article_id = $ArticleId
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
            khazix_draft = $DraftPath
            optimized_article = $ArticlePath
            approval_dir = $ApprovalDir
            provenance_dir = $ProvenanceDir
            illustration_dir = $IllustrationDir
            publish_unit_dir = $PublishUnitDir
        }
        execution_log = @()
    } | ConvertTo-Json -Depth 6)
}

$projectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$articleDir = Join-Path $projectDir 'reports\gzhrb'
$draftDir = Join-Path $articleDir 'drafts'
$workitemDir = Join-Path $articleDir 'workitems'
$articleRoot = Join-Path $articleDir 'articles'
$approvalRoot = Join-Path $articleDir 'approvals'
$provenanceRoot = Join-Path $articleDir 'provenance'
$illustrationRoot = Join-Path $articleDir 'illustrations'
$publishUnitRoot = Join-Path $articleDir 'publish-units'
New-Item -ItemType Directory -Force -Path $articleDir, $draftDir, $workitemDir, $articleRoot, $approvalRoot, $provenanceRoot, $illustrationRoot, $publishUnitRoot | Out-Null

$articleId = "gzhrb-test-" + [guid]::NewGuid().ToString('N')
$articlePath = Join-Path (Join-Path $articleRoot $articleId) 'article.md'
$draftPath = Join-Path $draftDir "$articleId-khazix.md"
$workitemPath = Join-Path $workitemDir "$articleId.json"
$approvalDir = Join-Path $approvalRoot $articleId
$provenanceDir = Join-Path $provenanceRoot $articleId
$illustrationDir = Join-Path $illustrationRoot $articleId
$publishUnitDir = Join-Path $publishUnitRoot $articleId

New-TestFile -Path $articlePath -Content '# article'
New-TestFile -Path $draftPath -Content '# khazix draft'
New-TestFile -Path $workitemPath -Content (New-TestWorkitemJson -DraftPath $draftPath -ArticlePath $articlePath -ArticleId $articleId -ApprovalDir $approvalDir -ProvenanceDir $provenanceDir -IllustrationDir $illustrationDir -PublishUnitDir $publishUnitDir)

$invalid = & cmd /c "`"$scriptPath`" --no-pause bad-action `"$articlePath`"" 2>&1
Assert-True ($LASTEXITCODE -ne 0) 'Unknown action should fail'
Assert-True (($invalid -join "`n").Contains('Unknown action')) 'Unknown action should report usage error'

$help = & cmd /c "`"$scriptPath`" --no-pause help" 2>&1
Assert-Equal $LASTEXITCODE 0 'Help action should succeed'
Assert-True (($help -join "`n").Contains('Usage:')) 'Help action should print usage'

$inspect = & cmd /c "`"$scriptPath`" --no-pause inspect `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'Inspect action should succeed'
Assert-True (($inspect -join "`n").Contains('Declared stage')) 'Inspect action should route to inspect command'

$inspectJson = & cmd /c "`"$scriptPath`" --no-pause inspect-json --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'inspect-json action should succeed'
$inspectJsonText = ($inspectJson -join "`n")
Assert-True ($inspectJsonText.Contains('"declared_stage"')) 'inspect-json should return validator json'

New-TestFile -Path (Join-Path $approvalDir 'topic-selected.json') -Content (([ordered]@{
    article_id = $articleId
    approved_by = 'tester'
    approved_at = '2026-04-23T09:55:00+08:00'
    stage = 'topic_selected'
} | ConvertTo-Json -Depth 6))
New-TestFile -Path (Join-Path $provenanceDir 'khazix-execution.json') -Content (([ordered]@{
    article_id = $articleId
    skill_name = 'khazix-writer'
    session_id = 'test-session'
    input_path = $articlePath
    output_path = $draftPath
    started_at = '2026-04-23T10:00:00+08:00'
    completed_at = '2026-04-23T10:05:00+08:00'
    status = 'completed'
} | ConvertTo-Json -Depth 6))

$autoSync = & cmd /c "`"$scriptPath`" --no-pause auto-sync --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'auto-sync action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.writing_state.khazix.status 'completed' 'auto-sync should complete khazix when evidence exists'
Assert-True ($workitem.writing_state.wechat.status -in @('pending', 'completed')) 'auto-sync should keep wechat state valid'
Assert-True ($workitem.execution_log.Count -ge 1) 'auto-sync should append at least one log entry'

$markKhazix = & cmd /c "`"$scriptPath`" --no-pause mark-khazix --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'mark-khazix action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.writing_state.khazix.status 'completed' 'mark-khazix should update workitem'

$workitem.stage = 'awaiting_wechat_execution'
New-TestFile -Path $workitemPath -Content ($workitem | ConvertTo-Json -Depth 8)
New-TestFile -Path (Join-Path $approvalDir 'khazix-approved.json') -Content (([ordered]@{
    article_id = $articleId
    approved_by = 'tester'
    approved_at = '2026-04-23T10:06:00+08:00'
    stage = 'khazix_approved'
} | ConvertTo-Json -Depth 6))
New-TestFile -Path (Join-Path $provenanceDir 'wechat-execution.json') -Content (([ordered]@{
    article_id = $articleId
    skill_name = 'wechat-article-writer'
    session_id = 'test-session'
    input_path = $draftPath
    output_path = $articlePath
    started_at = '2026-04-23T11:00:00+08:00'
    completed_at = '2026-04-23T11:05:00+08:00'
    status = 'completed'
} | ConvertTo-Json -Depth 6))

$markWechat = & cmd /c "`"$scriptPath`" --no-pause mark-wechat --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'mark-wechat action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.writing_state.wechat.status 'completed' 'mark-wechat should update workitem'

$approvalWorkitem = [ordered]@{
    stage = 'awaiting_topic_approval'
    article_id = $articleId
    writing_state = [ordered]@{
        khazix = [ordered]@{
            status = 'completed'
            completed_at = $null
            updated_at = $null
            updated_by = $null
            source_path = $draftPath
        }
        wechat = [ordered]@{
            status = 'completed'
            completed_at = $null
            updated_at = $null
            updated_by = $null
            source_path = $articlePath
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
New-TestFile -Path $workitemPath -Content $approvalWorkitem

$approveTopic = & cmd /c "`"$scriptPath`" --no-pause approve-topic --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'approve-topic action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.stage 'awaiting_khazix_execution' 'approve-topic should move stage to awaiting_khazix_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $approvalDir 'topic-selected.json')) 'approve-topic should write topic-selected approval file'

$workitem.stage = 'awaiting_khazix_approval'
New-TestFile -Path $workitemPath -Content ($workitem | ConvertTo-Json -Depth 8)
New-TestFile -Path $draftPath -Content '# khazix draft'
New-TestFile -Path (Join-Path $provenanceDir 'khazix-execution.json') -Content (([ordered]@{
    article_id = $articleId
    skill_name = 'khazix-writer'
    session_id = 'test-session'
    input_path = $articlePath
    output_path = $draftPath
    started_at = '2026-04-23T10:00:00+08:00'
    completed_at = '2026-04-23T10:05:00+08:00'
    status = 'completed'
} | ConvertTo-Json -Depth 6))

$approveKhazix = & cmd /c "`"$scriptPath`" --no-pause approve-khazix --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'approve-khazix action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.stage 'awaiting_wechat_execution' 'approve-khazix should move stage to awaiting_wechat_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $approvalDir 'khazix-approved.json')) 'approve-khazix should write khazix-approved file'

$workitem.stage = 'awaiting_wechat_approval'
New-TestFile -Path $workitemPath -Content ($workitem | ConvertTo-Json -Depth 8)
New-TestFile -Path $articlePath -Content '# optimized article'
New-TestFile -Path (Join-Path $provenanceDir 'wechat-execution.json') -Content (([ordered]@{
    article_id = $articleId
    skill_name = 'wechat-article-writer'
    session_id = 'test-session'
    input_path = $draftPath
    output_path = $articlePath
    started_at = '2026-04-23T11:00:00+08:00'
    completed_at = '2026-04-23T11:05:00+08:00'
    status = 'completed'
} | ConvertTo-Json -Depth 6))

$approveWechat = & cmd /c "`"$scriptPath`" --no-pause approve-wechat --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'approve-wechat action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.stage 'awaiting_illustration_execution' 'approve-wechat should move stage to awaiting_illustration_execution'
Assert-True (Test-Path -LiteralPath (Join-Path $approvalDir 'wechat-approved.json')) 'approve-wechat should write wechat-approved file'

$workitem.stage = 'awaiting_illustration_approval'
New-TestFile -Path $workitemPath -Content ($workitem | ConvertTo-Json -Depth 8)
New-TestFile -Path (Join-Path $illustrationDir 'placement.json') -Content '{"placements":[]}'
New-TestFile -Path (Join-Path $illustrationDir 'batch.json') -Content '{"batch":[]}'
New-TestFile -Path (Join-Path $illustrationDir 'outline.md') -Content '# outline'
New-Item -ItemType Directory -Force -Path (Join-Path $illustrationDir 'prompts') | Out-Null
New-TestFile -Path (Join-Path $illustrationDir 'image-01.png') -Content 'fake-image'
New-TestFile -Path (Join-Path $provenanceDir 'illustration-execution.json') -Content (([ordered]@{
    article_id = $articleId
    skill_name = 'baoyu-article-illustrator'
    session_id = 'test-session'
    input_path = $articlePath
    output_path = $illustrationDir
    started_at = '2026-04-23T12:00:00+08:00'
    completed_at = '2026-04-23T12:05:00+08:00'
    status = 'completed'
} | ConvertTo-Json -Depth 6))

$approveIllustrations = & cmd /c "`"$scriptPath`" --no-pause approve-illustrations --article `"$articlePath`"" 2>&1
Assert-Equal $LASTEXITCODE 0 'approve-illustrations action should succeed'
$workitem = Get-Content -Raw -LiteralPath $workitemPath | ConvertFrom-Json
Assert-Equal $workitem.stage 'ready_for_publish_unit' 'approve-illustrations should move stage to ready_for_publish_unit'
Assert-True (Test-Path -LiteralPath (Join-Path $approvalDir 'illustrations-approved.json')) 'approve-illustrations should write illustrations-approved file'

Remove-Item -LiteralPath $articlePath -Force
Remove-Item -LiteralPath $draftPath -Force
Remove-Item -LiteralPath $workitemPath -Force
if (Test-Path -LiteralPath (Split-Path -Parent $articlePath)) { Remove-Item -LiteralPath (Split-Path -Parent $articlePath) -Recurse -Force }
if (Test-Path -LiteralPath $approvalDir) { Remove-Item -LiteralPath $approvalDir -Recurse -Force }
if (Test-Path -LiteralPath $provenanceDir) { Remove-Item -LiteralPath $provenanceDir -Recurse -Force }
if (Test-Path -LiteralPath $illustrationDir) { Remove-Item -LiteralPath $illustrationDir -Recurse -Force }
if (Test-Path -LiteralPath $publishUnitDir) { Remove-Item -LiteralPath $publishUnitDir -Recurse -Force }

Write-Host 'All gzhrb-writing-state.cmd tests passed.'
