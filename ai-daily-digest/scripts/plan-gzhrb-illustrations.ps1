param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$IllustrationsRoot,
    [string]$OutputDir,
    [ValidateSet('auto', 'model-release', 'tool-tutorial', 'workflow-agent', 'trend-opinion', 'hands-on', 'technical-explainer')]
    [string]$VisualProfile = 'auto',
    [int]$MaxPlacements = 5
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

function Get-VisualProfileDefinition {
    param([Parameter(Mandatory)][string]$Name)

    $definitions = @{
        'model-release' = [pscustomobject]@{
            Name = 'model-release'
            Description = '模型或产品发布，先讲事实，再回到能力证据、真实任务和使用判断。'
            Rules = @(
                'Use product-entry, official-showroom, launch-stage, or brand-page imagery at most once for the whole article',
                'After the product fact image, shift to capability evidence, real-task validation, workflow, user scenarios, and personal judgment',
                'Do not turn the model name, logo, chip, or brand wall into the dominant advertising visual'
            )
            Roles = @('product fact', 'capability evidence', 'real-task validation', 'workflow in use', 'user scenarios', 'personal judgment')
        }
        'tool-tutorial' = [pscustomobject]@{
            Name = 'tool-tutorial'
            Description = '工具教程，突出操作、输入输出和可复现的结果。'
            Rules = @(
                'Show a practical action, input, setting, output, or troubleshooting moment in each image',
                'Use concise step labels and structured interface blocks only when they help the reader reproduce the action',
                'Avoid generic product promotion and do not repeat the same setup screen'
            )
            Roles = @('tool context', 'first action', 'input and setup', 'output check', 'common obstacle', 'repeatable result')
        }
        'workflow-agent' = [pscustomobject]@{
            Name = 'workflow-agent'
            Description = 'Agent 与工作流，突出任务交接、工具、权限和恢复。'
            Rules = @(
                'Show task handoff, tool use, permissions, failure handling, or result review through people and real work objects',
                'Use files, terminals, task queues, and result surfaces instead of factory pipelines or mechanical metaphors',
                'Keep each image focused on one work relationship or decision boundary'
            )
            Roles = @('task context', 'handoff', 'tool boundary', 'failure recovery', 'result review', 'operating habit')
        }
        'trend-opinion' = [pscustomobject]@{
            Name = 'trend-opinion'
            Description = '趋势与观点，突出人的处境、选择、成本和结果。'
            Rules = @(
                'Put human choices, tradeoffs, costs, pressure, opportunity, and outcomes ahead of product branding',
                'Use a concrete life or work moment rather than an abstract industry metaphor',
                'Keep brands and model names factual but visually secondary'
            )
            Roles = @('human context', 'pressure or change', 'tradeoff', 'real consequence', 'different people', 'personal action')
        }
        'hands-on' = [pscustomobject]@{
            Name = 'hands-on'
            Description = '个人实战与复盘，突出真实操作、踩坑和前后变化。'
            Rules = @(
                'Show a reproducible small task, practical setup, obstacle, fix, or outcome',
                'Use real working surfaces such as terminals, logs, files, settings, and results without generating dense fake text',
                'Make each image suggest a concrete next action the reader can try'
            )
            Roles = @('starting task', 'setup', 'obstacle', 'fix', 'before and after', 'repeatable takeaway')
        }
        'technical-explainer' = [pscustomobject]@{
            Name = 'technical-explainer'
            Description = '技术解释，突出输入、处理、输出和边界条件。'
            Rules = @(
                'Show documents, data, retrieval, model input, output, and boundary conditions through clean real-world objects and light structure',
                'Allow concise structural relationships but do not use factory lines, heavy module boards, or mechanical machine metaphors',
                'Keep technical labels factual, short, and tied to actual inputs or outputs'
            )
            Roles = @('problem input', 'key mechanism', 'data or document path', 'output quality', 'boundary condition', 'practical takeaway')
        }
    }

    if (-not $definitions.ContainsKey($Name)) {
        throw "Unsupported visual profile: $Name"
    }

    return $definitions[$Name]
}

