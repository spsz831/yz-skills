param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$IllustrationsRoot,
    [string]$OutputDir,
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

        $eligible += [pscustomobject]@{
            Heading = $heading.Heading
            Text = $heading.Text
            Level = $heading.Level
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

function New-PlacementPlan {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$Markdown,
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
        [Parameter(Mandatory)][object[]]$Placements
    )

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $lines = @(
        '# GZHRB Illustration Outline',
        '',
        'Style: ai-yang-detective-editorial',
        'Palette: #F6F1E8 / #27403A / #D8BFC5 / #A56A43',
        'Ratio: 16:9',
        'Quality: 2K',
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
            'Style: ai-yang-detective-editorial',
            'Palette: #F6F1E8 / #27403A / #D8BFC5 / #A56A43',
            ''
        )
    }

    return [string]::Join("`n", $lines)
}

function Get-IllustrationType {
    param([Parameter(Mandatory)][string]$HeadingText)

    $text = $HeadingText.ToLowerInvariant()

    if ($text.Contains('从') -and $text.Contains('到')) {
        return 'comparison'
    }

    if ($text.Contains('关系') -or $text.Contains('边界') -or $text.Contains('结构')) {
        return 'framework'
    }

    if ($text.Contains('开发者') -or $text.Contains('普通人') -or $text.Contains('没关系')) {
        return 'scene'
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
                '- Build a layered editorial framework graphic',
                '- Use one central structure with surrounding modules or stacked sections',
                '- Show hierarchy, boundaries, and one key conclusion',
                '- Prefer cards, containers, zones, labels, and structured grouping',
                '- Keep the composition stable, balanced, and easy to scan'
            )
        }
        'comparison' {
            return @(
                '- Build a left-right comparison layout with mirrored balance',
                '- Show two contrasting paths, systems, or roles clearly',
                '- Use matching containers, contrast labels, and a shared comparison anchor',
                '- Make differences obvious at a glance',
                '- Keep both sides visually balanced and structurally parallel'
            )
        }
        'flowchart' {
            return @(
                '- Build a directional flow illustration',
                '- Show a start, intermediate steps, and an outcome',
                '- Use arrows, connectors, stages, or transitions clearly',
                '- Keep the path readable in one viewing direction',
                '- Limit the number of nodes so the mechanism stays easy to scan'
            )
        }
        'scene' {
            return @(
                '- Build a minimal symbolic scene with one main object or one small group of objects',
                '- Keep the environment abstract and restrained',
                '- Retain diagram-like labels or structural hints so the image still explains rather than only atmospheres',
                '- Make the symbolic object clean, rounded, and lightly materialized',
                '- Do not let the scene overwhelm the explainer function'
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
                '- If the contrast is unclear, fall back to a framework layout with two clearly separated zones',
                '- Do not turn this into a flowchart unless the heading clearly describes a sequence'
            )
        }
        'flowchart' {
            return @(
                '- If the sequence is unclear, fall back to a framework graphic with three ordered stages',
                '- Direction must remain obvious; do not turn this into a static comparison board'
            )
        }
        'scene' {
            return @(
                '- If the concept is ambiguous, prefer a structured framework graphic over a mood-based scene',
                '- If a scene is used, keep it minimal and anchored by labels and structural cues'
            )
        }
        default {
            return @(
                '- If the concept is ambiguous, prefer a structured framework graphic over a mood-based scene',
                '- Keep explanation stronger than atmosphere'
            )
        }
    }
}

