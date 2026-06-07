param(
    [switch]$NoPause,
    [switch]$GenerateGzhrb,
    [switch]$OrganizeGzhrbIllustrations
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$digestTs = Join-Path $projectDir 'scripts\digest.ts'
$prepareGzhrbWritingWorkspacePs1 = Join-Path $projectDir 'scripts\prepare-gzhrb-writing-workspace.ps1'
$selectGzhrbTopicTs = Join-Path $projectDir 'scripts\select-gzhrb-topic.ts'
$organizeGzhrbIllustrationsPs1 = Join-Path $projectDir 'scripts\organize-gzhrb-illustrations.ps1'
$outputDir = Join-Path $projectDir 'reports\output'
$healthDir = Join-Path $projectDir 'reports\health'
$topicDir = Join-Path $projectDir 'reports\gzhrb\topics'

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Allowed,
        [string]$Default
    )

    while ($true) {
        $value = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $Default
        }
        if ($Allowed -contains $value) {
            return $value
        }
        Write-Host "输入无效 / Invalid input. Allowed: $($Allowed -join ', ')"
    }
}

function Resolve-OpenAIWireApi {
    param(
        [string]$WireApi,
        [string]$ApiBase
    )

    if (-not [string]::IsNullOrWhiteSpace($WireApi)) {
        return $WireApi
    }

    $normalizedBase = $ApiBase
    if (-not [string]::IsNullOrWhiteSpace($normalizedBase)) {
        $normalizedBase = $normalizedBase.Trim().ToLowerInvariant()
        if ($normalizedBase.Contains('rawchat.cn/codex')) {
            return 'responses'
        }
    }

    return 'chat'
}