function Resolve-VisualProfile {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [Parameter(Mandatory)][string]$RequestedProfile
    )

    if ($RequestedProfile -ne 'auto') {
        return [pscustomobject]@{ Name = $RequestedProfile; Source = 'explicit' }
    }

    $text = $Markdown.ToLowerInvariant()
    $hasReleaseSignal = $text -match '发布|上线|开放权重|权重开放|版本更新|正式推出|release'
    $hasModelReleaseSubject = $text -match '模型|model|参数|权重|上下文|推理|多模态'
    if ($hasReleaseSignal -and $hasModelReleaseSubject) {
        return [pscustomobject]@{ Name = 'model-release'; Source = 'auto' }
    }
    if ($text -match '安装|配置|怎么用|使用方法|教程|tutorial') {
        return [pscustomobject]@{ Name = 'tool-tutorial'; Source = 'auto' }
    }
    if ($text -match 'agent|工作流|权限|自动化|harness|coding agent') {
        return [pscustomobject]@{ Name = 'workflow-agent'; Source = 'auto' }
    }
    if ($text -match '部署|实战|踩坑|复盘|我怎么') {
        return [pscustomobject]@{ Name = 'hands-on'; Source = 'auto' }
    }
    if ($text -match 'rag|检索|pdf|文档解析|架构|数据') {
        return [pscustomobject]@{ Name = 'technical-explainer'; Source = 'auto' }
    }

    return [pscustomobject]@{ Name = 'trend-opinion'; Source = 'auto' }
}

function Get-LatestGzhrbPath {
    param([Parameter(Mandatory)][string]$GzhrbDir)

    $latest = Get-ChildItem -LiteralPath $GzhrbDir -Filter 'gzhrb-*.md' -File |
        Sort-Object `
            @{ Expression = { $_.LastWriteTime }; Descending = $true }, `
            @{ Expression = { $_.FullName }; Descending = $true } |
        Select-Object -First 1

    if (-not $latest) {
        throw "No GZHRB article found in: $GzhrbDir"
    }

    return $latest.FullName
}

function Get-MaxPlacementStemLength {
    return 28
}

function Get-ArticleIllustrationsDir {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$IllustrationsRoot
    )

    return Get-CompactOutputDir -ArticlePath $ArticlePath -IllustrationsRoot $IllustrationsRoot
}

function Get-PromptsDir {
    param([Parameter(Mandatory)][string]$OutputDir)

    return Join-Path $OutputDir 'prompts'
}

function New-StringFromCodePoints {
    param([int[]]$CodePoints)

    $builder = New-Object System.Text.StringBuilder
    foreach ($codePoint in $CodePoints) {
        [void]$builder.Append([char]$codePoint)
    }

    return $builder.ToString()
}

function Get-TitleOptionsMarker {
    return New-StringFromCodePoints @(0x6807, 0x9898, 0x5907, 0x9009)
}

function Get-IntroOptionsMarker {
    return New-StringFromCodePoints @(0x5F15, 0x5BFC, 0x8BED, 0x5907, 0x9009)
}

function Get-TopicTagsMarker {
    return New-StringFromCodePoints @(0x8BDD, 0x9898, 0x6807, 0x7B7E)
}

function Get-MarkdownHeadings {
    param([Parameter(Mandatory)]$Lines)

    $headings = @()

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = [string]$Lines[$i]
        if ($line -match '^(#{1,6})\s+(.+?)\s*$') {
            $headings += [pscustomobject]@{
                Index = $i
                Level = $Matches[1].Length
                Heading = ('{0} {1}' -f $Matches[1], $Matches[2])
                Text = $Matches[2]
            }
        }
    }

    return @($headings)
}

function Test-IsTitleOptionsHeadingText {
    param([Parameter(Mandatory)][string]$Text)

    $normalized = (($Text -replace '\s+', ' ').Trim()).ToLowerInvariant()
    $titleOptionsMarker = Get-TitleOptionsMarker

    if ($normalized.Contains($titleOptionsMarker)) {
        return $true
    }

    return $normalized.Contains('title options')
}

function Test-IsPackagingHeadingText {
    param([Parameter(Mandatory)][string]$Text)

    $normalized = (($Text -replace '\s+', ' ').Trim()).ToLowerInvariant()
    if (Test-IsTitleOptionsHeadingText -Text $Text) {
        return $true
    }

    if ($normalized.Contains((Get-IntroOptionsMarker))) {
        return $true
    }

    if ($normalized.Contains((Get-TopicTagsMarker))) {
        return $true
    }

    return $normalized.Contains('intro line') -or $normalized.Contains('topic tag')
}

function Get-TitleOptionsRanges {
    param(
        [Parameter(Mandatory)]$Lines,
        [Parameter(Mandatory)][object[]]$Headings
    )

    $ranges = @()

    for ($i = 0; $i -lt $Headings.Count; $i++) {
        $heading = $Headings[$i]
        if (-not (Test-IsPackagingHeadingText -Text $heading.Text)) {
            continue
        }

        $endIndex = $Lines.Count
        for ($j = $i + 1; $j -lt $Headings.Count; $j++) {
            if ($Headings[$j].Level -le $heading.Level) {
                $endIndex = $Headings[$j].Index
                break
            }
        }

        $ranges += [pscustomobject]@{
            Start = $heading.Index
            End = $endIndex
        }
    }

    return @($ranges)
}

function Test-LineInIgnoredRange {
    param(
        [int]$Index,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Ranges
    )

    foreach ($range in $Ranges) {
        if ($Index -ge $range.Start -and $Index -lt $range.End) {
            return $true
        }
    }

    return $false
}

