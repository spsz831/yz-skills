param(
    [string]$DigestPath,
    [string]$GzhrbDir,
    [string]$TopicTitle,
    [string]$TopicSource,
    [string]$TopicUrl,
    [string]$TopicSummary,
    [string]$TopicCategory,
    [string]$TopicAge,
    [string]$TopicScore
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Get-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Write-Utf8TextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
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

function Get-StableShortHash {
    param(
        [Parameter(Mandatory)][string]$Text,
        [int]$Length = 8
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hashBytes = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    $hash = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    return $hash.Substring(0, [Math]::Min($Length, $hash.Length))
}

function Get-ShortDateStamp {
    param([Parameter(Mandatory)][string]$DateStamp)

    if ($DateStamp.Length -ne 8) {
        throw "Invalid date stamp: $DateStamp"
    }

    return $DateStamp.Substring(2, 6)
}

function Get-SlugFromText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [string]$Fallback = 'topic',
        [int]$MaxLength = 24
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    $asciiBuilder = New-Object System.Text.StringBuilder

    foreach ($char in $Text.ToCharArray()) {
        $codePoint = [int][char]$char

        if (($codePoint -ge 48 -and $codePoint -le 57) -or
            ($codePoint -ge 65 -and $codePoint -le 90) -or
            ($codePoint -ge 97 -and $codePoint -le 122)) {
            [void]$asciiBuilder.Append(([string]$char).ToLowerInvariant())
            continue
        }

        if ($asciiBuilder.Length -gt 0) {
            $tokens.Add($asciiBuilder.ToString())
            [void]$asciiBuilder.Clear()
        }
    }

    if ($asciiBuilder.Length -gt 0) {
        $tokens.Add($asciiBuilder.ToString())
    }

    $hash = Get-StableShortHash -Text $Text -Length 8
    $base = if ($tokens.Count -gt 0) {
        (($tokens -join '-') -replace '-{2,}', '-').Trim('-')
    } else {
        $Fallback
    }

    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = $Fallback
    }

    $reserved = $hash.Length + 1
    $baseMaxLength = [Math]::Max(1, $MaxLength - $reserved)
    if ($base.Length -gt $baseMaxLength) {
        $base = $base.Substring(0, $baseMaxLength).Trim('-')
    }

    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = $Fallback.Substring(0, [Math]::Min($Fallback.Length, $baseMaxLength))
    }

    return "$base-$hash"
}

function Get-GzhrbOutputPath {
    param(
        [Parameter(Mandatory)][string]$DigestPath,
        [Parameter(Mandatory)][string]$GzhrbDir,
        [Parameter(Mandatory)][string]$TopicHint
    )

    $fileName = Split-Path -Leaf $DigestPath
    $topicSuffix = "-$(Get-SlugFromText -Text $TopicHint)"
    $match = [regex]::Match($fileName, '^ai-daily-digest-(\d{8}-\d{4})\.md$')
    if ($match.Success) {
        $timestampParts = $match.Groups[1].Value -split '-'
        $shortDate = Get-ShortDateStamp -DateStamp $timestampParts[0]
        return Join-Path $GzhrbDir "gzhrb-$shortDate-$($timestampParts[1])$topicSuffix.md"
    }

    $dateOnlyMatch = [regex]::Match($fileName, '^ai-daily-digest-(\d{8})\.md$')
    if (-not $dateOnlyMatch.Success) {
        throw "Cannot parse digest timestamp from: $fileName"
    }

    $digestItem = Get-Item -LiteralPath $DigestPath
    $timeSuffix = $digestItem.LastWriteTime.ToString('HHmm')
    $shortDate = Get-ShortDateStamp -DateStamp $dateOnlyMatch.Groups[1].Value
    return Join-Path $GzhrbDir "gzhrb-$shortDate-$timeSuffix$topicSuffix.md"
}