function Read-TopicChoice {
    param([int]$MaxChoice)

    while ($true) {
        $value = Read-Host "请选择候选题（1-$MaxChoice），输入 N 取消 / Choose 1-$MaxChoice, or N to cancel"
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        if ($value -in @('N', 'n')) {
            return 'cancel'
        }

        $parsed = 0
        if ([int]::TryParse($value, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $MaxChoice) {
            return $parsed
        }

        Write-Host "输入无效 / Invalid input. Allowed: 1-$MaxChoice, N"
    }
}

function Get-TopicArtifactPaths {
    param([Parameter(Mandatory)][string]$DigestPath)

    $digestName = [System.IO.Path]::GetFileNameWithoutExtension($DigestPath)
    $suffix = $digestName -replace '^ai-daily-digest-', ''
    return [pscustomobject]@{
        JsonPath = Join-Path $topicDir "gzhrb-topics-$suffix.json"
        MarkdownPath = Join-Path $topicDir "gzhrb-topics-$suffix.md"
    }
}

function Select-GzhrbTopic {
    param([Parameter(Mandatory)][string]$DigestPath)

    if (-not (Test-Path -LiteralPath $selectGzhrbTopicTs)) {
        throw "未找到候选题脚本 / Topic shortlist script not found: $selectGzhrbTopicTs"
    }

    New-Item -ItemType Directory -Force -Path $topicDir | Out-Null
    $artifacts = Get-TopicArtifactPaths -DigestPath $DigestPath

    Push-Location $projectDir
    try {
        $npxCmd = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
        if (-not $npxCmd) {
            $npxCmd = (Get-Command npx -ErrorAction Stop).Source
        }

        $jsonText = & $npxCmd -y bun $selectGzhrbTopicTs --digest $DigestPath --limit 5 --json --output-json $artifacts.JsonPath --output-md $artifacts.MarkdownPath
        if ($LASTEXITCODE -ne 0) {
            throw "候选题提取失败 / Topic shortlist generation failed. Exit code: $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }

    $payload = Get-Content -Raw -LiteralPath $artifacts.JsonPath | ConvertFrom-Json
    if (-not $payload -or -not $payload.candidates -or $payload.candidates.Count -eq 0) {
        throw "候选题为空 / No topic candidates generated from digest: $DigestPath"
    }

    Write-Host ""
    Write-Host "[选题关口] 公众号候选题 / Topic Gate"
    Write-Host "候选清单已保存 / Saved shortlist:"
    Write-Host "  $($artifacts.MarkdownPath)"
    Write-Host ""

    for ($i = 0; $i -lt $payload.candidates.Count; $i++) {
        $candidate = $payload.candidates[$i]
        Write-Host ("{0}) [{1}] {2}" -f ($i + 1), $candidate.editorialScore, $candidate.title)
        Write-Host ("   来源: {0} | {1} | {2}" -f $candidate.source, $candidate.age, $candidate.category)
        if (-not [string]::IsNullOrWhiteSpace($candidate.summary)) {
            Write-Host ("   摘要: {0}" -f $candidate.summary)
        }
        if ($candidate.editorialReasons -and $candidate.editorialReasons.Count -gt 0) {
            Write-Host ("   入选原因: {0}" -f (($candidate.editorialReasons -join '；')))
        }
        Write-Host ""
    }

    $choice = Read-TopicChoice -MaxChoice $payload.candidates.Count
    if ($choice -eq 'cancel') {
        Write-Host "已取消进入正式写作阶段 / Cancelled before the formal writing stage."
        return $null
    }

    return $payload.candidates[$choice - 1]
}

if (-not (Test-Path -LiteralPath $digestTs)) {
    throw "未找到项目脚本 / Project script not found: $digestTs"
}

New-Item -ItemType Directory -Force -Path $outputDir, $healthDir | Out-Null

Write-Host ""
Write-Host "=========================================="
Write-Host "  AI杨侦探工作流启动器 / AI Content Workflow Launcher"
Write-Host "=========================================="
Write-Host ""

Write-Host "[1/7] 选择时间范围 / Select time range:"
Write-Host "  1) 24 小时 / 24 hours"
Write-Host "  2) 48 小时（推荐） / 48 hours (recommended)"
Write-Host "  3) 72 小时 / 72 hours"
Write-Host "  4) 7 天（168 小时） / 7 days (168 hours)"
$hoursChoice = Read-Choice "请输入 1-4 / Choose 1-4" @('1','2','3','4') '2'
$hours = @{ '1' = 24; '2' = 48; '3' = 72; '4' = 168 }[$hoursChoice]
Write-Host "已选择 / Selected: $hours hours"
Write-Host ""

Write-Host "[2/7] 选择文章数量 / Select article count:"
Write-Host "  1) 10 篇 / 10"
Write-Host "  2) 15 篇（推荐） / 15 (recommended)"
Write-Host "  3) 20 篇 / 20"
$topChoice = Read-Choice "请输入 1-3 / Choose 1-3" @('1','2','3') '2'
$topN = @{ '1' = 10; '2' = 15; '3' = 20 }[$topChoice]
Write-Host "已选择 / Selected: $topN"
Write-Host ""

Write-Host "[3/7] 选择语言 / Select language:"
Write-Host "  1) 中文 / Chinese (zh)"
Write-Host "  2) 英文 / English (en)"
$langChoice = Read-Choice "请输入 1-2 / Choose 1-2" @('1','2') '1'
$lang = if ($langChoice -eq '2') { 'en' } else { 'zh' }
Write-Host "已选择 / Selected: $lang"
Write-Host ""

Write-Host "[4/7] 是否包含 WaytoAGI 最新文章 / Include WaytoAGI latest posts:"
Write-Host "  1) 不包含（默认） / Disable (0, default)"
Write-Host "  2) 5 篇 / 5 posts"
Write-Host "  3) 10 篇 / 10 posts"
$wayChoice = Read-Choice "请输入 1-3 / Choose 1-3" @('1','2','3') '1'
$waytoagiLimit = @{ '1' = 0; '2' = 5; '3' = 10 }[$wayChoice]
Write-Host "已选择 WaytoAGI 数量 / Selected WaytoAGI limit: $waytoagiLimit"
Write-Host ""

Write-Host "[5/7] 选择 Gemini 模型 / Select Gemini model:"
Write-Host "  1) gemini-3.1-pro-preview (默认 / 推荐 / 高质量 | default / recommended / high quality)"
Write-Host "  2) gemini-3-flash-preview (省钱 / 更快 | budget / faster)"
Write-Host "  3) 自定义模型名 / Custom model name"
$geminiChoice = Read-Choice "请输入 1-3 / Choose 1-3" @('1','2','3') '1'
$geminiModel = switch ($geminiChoice) {
    '2' { 'gemini-3-flash-preview' }
    '3' { Read-Host "请输入自定义 Gemini 模型名 / Enter custom Gemini model name" }
    default { 'gemini-3.1-pro-preview' }
}
if ([string]::IsNullOrWhiteSpace($geminiModel)) { $geminiModel = 'gemini-3.1-pro-preview' }
Write-Host "已选择 Gemini 模型 / Selected Gemini model: $geminiModel"
Write-Host ""

Write-Host "[6/7] 选择 OpenAI 兜底模型 / Select OpenAI fallback model:"
Write-Host "  1) gpt-5.4 (默认 / default)"
Write-Host "  2) 使用环境变量中的 OPENAI_MODEL / Use current OPENAI_MODEL from environment"
Write-Host "  3) gpt-5.3-codex"
Write-Host "  4) 自定义模型名 / Custom model name"
$openaiChoice = Read-Choice "请输入 1-4 / Choose 1-4" @('1','2','3','4') '1'
$openaiModelOverride = switch ($openaiChoice) {
    '2' { '' }
    '3' { 'gpt-5.3-codex' }
    '4' { Read-Host "请输入自定义 OpenAI 模型名 / Enter custom OpenAI model name" }
    default { 'gpt-5.4' }
}
$openaiLabel = if ([string]::IsNullOrWhiteSpace($openaiModelOverride)) { '(env OPENAI_MODEL)' } else { $openaiModelOverride }
$openaiWireApi = Resolve-OpenAIWireApi -WireApi $env:OPENAI_WIRE_API -ApiBase $env:OPENAI_API_BASE
$gzhrbMode = if ([string]::IsNullOrWhiteSpace($env:GZHRB_MODE)) { 'ai-observation' } else { $env:GZHRB_MODE }
$gzhrbModeLabel = switch ($gzhrbMode) {
    'tool-guide' { 'tool-guide（工具讲解 / 配置说明型）' }
    'troubleshooting' { 'troubleshooting（故障排查 / 技术破案型）' }
    default { 'ai-observation（AI新闻观察 / 趋势判断型）' }
}
Write-Host "已选择 OpenAI 兜底模型 / Selected OpenAI fallback model: $openaiLabel"
Write-Host ""

Write-Host "[7/7] 确认配置 / Confirm:"
Write-Host "  时间范围 Hours         : $hours"
Write-Host "  文章数量 Top N         : $topN"
Write-Host "  语言 Language          : $lang"
Write-Host "  WaytoAGI 最新文章      : $waytoagiLimit"
Write-Host "  Gemini 模型            : $geminiModel"
Write-Host "  OpenAI 兜底模型        : $openaiLabel"
Write-Host "  OpenAI 协议类型        : $openaiWireApi"
Write-Host "  公众号转稿模式         : $gzhrbModeLabel"
Write-Host "  项目目录 Project       : $projectDir"
Write-Host "  输出目录 Output        : $outputDir"
Write-Host ""
$confirm = Read-Choice "是否开始执行？ / Start now? (Y/N)" @('Y','y','N','n') 'Y'
if ($confirm -in @('N','n')) {
    Write-Host "已取消 / Cancelled."
    exit 0
}

if (-not $env:GEMINI_API_KEY -and -not $env:OPENAI_API_KEY) {
    throw "缺少 API Key，请先设置 GEMINI_API_KEY 和/或 OPENAI_API_KEY 到用户环境变量。"
}

$ts = Get-Date -Format 'yyyyMMdd-HHmm'
$outputFile = Join-Path $outputDir "ai-daily-digest-$ts.md"
$healthLogFile = Join-Path $healthDir "run-$ts.json"

Write-Host ""
Write-Host "正在生成日报，请稍候... / Generating digest, please wait..."

$env:GEMINI_MODEL = $geminiModel
if (-not [string]::IsNullOrWhiteSpace($openaiModelOverride)) {
    $env:OPENAI_MODEL = $openaiModelOverride
}

Push-Location $projectDir
try {
    $npxCmd = (Get-Command npx.cmd -ErrorAction SilentlyContinue).Source
    if (-not $npxCmd) {
        $npxCmd = (Get-Command npx -ErrorAction Stop).Source
    }

    & $npxCmd -y bun scripts/digest.ts --hours $hours --top-n $topN --lang $lang --waytoagi-limit $waytoagiLimit --output $outputFile --health-log $healthLogFile
    if ($LASTEXITCODE -ne 0) {
        throw "生成失败 / Generation failed. Exit code: $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if ($GenerateGzhrb) {
    if (-not (Test-Path -LiteralPath $prepareGzhrbWritingWorkspacePs1)) {
        throw "未找到写作工作单脚本 / Writing workspace script not found: $prepareGzhrbWritingWorkspacePs1"
    }

    $selectedTopic = Select-GzhrbTopic -DigestPath $outputFile
    if (-not $selectedTopic) {
        Write-SuccessSummary -OutputFile $outputFile -HealthLogFile $healthLogFile -OutputDir $outputDir
        exit 0
    }

    Write-Host ""
    Write-Host "正在准备双 skill 写作工作单，请稍候... / Preparing dual-skill writing workspace, please wait..."
    Write-Host ("已确认题材 / Confirmed topic: {0}" -f $selectedTopic.title)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $prepareGzhrbWritingWorkspacePs1 `
        -DigestPath $outputFile `
        -TopicTitle $selectedTopic.title `
        -TopicSource $selectedTopic.source `
        -TopicUrl $selectedTopic.url `
        -TopicSummary $selectedTopic.summary `
        -TopicCategory $selectedTopic.category `
        -TopicAge $selectedTopic.age `
        -TopicScore $selectedTopic.editorialScore
    if ($LASTEXITCODE -ne 0) {
        throw "写作工作单准备失败 / Writing workspace preparation failed. Exit code: $LASTEXITCODE"
    }

    if ($OrganizeGzhrbIllustrations) {
        if (-not (Test-Path -LiteralPath $organizeGzhrbIllustrationsPs1)) {
            throw "未找到插图归档脚本 / Illustration organizer script not found: $organizeGzhrbIllustrationsPs1"
        }

        Write-Host ""
        Write-Host "正在整理公众号插图目录，请稍候... / Organizing article illustrations, please wait..."
        & powershell -NoProfile -ExecutionPolicy Bypass -File $organizeGzhrbIllustrationsPs1
        if ($LASTEXITCODE -ne 0) {
            throw "公众号插图归档失败 / Article illustration organize failed. Exit code: $LASTEXITCODE"
        }
    }

    Write-Host ""
    Write-Host "[STOP] 正式流程现在停在写作关口。"
    Write-Host "[STOP] Next: 先用 khazix-writer 产出初稿，再用 wechat-article-writer 产出优化稿。"
    Write-Host "[STOP] 优化稿落盘后，再运行插图和发布后半程。"
}

function Write-SuccessSummary {
    param(
        [Parameter(Mandatory)][string]$OutputFile,
        [Parameter(Mandatory)][string]$HealthLogFile,
        [Parameter(Mandatory)][string]$OutputDir
    )

    Write-Host ""
    Write-Host "[OK] 已完成 / Done."
    Write-Host "输出文件 Output file : $OutputFile"
    Write-Host "健康日志 Health log : $HealthLogFile"
    Write-Host "输出目录 Output dir : $OutputDir"
}

Write-SuccessSummary -OutputFile $outputFile -HealthLogFile $healthLogFile -OutputDir $outputDir

if (-not $NoPause) {
    Read-Host "按回车键关闭 / Press Enter to exit" | Out-Null
}