function Test-SectionHasContent {
    param(
        [Parameter(Mandatory)]$Lines,
        [int]$StartIndex,
        [int]$EndIndex
    )

    if ($EndIndex -le ($StartIndex + 1)) {
        return $false
    }

    for ($i = $StartIndex + 1; $i -lt $EndIndex; $i++) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Lines[$i])) {
            return $true
        }
    }

    return $false
}

function Get-SectionEndIndex {
    param(
        [Parameter(Mandatory)][object]$Heading,
        [Parameter(Mandatory)][object[]]$Headings,
        [int]$LinesCount
    )

    foreach ($candidate in $Headings) {
        if ($candidate.Index -le $Heading.Index) {
            continue
        }

        if ($candidate.Level -le $Heading.Level) {
            return $candidate.Index
        }
    }

    return $LinesCount
}

function Get-EligibleArticleHeadings {
    param([Parameter(Mandatory)][string]$Markdown)

    $lines = $Markdown -split "`r?`n"
    $headings = @(Get-MarkdownHeadings -Lines $lines)
    $ignoredRanges = @(Get-TitleOptionsRanges -Lines $lines -Headings $headings)
    $headingCounts = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([System.StringComparer]::Ordinal)
    $eligible = @()

    foreach ($heading in $headings) {
        if ($heading.Level -notin @(2, 3)) {
            continue
        }

        if ($headingCounts.ContainsKey($heading.Heading)) {
            $headingCounts[$heading.Heading]++
        }
        else {
            $headingCounts[$heading.Heading] = 1
        }
    }

    foreach ($heading in $headings) {
        if ($heading.Level -notin @(2, 3)) {
            continue
        }

        if (Test-LineInIgnoredRange -Index $heading.Index -Ranges $ignoredRanges) {
            continue
        }

        if ($headingCounts[$heading.Heading] -gt 1) {
            continue
        }

        $sectionEndIndex = Get-SectionEndIndex -Heading $heading -Headings $headings -LinesCount $lines.Count
        if (-not (Test-SectionHasContent -Lines $lines -StartIndex $heading.Index -EndIndex $sectionEndIndex)) {
            continue
        }

        $sectionContext = Get-SectionContext -Lines $lines -StartIndex $heading.Index -EndIndex $sectionEndIndex
        $eligible += [pscustomobject]@{
            Heading = $heading.Heading
            Text = $heading.Text
            Level = $heading.Level
            SectionContext = $sectionContext
        }
    }

    return @($eligible)
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

function Get-SectionContext {
    param(
        [Parameter(Mandatory)]$Lines,
        [int]$StartIndex,
        [int]$EndIndex,
        [int]$MaxLength = 280
    )

    $sectionLines = @()

    for ($i = $StartIndex + 1; $i -lt $EndIndex; $i++) {
        $line = ([string]$Lines[$i]).Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        if ($line -match '^!\[' -or $line -match '^<img' -or $line -match '^```') {
            continue
        }

        $sectionLines += $line
    }

    $context = (($sectionLines -join ' ') -replace '\s+', ' ')
    $context = $context -replace '`', ''
    if ($context.Length -gt $MaxLength) {
        return $context.Substring(0, $MaxLength).TrimEnd() + '...'
    }

    return $context
}

function Get-HeadingSlug {
    param(
        [Parameter(Mandatory)][string]$HeadingText,
        [string]$Fallback = 'section',
        [int]$MaxLength = 0
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    $asciiBuilder = New-Object System.Text.StringBuilder

    foreach ($char in $HeadingText.ToCharArray()) {
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

    $hash = Get-StableShortHash -Text $HeadingText -Length 8
    $base = if ($tokens.Count -gt 0) {
        (($tokens -join '-') -replace '-{2,}', '-').Trim('-')
    } else {
        $Fallback
    }

    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = $Fallback
    }

    if ($MaxLength -le 0) {
        return "$base-$hash"
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

function Get-CompactArticleStem {
    param([Parameter(Mandatory)][string]$ArticleId)

    $match = [regex]::Match($ArticleId, '^(gzhrb-\d{8}-\d{4})(?:-(.+))?$')
    if (-not $match.Success) {
        return $ArticleId
    }

    $prefix = $match.Groups[1].Value
    $suffix = [string]$match.Groups[2].Value
    if ([string]::IsNullOrWhiteSpace($suffix)) {
        return $prefix
    }

    $tokens = @(
        ($suffix -split '-') |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $base = if ($tokens.Count -gt 0) { $tokens[0] } else { 'topic' }
    if ($base.Length -gt 10) {
        $base = $base.Substring(0, 10).Trim('-')
    }

    $hash = Get-StableShortHash -Text $suffix -Length 6
    return "$prefix-$base-$hash"
}

function Get-CompactOutputDir {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$IllustrationsRoot
    )

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $articleDir = Join-Path $IllustrationsRoot $articleId
    if (Test-Path -LiteralPath $articleDir) {
        return $articleDir
    }

    return Join-Path $IllustrationsRoot (Get-CompactArticleStem -ArticleId $articleId)
}

function Get-NarrativeRole {
    param(
        [Parameter(Mandatory)][string]$VisualProfile,
        [Parameter(Mandatory)][int]$Slot
    )

    $definition = Get-VisualProfileDefinition -Name $VisualProfile
    $index = [Math]::Min($Slot - 1, $definition.Roles.Count - 1)
    return $definition.Roles[$index]
}

function New-PlacementPlan {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$Markdown,
        [ValidateSet('model-release', 'tool-tutorial', 'workflow-agent', 'trend-opinion', 'hands-on', 'technical-explainer')]
        [string]$VisualProfile = 'trend-opinion',
        [int]$MaxPlacements = 5
    )

    if ($MaxPlacements -le 0) {
        throw "MaxPlacements must be greater than zero."
    }

    $eligibleHeadings = Get-EligibleArticleHeadings -Markdown $Markdown
    if ($eligibleHeadings.Count -eq 0) {
        throw "No eligible illustration headings found in article: $ArticlePath"
    }

    $selectedHeadings = @($eligibleHeadings | Select-Object -First $MaxPlacements)
    $placements = @()

    for ($i = 0; $i -lt $selectedHeadings.Count; $i++) {
        $slot = $i + 1
        $heading = $selectedHeadings[$i]
        $stemPrefix = '{0:d2}-' -f $slot
        $maxStemLength = Get-MaxPlacementStemLength
        $maxSlugLength = [Math]::Max(1, ($maxStemLength - $stemPrefix.Length))
        $slug = Get-HeadingSlug -HeadingText $heading.Text -MaxLength $maxSlugLength
        $stem = "$stemPrefix$slug"

        $placements += [pscustomobject]@{
            slot = $slot
            after_heading = $heading.Heading
            image = "$stem.png"
            alt = $heading.Text
            PromptFile = "prompts/$stem.md"
            TaskId = $stem
            HeadingText = $heading.Text
            SectionContext = $heading.SectionContext
            NarrativeRole = Get-NarrativeRole -VisualProfile $VisualProfile -Slot $slot
        }
    }

    return @($placements)
}

function ConvertTo-PlacementRecords {
    param([Parameter(Mandatory)][object[]]$Placements)

    $records = @()

    foreach ($placement in $Placements) {
        $records += [pscustomobject][ordered]@{
            slot = $placement.slot
            after_heading = $placement.after_heading
            image = $placement.image
            alt = $placement.alt
            narrative_role = $placement.NarrativeRole
        }
    }

    return @($records)
}

function Get-BatchTasks {
    param([Parameter(Mandatory)][object[]]$Placements)

    $tasks = @()

    foreach ($placement in $Placements) {
        $tasks += [pscustomobject][ordered]@{
            id = $placement.TaskId
            promptFiles = @($placement.PromptFile)
            image = $placement.image
            provider = 'google'
            model = 'gemini-3-pro-image-preview'
            ar = '16:9'
            quality = '2k'
        }
    }

    return @($tasks)
}

function Get-OutlineContent {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$VisualProfile,
        [Parameter(Mandatory)][string]$ProfileSource,
        [Parameter(Mandatory)][object[]]$Placements
    )

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $profile = Get-VisualProfileDefinition -Name $VisualProfile
    $lines = @(
        '# GZHRB Illustration Outline',
        '',
        'Style: ai-yang-detective-editorial',
        'Palette: #F6F1E8 / #27403A / #D8BFC5 / #A56A43',
        'Ratio: 16:9',
        'Quality: 2K',
        "VisualProfile: $VisualProfile",
        "ProfileSource: $ProfileSource",
        "ProfileDescription: $($profile.Description)",
        '',
        "ArticleId: $articleId",
        "ArticlePath: $ArticlePath",
        "OutputDir: $OutputDir",
        "Placements: $($Placements.Count)",
        ''
    )

    foreach ($placement in $Placements) {
        $lines += @(
            ('## Slot {0:d2}' -f $placement.slot),
            '',
            "After heading: $($placement.after_heading)",
            "Image: $($placement.image)",
            "Prompt: $($placement.PromptFile)",
            "Alt: $($placement.alt)",
            "Type: $(Get-IllustrationType -HeadingText $placement.after_heading)",
            "NarrativeRole: $($placement.NarrativeRole)",
            'Style: ai-yang-detective-editorial',
            'Palette: #F6F1E8 / #27403A / #D8BFC5 / #A56A43',
            ''
        )
    }

    return [string]::Join("`n", $lines)
}

function Get-VisualBriefContent {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$VisualProfile,
        [Parameter(Mandatory)][string]$ProfileSource,
        [Parameter(Mandatory)][object[]]$Placements
    )

    $profile = Get-VisualProfileDefinition -Name $VisualProfile
    return [pscustomobject][ordered]@{
        article_id = Get-ArticleIdFromPath -ArticlePath $ArticlePath
        profile = $VisualProfile
        profile_source = $ProfileSource
        profile_description = $profile.Description
        global_rules = @(
            'Warm editorial explainer graphics with premium print-like texture, clear structure, and a small number of light 3D objects',
            'Use only short verifiable labels and at most one concise title or conclusion; no long generated prose, fake citations, formulas, or dense fake UI',
            'Keep the account palette and mobile-width clarity; avoid blur, haze, vintage effects, machinery, and generic decoration'
        )
        profile_rules = @($profile.Rules)
        roles = @($Placements | ForEach-Object {
                [pscustomobject][ordered]@{
                    slot = $_.slot
                    heading = $_.after_heading
                    narrative_role = $_.NarrativeRole
                }
            })
    }
}

function Get-IllustrationType {
    param([Parameter(Mandatory)][string]$HeadingText)

    $text = $HeadingText.ToLowerInvariant()

    if ($text.Contains('从') -and $text.Contains('到')) {
        return 'comparison'
    }

    if ($text.Contains('震一下')) {
        return 'comparison'
    }

    if ($text.Contains('关系') -or $text.Contains('边界') -or $text.Contains('结构') -or
        $text.Contains('参数') -or $text.Contains('工作流') -or $text.Contains('普通人')) {
        return 'framework'
    }

    if ($text.Contains('对比') -or $text.Contains('区别') -or $text.Contains('还是') -or
        $text.Contains('选择') -or $text.Contains('不同')) {
        return 'comparison'
    }

    if ($text.Contains('开始') -or $text.Contains('流程') -or $text.Contains('重建')) {
        return 'flowchart'
    }

    return 'framework'
}

function Get-TypeTemplateLines {
    param([Parameter(Mandatory)][string]$Type)

    switch ($Type) {
        'framework' {
            return @(
                '- Build a layered editorial framework graphic with one central structure and surrounding modules or grouped sections',
                '- Use cards, containers, zones, labels, arrows, or light 3D props when they make the relationship easier to scan',
                '- Show hierarchy, boundaries, and one clear conclusion without overcrowding the canvas',
                '- Use one central structure with surrounding modules, zones, or stacked sections',
                '- A concise title or short conclusion is allowed when it clarifies the framework; do not use a subtitle or paragraph',
                '- Keep the composition stable, balanced, and easy to scan at mobile width'
            )
        }
        'comparison' {
            return @(
                '- Build a clear editorial comparison with two visually distinct sides, containers, or columns',
                '- Use concise contrast labels and no more than three facts on each side',
                '- Let color, spacing, and object grouping make the difference obvious within one glance',
                '- A concise title or short conclusion is allowed when it clarifies the comparison',
                '- Keep the comparison focused on one decision and use balance only when it suits the content'
            )
        }
        'flowchart' {
            return @(
                '- Build an editorial process graphic with three to five ordered stages',
                '- Use a clear directional path, concise step labels, and simple arrows or connectors',
                '- Show start, transition, and outcome without adding unnecessary branches',
                '- A concise title or short conclusion is allowed when it names the process or outcome',
                '- Preserve whitespace and make every stage readable at mobile width'
            )
        }
        'scene' {
            return @(
                '- Build one concise light 3D object scene that supports a concrete conclusion or key object',
                '- Keep the environment abstract and restrained; the explanatory structure remains primary',
                '- Use object-bound labels and a concise title only when they improve understanding',
                '- Do not use people as the default focal point',
                '- Make the image memorable without turning it into a poster or a cinematic scene'
            )
        }
        default {
            return @(
                '- Prefer a structured editorial framework graphic',
                '- Keep the composition calm, modular, and explanation-first'
            )
        }
    }
}

function Get-TypeFallbackLines {
    param([Parameter(Mandatory)][string]$Type)

    switch ($Type) {
        'comparison' {
            return @(
                '- If the contrast is unclear, fall back to a two-column editorial comparison',
                '- Do not turn this into a flowchart unless the heading clearly describes a sequence'
            )
        }
        'flowchart' {
            return @(
                '- If the sequence is unclear, fall back to a three-stage framework graphic',
                '- Direction must remain obvious; do not turn this into a dense static board'
            )
        }
        'scene' {
            return @(
                '- If the concept is ambiguous, prefer a structured framework graphic over a mood-based scene',
                '- Preserve three to six readable labels when the section contains concrete facts, capabilities, or decisions'
            )
        }
        default {
            return @(
                '- If the concept is ambiguous, prefer a structured editorial framework graphic',
                '- Keep the image clear, calm, and not over-designed'
            )
        }
    }
}

function New-IllustrationPromptContent {
    param([Parameter(Mandatory)][object]$Context)

    $articleId = Get-ArticleIdFromPath -ArticlePath $Context.ArticlePath
    $profile = Get-VisualProfileDefinition -Name $Context.VisualProfile
    $placement = $Context.Placement
    $type = Get-IllustrationType -HeadingText $placement.after_heading
    $typeTemplateLines = Get-TypeTemplateLines -Type $type
    $typeFallbackLines = Get-TypeFallbackLines -Type $type
    $profileRuleLines = @($profile.Rules | ForEach-Object { "- $_" })
    $lines = @(
        '---',
        "illustration_id: $('{0:d2}' -f $placement.slot)",
        "type: $type",
        'style: ai-yang-detective-editorial',
        'palette: ai-yang-detective-default',
        '---',
        '',
        "# $($placement.TaskId)",
        '',
        "Article: $articleId",
        "After heading: $($placement.after_heading)",
        "Target image: $($placement.image)",
        "Alt text: $($placement.alt)",
        "Visual profile: $($Context.VisualProfile)",
        "Narrative role: $($placement.NarrativeRole)",
        '',
        'SECTION CONTEXT:',
        $placement.SectionContext,
        '',
        'Translate the section context into one concise editorial explainer. Do not illustrate every sentence or create a literal text summary.',
        '',
        'Create a premium editorial explainer illustration for a WeChat article.',
        'This is not a poster, not cinematic concept art, and not generic AI tech art.',
        'The image must help readers understand a structure, comparison, mechanism, or conclusion.',
        'This must follow AI杨侦探 default illustration style, not generic AI tech art.',
        'Honor the visual profile and narrative role below. They are article-specific requirements, not optional decoration.',
        '',
        'ARTICLE PROFILE:',
        "- $($profile.Description)",
        ($profileRuleLines -join "`n"),
        '',
        'STYLE DIRECTION:',
        '- Light editorial explainer style with clean deep-green linework, sharp edges, and restrained light 3D object depth',
         '- Choose the visual form from the section: framework, comparison, process, person, real scene, data relationship, focused object, or conclusion; use light 3D objects only when they help explain the subject',
        '- Premium, calm, structured, intelligent, restrained, low-AI-look, warm, magazine-quality',
        '- Warm cream background, clear modular layout, controlled category color, strong editorial clarity, and practical information density',
        '- Feels like an editor-designed magazine explainer graphic, not a flashy AI poster, generic dashboard, or software onboarding screen',
        '',
        'CLARITY REQUIREMENTS:',
        '- Prioritize clean, high-legibility shapes, sharp rendering, and realistic spatial separation over decorative texture',
        '- Use medium-weight consistent outlines, high edge separation, and solid fills with clear contrast against the background',
        '- Every core object and label must remain recognizable at mobile article width, not only when zoomed in',
        '- Keep the focal object, information-bearing props, and all labels crisp; use clean lighting instead of texture or haze to create depth',
        '- Avoid tiny icons, thin faint connectors, synthetic canvas grain, distressed texture, blurred edges, and low-contrast beige-on-beige details; retain subtle premium print texture without making the background dirty',
        '- Keep the primary subject visually sharp; do not use soft focus, haze, or depth-of-field blur',
        '',
        'INFORMATION DENSITY:',
         '- Keep the image informative rather than minimal, but use only the supporting visual cues needed to explain the point',
         '- Supporting cues may be concise cards, labels, modules, arrows, people, objects, or scenes when they explain the point; do not turn every fact into an equal-size card',
         '- Use only the short Chinese labels needed for facts, states, inputs, outputs, capabilities, or decisions',
        '- Keep all information organized around the same central idea so clarity does not turn into clutter',
        '- Give this image a distinct explanatory role from other article images; do not repeat the same framework or comparison composition',
        "- This image must visibly serve the narrative role: $($placement.NarrativeRole). Do not turn another role into a product-fact or promotional scene unless the selected profile explicitly calls for it",
        '',
        'PALETTE:',
        '- Background paper: #F6F1E8',
        '- Deep structure / outline: #27403A',
        '- Soft accent: #D8BFC5',
        '- Small copper highlight: #A56A43',
        '- Text / line neutral: #2B2B2B',
        'Color values are rendering guidance only. Do not show hex codes in the image.',
        '',
        'COLOR ROLE SYSTEM:',
        '- Keep cream and deep green as the visual base. Give each important category, route, or outcome a semantic accent rather than tinting every object the same beige-pink.',
        '- Choose only one or two secondary accent families that match the section: muted blue #6E9CCF for search, information, data, or connection; sage #779B86 for stable tools, workflow, or completion; amber #D6A447 for action, decision, or warning; coral #D98578 for creation, people, or contrast.',
        '- Use the selected accents consistently on category tabs, key task props, small icons, or one highlighted path. Preserve deep green for structure and text. Do not use all accent families in one image.',
        '- Accent colors must clarify meaning at mobile size, not become decorative gradients or a rainbow background.',
        '',
        'BACKGROUND TREATMENT:',
        '- Use a warm cream editorial canvas with subtle layered light and premium print-like texture; avoid empty pure-white space, strong visible grain, or distressed texture',
        '- Use powder-pink and copper-tan blocks as meaningful areas of emphasis, not as faint decorative washes; preserve a clear deep-green to copper contrast',
        '- A light tabletop, device base, corner paper, notebook edge, or abstract editorial plane is allowed when it gives objects physical grounding and prevents an empty background',
        '- Keep background detail below the information hierarchy; do not create a room, showroom, or lifestyle scene by default',
        '- Do not use blur, haze, scratches, faded vintage color, rust, exposed pipes, retro machinery, or decorative clutter',
        '',
        'COMPOSITION:',
        '- Keep one clear core concept tied to the section and show it through an explicit diagram, comparison, process, or conclusion structure',
        '- Use purposeful whitespace, one obvious focal point, and a stable reading order',
        '- Use a title, central structure, surrounding modules, or a bottom conclusion only when the selected image type and section content call for it',
        '- Make the focal point obvious within one second',
        '- Prefer a composition that matches the section: a centered framework, balanced comparison, ordered flow, or a focused object scene',
        '- Use cards, arrows, labels, zones, and framework modules deliberately; keep the structure balanced and avoid generic dashboards or SaaS onboarding screens',
        '- Use light 3D devices, cards, containers, screens, or symbolic objects only when they improve memory and interpretation',
         '- A concise title, optional short subtitle, or one short conclusion is allowed when it materially improves comprehension. No long paragraph or footer caption',
        ''
    )

    $lines += 'TYPE TEMPLATE:'
    $lines += $typeTemplateLines
    $lines += ''
    $lines += @(
        'OBJECT GUIDANCE:',
         '- If props are needed, choose believable elements that match the article: people, documents, tools, devices, data cards, paths, or real task objects. Computers, desks, and workbenches are optional, not defaults',
        '- Treat icons as compact semantic miniatures with a recognizable action, material, and depth. Do not use flat generic pictograms, unrelated decorative symbols, or a collection of sticker-like icons.',
        '- Keep objects proportionate, clean, and naturally lit; labels should be integrated into screens, documents, devices, or task surfaces rather than floating signboards',
        '- Avoid glossy ecommerce-render look, heavy sci-fi machinery, industrial pipes, conveyor belts, generators, or retro-factory props',
        '',
        'AVOID:',
        '- Dark blue backgrounds',
        '- Purple cyberpunk glow',
        '- Neon gradients',
        '- Floating futuristic UI panels',
        '- Busy collage layouts',
        '- Watercolor washes, hand-painted scenery, distant mountains, city skylines, clouds, birds, or storybook landscapes',
        '- Canvas grain, faded sepia wash, distressed metal, rusty edges, vintage machinery, exposed pipes, or conveyor-belt AI devices',
        '- Generic dashboards, slide templates, SaaS onboarding screens, no-order card walls, repetitive three-column boxes with no hierarchy, checklists, or dense small-text panels',
         '- More than one title, a long subtitle, a footer paragraph, or an article paragraph',
        '- Large generated Chinese prose, paper citations, complex formulas, fake product UI copy, or unreadable dense screen text',
        '- Floating label boards, giant brand walls, launch-stage displays, or product-advertising composition unless the section requires a verified product fact',
        '- Fake future city scenes',
        '- Complex mechanical robots',
        '- Realistic human faces',
        '- Generic potted plants, coffee cups, bookshelves, desk lamps, or decorative desk clutter',
        '- Photorealistic, painterly, sepia-only, moody brown monochrome, flat sticker icons, or low-detail cartoon rendering',
        '- Poster-like cinematic drama',
        '- Watermarks, logos, or screenshots',
        '',
        'TEXT:',
        '- Use one concise Chinese title when it materially improves comprehension; place it top-center for symmetric frameworks or align it with the core object when the composition is asymmetric; keep it under 18 Chinese characters or 24 mixed characters',
         '- Use only the short Chinese labels needed for modules, facts, states, inputs, outputs, capabilities, or decisions',
        '- Keep each label to two to ten Chinese characters; one optional model-name or key-number label may be longer',
        '- Make title and labels high-contrast and large enough for mobile reading',
        '- Labels may appear in cards, object tags, small zones, process stages, or comparison columns',
        '- One optional conclusion zone may contain a short factual judgement under 16 Chinese characters',
        '- Do not place a paragraph, fake citation, long slogan, or unreadable dense copy inside the image',
        ''
    )

    $lines += 'FAILSAFE:'
    $lines += $typeFallbackLines
    $lines += ''
    $lines += @(
        'OUTPUT:',
        '- 16:9',
        '- 2K quality',
        '- suitable for WeChat article inline illustration'
    )

    return [string]::Join("`n", $lines)
}

function Write-IllustrationPlanFiles {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$VisualProfile,
        [Parameter(Mandatory)][string]$ProfileSource,
        [Parameter(Mandatory)][object[]]$Placements
    )

    $promptsDir = Get-PromptsDir -OutputDir $OutputDir
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $promptsDir | Out-Null

    $placementPath = Join-Path $OutputDir 'placement.json'
    $outlinePath = Join-Path $OutputDir 'outline.md'
    $batchPath = Join-Path $OutputDir 'batch.json'
    $visualBriefPath = Join-Path $OutputDir 'visual-brief.json'

    $placementJson = ConvertTo-Json -InputObject (ConvertTo-PlacementRecords -Placements $Placements) -Depth 5
    $batchJson = ConvertTo-Json -InputObject ([pscustomobject][ordered]@{
            jobs = 2
            tasks = @(Get-BatchTasks -Placements $Placements)
        }) -Depth 5

    Write-Utf8TextFile -Path $placementPath -Content $placementJson
    Write-Utf8TextFile -Path $outlinePath -Content (Get-OutlineContent -ArticlePath $ArticlePath -OutputDir $OutputDir -VisualProfile $VisualProfile -ProfileSource $ProfileSource -Placements $Placements)
    Write-Utf8TextFile -Path $batchPath -Content $batchJson
    Write-Utf8TextFile -Path $visualBriefPath -Content (ConvertTo-Json -InputObject (Get-VisualBriefContent -ArticlePath $ArticlePath -VisualProfile $VisualProfile -ProfileSource $ProfileSource -Placements $Placements) -Depth 6)

    foreach ($placement in $Placements) {
        $promptPath = Join-Path $OutputDir $placement.PromptFile
        $promptContext = [pscustomobject]@{
            ArticlePath = $ArticlePath
            VisualProfile = $VisualProfile
            Placement = $placement
        }
        Write-Utf8TextFile -Path $promptPath -Content (New-IllustrationPromptContent -Context $promptContext)
    }
}