function Start-GzhrbWritingWorkspacePreparation {
    param(
        [string]$DigestPath,
        [string]$GzhrbDir,
        [string]$TopicTitle,
        [string]$TopicSource,
        [string]$TopicUrl,
        [string]$TopicSummary,
        [string]$TopicCategory,
        [string]$TopicAge,
        [string]$TopicScore
    )

    $projectDir = Get-ProjectDir

    if ([string]::IsNullOrWhiteSpace($DigestPath)) {
        throw 'DigestPath is required.'
    }
    if (-not (Test-Path -LiteralPath $DigestPath)) {
        throw "Digest file not found: $DigestPath"
    }
    if ([string]::IsNullOrWhiteSpace($TopicTitle)) {
        throw 'TopicTitle is required.'
    }

    if ([string]::IsNullOrWhiteSpace($GzhrbDir)) {
        $GzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    }

    $draftsDir = Join-Path $GzhrbDir 'drafts'
    $workitemsDir = Join-Path $GzhrbDir 'workitems'
    $illustrationsRoot = Join-Path $GzhrbDir 'illustrations'
    $approvalsRoot = Join-Path $GzhrbDir 'approvals'
    $provenanceRoot = Join-Path $GzhrbDir 'provenance'
    $articlesRoot = Join-Path $GzhrbDir 'articles'
    $publishUnitsRoot = Join-Path $GzhrbDir 'publish-units'

    New-Item -ItemType Directory -Force -Path $GzhrbDir, $draftsDir, $workitemsDir, $illustrationsRoot, $approvalsRoot, $provenanceRoot, $articlesRoot, $publishUnitsRoot | Out-Null

    $legacyOptimizedArticlePath = Get-GzhrbOutputPath -DigestPath $DigestPath -GzhrbDir $GzhrbDir -TopicHint $TopicTitle
    $articleId = [System.IO.Path]::GetFileNameWithoutExtension($legacyOptimizedArticlePath)
    $articleDir = Join-Path $articlesRoot $articleId
    $approvalDir = Join-Path $approvalsRoot $articleId
    $provenanceDir = Join-Path $provenanceRoot $articleId
    $publishUnitDir = Join-Path $publishUnitsRoot $articleId
    $optimizedArticlePath = Join-Path $articleDir 'article.md'
    $khazixDraftPath = Join-Path $draftsDir "$articleId-khazix.md"
    $workitemJsonPath = Join-Path $workitemsDir "$articleId.json"
    $workitemMarkdownPath = Join-Path $workitemsDir "$articleId.md"
    $illustrationDir = Join-Path $illustrationsRoot $articleId

    New-Item -ItemType Directory -Force -Path $articleDir, $approvalDir, $provenanceDir, $publishUnitDir, $illustrationDir | Out-Null

    if (-not (Test-Path -LiteralPath $khazixDraftPath)) {
        Write-Utf8TextFile -Path $khazixDraftPath -Content @"
# $TopicTitle

> khazix-writer 初稿占位文件
> 正式初稿请由外部 skill 写入这个文件，或按同等内容另存后再同步到这里。

"@
    }

    $manifest = [ordered]@{
        workflow = 'ai-yang-detective-content-pipeline'
        stage = 'awaiting_topic_approval'
        writing_state = [ordered]@{
            khazix = New-PendingWritingState
            wechat = New-PendingWritingState
        }
        execution_log = @()
        article_id = $articleId
        digest_path = $DigestPath
        topic = [ordered]@{
            title = $TopicTitle
            source = $TopicSource
            url = $TopicUrl
            summary = $TopicSummary
            category = $TopicCategory
            age = $TopicAge
            editorial_score = $TopicScore
        }
        paths = [ordered]@{
            khazix_draft = $khazixDraftPath
            optimized_article = $optimizedArticlePath
            article_dir = $articleDir
            approval_dir = $approvalDir
            provenance_dir = $provenanceDir
            illustration_dir = $illustrationDir
            publish_unit_dir = $publishUnitDir
        }
        next_steps = @(
            "1. 先人工确认选题，并写入 $approvalDir\\topic-selected.json",
            "2. 用 khazix-writer 围绕选题生成长文初稿，写入 $khazixDraftPath",
            "3. 用 wechat-article-writer 基于初稿生成优化稿，保存到 $optimizedArticlePath",
            "4. 插图与发布后半段完成后，把最终交付写入 $publishUnitDir"
        )
    }

    $manifestJson = $manifest | ConvertTo-Json -Depth 6
    Write-Utf8TextFile -Path $workitemJsonPath -Content $manifestJson

    $workitemMarkdownLines = @(
        '# AI杨侦探写作工作单',
        '',
        "- 文章 ID：``$articleId``",
        "- 日报：``$DigestPath``",
        "- 选题：``$TopicTitle``",
        "- 来源：``$TopicSource``",
        "- 时效：``$TopicAge``",
        "- 分类：``$TopicCategory``",
        "- 公众号选题分：``$TopicScore``",
        '',
        '## 题材摘要',
        '',
        $TopicSummary,
        '',
        '## 预定路径',
        '',
        "- ``khazix-writer`` 初稿：``$khazixDraftPath``",
        "- ``wechat-article-writer`` 优化稿：``$optimizedArticlePath``",
        "- 工作稿目录：``$articleDir``",
        "- approval 目录：``$approvalDir``",
        "- provenance 目录：``$provenanceDir``",
        "- 插图归档目录：``$illustrationDir``",
        "- 最终发布单元目录：``$publishUnitDir``",
        '',
        '## 正式顺序',
        '',
        '1. 先人工确认选题，通过后进入 `khazix-writer` 阶段',
        '2. 用 `khazix-writer` 产出公众号长文初稿',
        '3. 初稿人工确认通过后，再进入 `wechat-article-writer` 阶段',
        '4. 用 `wechat-article-writer` 把初稿改成发文态优化稿，并写入优化稿路径',
        '5. 优化稿人工确认通过后，再进入插图规划和后续发布链路',
        '',
        '## 当前状态',
        '',
        '- `awaiting_topic_approval`：等待人工确认选题',
        '- `awaiting_khazix_execution`：选题已确认，等待 `khazix-writer` 正式执行',
        '- `awaiting_khazix_approval`：`khazix-writer` 初稿已完成，等待人工确认',
        '- `awaiting_wechat_execution`：初稿已确认，等待 `wechat-article-writer` 正式执行',
        '- `awaiting_wechat_approval`：优化稿已完成，等待人工确认',
        '- `awaiting_illustration_execution`：优化稿已确认，等待插图规划与生成',
        '- `awaiting_illustration_approval`：插图已完成，等待人工确认',
        '- `ready_for_publish_unit`：可进入归档、回填、发布包装和最终发布单元生成',
        '',
        '当前工作单已创建，状态：`awaiting_topic_approval`'
    )
    $workitemMarkdown = $workitemMarkdownLines -join "`n"
    Write-Utf8TextFile -Path $workitemMarkdownPath -Content $workitemMarkdown

    Write-Host ""
    Write-Host "[OK] 已创建写作工作单 / Writing workspace prepared."
    Write-Host "文章 ID Article ID        : $articleId"
    Write-Host "工作单 JSON Workitem      : $workitemJsonPath"
    Write-Host "工作单 Markdown Brief     : $workitemMarkdownPath"
    Write-Host "khazix 初稿路径 Draft     : $khazixDraftPath"
    Write-Host "wechat 优化稿路径 Article : $optimizedArticlePath"
    Write-Host "插图目录 Illustrations    : $illustrationDir"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbWritingWorkspacePreparation `
        -DigestPath $DigestPath `
        -GzhrbDir $GzhrbDir `
        -TopicTitle $TopicTitle `
        -TopicSource $TopicSource `
        -TopicUrl $TopicUrl `
        -TopicSummary $TopicSummary `
        -TopicCategory $TopicCategory `
        -TopicAge $TopicAge `
        -TopicScore $TopicScore
}
