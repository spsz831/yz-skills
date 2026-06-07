$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'prepare-gzhrb-writing-workspace.ps1'

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

function Read-TestUtf8File {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$slug = Get-SlugFromText -Text '腾讯旗下 LightVela，提供免费一个月 Hermes，带 Kimi K2.5 模型'
Assert-True ($slug.Length -le 24) 'Slug should stay short for mixed Chinese and English titles'
Assert-True (-not $slug.Contains('u817e')) 'Slug should not encode Chinese characters as long uXXXX sequences'
Assert-True ($slug -match '^[a-z0-9-]+-[0-9a-f]{8}$') 'Slug should keep a short ASCII prefix plus stable hash'

$tempRoot = Join-Path $env:TEMP ("prepare-gzhrb-writing-workspace-test-" + [guid]::NewGuid().ToString('N'))
$digestDir = Join-Path $tempRoot 'reports\output'
$gzhrbDir = Join-Path $tempRoot 'reports\gzhrb'
New-Item -ItemType Directory -Force -Path $digestDir, $gzhrbDir | Out-Null

$digestPath = Join-Path $digestDir 'ai-daily-digest-20260421-1328.md'
[System.IO.File]::WriteAllText($digestPath, '# digest', (New-Object System.Text.UTF8Encoding($false)))

Start-GzhrbWritingWorkspacePreparation `
    -DigestPath $digestPath `
    -GzhrbDir $gzhrbDir `
    -TopicTitle 'Kimi K2.6 发布并开源' `
    -TopicSource 'Moonshot AI' `
    -TopicUrl 'https://example.com/kimi-k2-6' `
    -TopicSummary '这是一条测试摘要。' `
    -TopicCategory '模型发布' `
    -TopicAge '2h ago' `
    -TopicScore '92'

$workitemJsonPath = Get-ChildItem -LiteralPath (Join-Path $gzhrbDir 'workitems') -Filter '*.json' | Select-Object -ExpandProperty FullName -First 1
Assert-True (-not [string]::IsNullOrWhiteSpace($workitemJsonPath)) 'Should create a workitem json file'

$workitem = Get-Content -Raw -LiteralPath $workitemJsonPath | ConvertFrom-Json
$articleId = $workitem.article_id
Assert-True ($articleId -match '^gzhrb-\d{6}-\d{4}-[a-z0-9-]+-[0-9a-f]{8}$') 'Article id should use short date, time, topic slug and hash'
$draftPath = Join-Path $gzhrbDir "drafts\$articleId-khazix.md"
$articleDir = Join-Path $gzhrbDir "articles\$articleId"
$approvalDir = Join-Path $gzhrbDir "approvals\$articleId"
$provenanceDir = Join-Path $gzhrbDir "provenance\$articleId"
$publishUnitDir = Join-Path $gzhrbDir "publish-units\$articleId"
$optimizedPath = Join-Path $articleDir 'article.md'
$workitemMarkdownPath = Join-Path $gzhrbDir "workitems\$articleId.md"

Assert-True (Test-Path -LiteralPath $draftPath) 'Should create khazix draft placeholder'
Assert-True (Test-Path -LiteralPath $articleDir) 'Should create article working directory'
Assert-True (Test-Path -LiteralPath $approvalDir) 'Should create approval directory'
Assert-True (Test-Path -LiteralPath $provenanceDir) 'Should create provenance directory'
Assert-True (Test-Path -LiteralPath $publishUnitDir) 'Should create publish unit directory'
Assert-True (Test-Path -LiteralPath $workitemMarkdownPath) 'Should create workitem markdown'
Assert-True (-not (Test-Path -LiteralPath $optimizedPath)) 'Should not create optimized article before external skills write it'

Assert-Equal $workitem.article_id $articleId 'Should persist article id in workitem json'
Assert-Equal $workitem.stage 'awaiting_topic_approval' 'Should mark stage as awaiting topic approval'
Assert-Equal $workitem.writing_state.khazix.status 'pending' 'Should initialize khazix writing state'
Assert-Equal $workitem.writing_state.khazix.completed_at $null 'Should initialize khazix completed_at as null'
Assert-Equal $workitem.writing_state.khazix.updated_at $null 'Should initialize khazix updated_at as null'
Assert-Equal $workitem.writing_state.khazix.updated_by $null 'Should initialize khazix updated_by as null'
Assert-Equal $workitem.writing_state.khazix.source_path $null 'Should initialize khazix source_path as null'
Assert-Equal $workitem.writing_state.wechat.status 'pending' 'Should initialize wechat writing state'
Assert-Equal $workitem.writing_state.wechat.completed_at $null 'Should initialize wechat completed_at as null'
Assert-Equal $workitem.writing_state.wechat.updated_at $null 'Should initialize wechat updated_at as null'
Assert-Equal $workitem.writing_state.wechat.updated_by $null 'Should initialize wechat updated_by as null'
Assert-Equal $workitem.writing_state.wechat.source_path $null 'Should initialize wechat source_path as null'
Assert-Equal $workitem.execution_log.Count 0 'Should initialize empty execution log'
Assert-Equal $workitem.paths.khazix_draft $draftPath 'Should persist khazix draft path'
Assert-Equal $workitem.paths.optimized_article $optimizedPath 'Should persist optimized article path'
Assert-Equal $workitem.paths.article_dir $articleDir 'Should persist article directory'
Assert-Equal $workitem.paths.approval_dir $approvalDir 'Should persist approval directory'
Assert-Equal $workitem.paths.provenance_dir $provenanceDir 'Should persist provenance directory'
Assert-Equal $workitem.paths.publish_unit_dir $publishUnitDir 'Should persist publish unit directory'

$draftContent = Read-TestUtf8File -Path $draftPath
Assert-True ($draftContent.Contains('khazix-writer')) 'Draft placeholder should mention khazix-writer'
$workitemMarkdown = Read-TestUtf8File -Path $workitemMarkdownPath
Assert-True ($workitemMarkdown.Contains('awaiting_topic_approval')) 'Workitem markdown should describe topic approval stage'
Assert-True ($workitemMarkdown.Contains('awaiting_khazix_execution')) 'Workitem markdown should describe khazix execution stage'
Assert-True ($workitemMarkdown.Contains('awaiting_wechat_execution')) 'Workitem markdown should describe wechat execution stage'
Assert-True ($workitemMarkdown.Contains('ready_for_publish_unit')) 'Workitem markdown should describe publish-unit-ready stage'

Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Host 'All prepare-gzhrb-writing-workspace tests passed.'