function Get-PromptContent {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][object]$Placement
    )

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $type = Get-IllustrationType -HeadingText $Placement.after_heading
    $typeTemplateLines = Get-TypeTemplateLines -Type $type
    $typeFallbackLines = Get-TypeFallbackLines -Type $type
    $lines = @(
        '---',
        "illustration_id: $('{0:d2}' -f $Placement.slot)",
        "type: $type",
        'style: ai-yang-detective-editorial',
        'palette: ai-yang-detective-default',
        '---',
        '',
        "# $($Placement.TaskId)",
        '',
        "Article: $articleId",
        "After heading: $($Placement.after_heading)",
        "Target image: $($Placement.image)",
        "Alt text: $($Placement.alt)",
        '',
        'Create a premium editorial inline illustration for a WeChat article.',
        'This is not a poster, not cinematic concept art, and not generic AI tech art.',
        'The image must help readers understand a structure, comparison, mechanism, or conclusion.',
        'This must follow AI杨侦探 default illustration style, not generic AI tech art.',
        '',
        'STYLE DIRECTION:',
        '- Light editorial explainer style with premium print-like texture',
        '- 70% diagram / structured explainer, 30% light 3D object scene',
        '- Premium, calm, structured, intelligent, restrained, low-AI-look',
        '- Warm cream background, clear modular layout, restrained palette, strong editorial clarity',
        '- Feels like an editor-designed magazine explainer graphic, not a flashy AI poster',
        '',
        'PALETTE:',
        '- Background: #F6F1E8',
        '- Deep structure color: #27403A',
        '- Soft accent: #D8BFC5',
        '- Highlight accent: #A56A43',
        '- Text / line neutral: #2B2B2B',
        'Color values are rendering guidance only. Do not show hex codes in the image.',
        '',
        'COMPOSITION:',
        '- Keep one clear core concept tied to the heading',
        '- Use strong hierarchy and generous whitespace',
        '- Limit the number of objects and modules',
        '- Make the focal point obvious within one second',
        '- Use clean cards, labels, arrows, zones, comparison blocks, or framework modules',
        '- Add only a few light 3D props if they help memory and interpretation',
        '- Maintain generous whitespace and clear hierarchy',
        ''
    )

    $lines += 'TYPE TEMPLATE:'
    $lines += $typeTemplateLines
    $lines += ''
    $lines += @(
        'OBJECT GUIDANCE:',
        '- If props are needed, prefer cards, chips, screens, control panels, module boxes, labels, or simple devices',
        '- Keep objects rounded, lightly materialized, and softly shadowed',
        '- Avoid glossy ecommerce-render look or heavy sci-fi machinery',
        '',
        'AVOID:',
        '- Dark blue backgrounds',
        '- Purple cyberpunk glow',
        '- Neon gradients',
        '- Floating futuristic UI panels',
        '- Busy collage layouts',
        '- Fake future city scenes',
        '- Complex mechanical robots',
        '- Realistic human faces',
        '- Poster-like cinematic drama',
        '- Watermarks, logos, or screenshots',
        '',
        'LABELS:',
        '- Chinese-first labels only',
        '- Keep labels short and structural',
        '- Prefer module names, conclusion words, relation words, or contrast labels',
        '- Do not place large paragraphs inside the image',
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
        [Parameter(Mandatory)][object[]]$Placements
    )

    $promptsDir = Get-PromptsDir -OutputDir $OutputDir
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $promptsDir | Out-Null

    $placementPath = Join-Path $OutputDir 'placement.json'
    $outlinePath = Join-Path $OutputDir 'outline.md'
    $batchPath = Join-Path $OutputDir 'batch.json'

    $placementJson = ConvertTo-Json -InputObject (ConvertTo-PlacementRecords -Placements $Placements) -Depth 5
    $batchJson = ConvertTo-Json -InputObject ([pscustomobject][ordered]@{
            jobs = 2
            tasks = @(Get-BatchTasks -Placements $Placements)
        }) -Depth 5

    Write-Utf8TextFile -Path $placementPath -Content $placementJson
    Write-Utf8TextFile -Path $outlinePath -Content (Get-OutlineContent -ArticlePath $ArticlePath -OutputDir $OutputDir -Placements $Placements)
    Write-Utf8TextFile -Path $batchPath -Content $batchJson

    foreach ($placement in $Placements) {
        $promptPath = Join-Path $OutputDir $placement.PromptFile
        Write-Utf8TextFile -Path $promptPath -Content (Get-PromptContent -ArticlePath $ArticlePath -Placement $placement)
    }
}

function Start-GzhrbIllustrationPlan {
    param(
        [string]$ArticlePath,
        [string]$GzhrbDir,
        [string]$IllustrationsRoot,
        [string]$OutputDir,
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
    $placements = New-PlacementPlan -ArticlePath $ArticlePath -Markdown $markdown -MaxPlacements $MaxPlacements
    Write-IllustrationPlanFiles -ArticlePath $ArticlePath -OutputDir $OutputDir -Placements $placements

    Write-Host '[OK] GZHRB illustration plan created.'
    Write-Host "Article       : $ArticlePath"
    Write-Host "Output dir    : $OutputDir"
    Write-Host "Placements    : $($placements.Count)"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbIllustrationPlan `
        -ArticlePath $ArticlePath `
        -GzhrbDir $GzhrbDir `
        -IllustrationsRoot $IllustrationsRoot `
        -OutputDir $OutputDir `
        -MaxPlacements $MaxPlacements
}