function Start-GzhrbIllustrationPlan {
    param(
        [string]$ArticlePath,
        [string]$GzhrbDir,
        [string]$IllustrationsRoot,
        [string]$OutputDir,
        [ValidateSet('auto', 'model-release', 'tool-tutorial', 'workflow-agent', 'trend-opinion', 'hands-on', 'technical-explainer')]
        [string]$VisualProfile = 'auto',
        [int]$MaxPlacements = 5
    )

    $projectDir = Get-ProjectDir

    if ([string]::IsNullOrWhiteSpace($GzhrbDir)) {
        $GzhrbDir = Join-Path $projectDir 'reports\gzhrb'
    }

    if ([string]::IsNullOrWhiteSpace($IllustrationsRoot)) {
        $IllustrationsRoot = Join-Path $GzhrbDir 'illustrations'
    }

    if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
        $ArticlePath = Get-LatestGzhrbPath -GzhrbDir $GzhrbDir
    }

    if (-not (Test-Path -LiteralPath $ArticlePath)) {
        throw "Article not found: $ArticlePath"
    }

    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = Get-ArticleIllustrationsDir -ArticlePath $ArticlePath -IllustrationsRoot $IllustrationsRoot
    }

    $markdown = Read-Utf8TextFile -Path $ArticlePath
    $profileResolution = Resolve-VisualProfile -Markdown $markdown -RequestedProfile $VisualProfile
    $placements = New-PlacementPlan -ArticlePath $ArticlePath -Markdown $markdown -VisualProfile $profileResolution.Name -MaxPlacements $MaxPlacements
    Write-IllustrationPlanFiles -ArticlePath $ArticlePath -OutputDir $OutputDir -VisualProfile $profileResolution.Name -ProfileSource $profileResolution.Source -Placements $placements

    Write-Host '[OK] GZHRB illustration plan created.'
    Write-Host "Article       : $ArticlePath"
    Write-Host "Output dir    : $OutputDir"
    Write-Host "Profile       : $($profileResolution.Name) ($($profileResolution.Source))"
    Write-Host "Placements    : $($placements.Count)"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbIllustrationPlan `
        -ArticlePath $ArticlePath `
        -GzhrbDir $GzhrbDir `
        -IllustrationsRoot $IllustrationsRoot `
        -OutputDir $OutputDir `
        -VisualProfile $VisualProfile `
        -MaxPlacements $MaxPlacements
}
