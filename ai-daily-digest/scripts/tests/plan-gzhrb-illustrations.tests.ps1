$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'plan-gzhrb-illustrations.ps1'

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

function Assert-ThrowsLike {
    param(
        [scriptblock]$Action,
        [string]$ExpectedMessage,
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -like "*$ExpectedMessage*") {
            return
        }

        throw "Assert-ThrowsLike failed: $Message`nExpected error like: $ExpectedMessage`nActual error: $($_.Exception.Message)"
    }

    throw "Assert-ThrowsLike failed: $Message`nExpected an exception containing: $ExpectedMessage"
}

function New-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Write-TestUtf8File {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (New-Utf8NoBomEncoding))
}

function Read-TestUtf8File {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function New-StringFromCodePoints {
    param([int[]]$CodePoints)

    $builder = New-Object System.Text.StringBuilder
    foreach ($codePoint in $CodePoints) {
        [void]$builder.Append([char]$codePoint)
    }

    return $builder.ToString()
}

function Get-TestStrings {
    return @{
        MainTitle = New-StringFromCodePoints @(0x6BCF, 0x65E5, 0x89C2, 0x5BDF)
        TitleOptions = New-StringFromCodePoints @(0x6807, 0x9898, 0x5907, 0x9009)
        IntroOptions = New-StringFromCodePoints @(0x5F15, 0x5BFC, 0x8BED, 0x5907, 0x9009)
        TopicTags = New-StringFromCodePoints @(0x8BDD, 0x9898, 0x6807, 0x7B7E)
        BodyOne = New-StringFromCodePoints @(0x8FD9, 0x4E00, 0x6BB5, 0x8BF4, 0x660E, 0x5E02, 0x573A, 0x53D8, 0x5316)
        BodyTwo = New-StringFromCodePoints @(0x8FD9, 0x4E00, 0x6BB5, 0x8BF4, 0x660E, 0x5806, 0x6808, 0x538B, 0x529B)
        BodyThree = New-StringFromCodePoints @(0x8FD9, 0x4E00, 0x6BB5, 0x8BF4, 0x660E, 0x4EA4, 0x4ED8, 0x73B0, 0x5B9E)
        ChineseHeading = New-StringFromCodePoints @(0x4E2D, 0x6587, 0x89C2, 0x5BDF)
        BodyFour = New-StringFromCodePoints @(0x8FD9, 0x4E00, 0x6BB5, 0x4FDD, 0x7559, 0x4E2D, 0x6587, 0x5185, 0x5BB9)
        BodyFive = New-StringFromCodePoints @(0x8FD9, 0x4E00, 0x6BB5, 0x7528, 0x4E8E, 0x6536, 0x675F)
        BodySix = New-StringFromCodePoints @(0x6700, 0x540E, 0x4E00, 0x6BB5, 0x603B, 0x7ED3)
        RepeatHeading = New-StringFromCodePoints @(0x91CD, 0x590D, 0x5C0F, 0x8282)
        RepeatBodyOne = New-StringFromCodePoints @(0x91CD, 0x590D, 0x7B2C, 0x4E00, 0x6BB5)
        RepeatBodyTwo = New-StringFromCodePoints @(0x91CD, 0x590D, 0x7B2C, 0x4E8C, 0x6BB5)
        LongHeadingToken = New-StringFromCodePoints @(0x8D85, 0x957F, 0x7AE0, 0x8282)
    }
}

function New-TestArticleContent {
    param([hashtable]$Strings)

    $lines = @(
        "# $($Strings.MainTitle)",
        '',
        "# $($Strings.TitleOptions)",
        '',
        '## Alpha option',
        '',
        'Candidate heading that should be ignored.',
        '',
        '## Beta option',
        '',
        'Another candidate heading that should be ignored.',
        '',
        "# $($Strings.IntroOptions)",
        '',
        '## Intro candidate',
        '',
        'This intro option heading should be ignored.',
        '',
        "# $($Strings.TopicTags)",
        '',
        '## Tag candidate',
        '',
        'This topic tag heading should be ignored.',
        '',
        '# 正文',
        '',
        '## Market reset',
        '',
        $Strings.BodyOne,
        '',
        '### Stack pressure',
        '',
        $Strings.BodyTwo,
        '',
        '## Shipping reality',
        '',
        $Strings.BodyThree,
        '',
        ("## " + $Strings.ChineseHeading),
        '',
        $Strings.BodyFour,
        '',
        '### Closing signal',
        '',
        $Strings.BodyFive,
        '',
        '## Empty heading',
        '',
        '## Final takeaway',
        '',
        $Strings.BodySix
    )

    return [string]::Join("`n", $lines)
}

$strings = Get-TestStrings
$tempRoot = Join-Path $env:TEMP ("gzhrb-plan-test-" + [guid]::NewGuid().ToString('N'))
$gzhrbDir = Join-Path $tempRoot 'reports\gzhrb'
$illustrationsRoot = Join-Path $gzhrbDir 'illustrations'
$olderArticlePath = Join-Path $gzhrbDir 'gzhrb-20260415-1600.md'
$latestArticlePath = Join-Path $gzhrbDir 'gzhrb-20260415-1700.md'
$latestArticleId = 'gzhrb-20260415-1700'
$expectedDir = Join-Path $illustrationsRoot $latestArticleId
$articleScopedDir = Join-Path $gzhrbDir "articles\$latestArticleId"
$articleScopedPath = Join-Path $articleScopedDir 'article.md'

New-Item -ItemType Directory -Force -Path $illustrationsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $articleScopedDir | Out-Null
Write-TestUtf8File -Path $olderArticlePath -Content '# Older article'
Write-TestUtf8File -Path $latestArticlePath -Content (New-TestArticleContent -Strings $strings)
Write-TestUtf8File -Path $articleScopedPath -Content (New-TestArticleContent -Strings $strings)
(Get-Item -LiteralPath $olderArticlePath).LastWriteTime = [datetime]'2026-04-15T16:00:00'
(Get-Item -LiteralPath $latestArticlePath).LastWriteTime = [datetime]'2026-04-15T17:00:00'

$resolvedDir = Get-ArticleIllustrationsDir -ArticlePath $latestArticlePath -IllustrationsRoot $illustrationsRoot
Assert-Equal $resolvedDir $expectedDir 'Should resolve article-scoped illustration directory'
$resolvedArticleScopedDir = Get-ArticleIllustrationsDir -ArticlePath $articleScopedPath -IllustrationsRoot $illustrationsRoot
Assert-Equal $resolvedArticleScopedDir $expectedDir 'Should resolve parent article id when source path is article.md'

$tieGzhrbDir = Join-Path $tempRoot 'tie-gzhrb'
$sameTimeFirstPath = Join-Path $tieGzhrbDir 'gzhrb-20260415-1710.md'
$sameTimeSecondPath = Join-Path $tieGzhrbDir 'gzhrb-20260415-1711.md'
New-Item -ItemType Directory -Force -Path $tieGzhrbDir | Out-Null
Write-TestUtf8File -Path $sameTimeFirstPath -Content '# Same time first'
Write-TestUtf8File -Path $sameTimeSecondPath -Content '# Same time second'
$sameTimestamp = [datetime]'2026-04-15T18:00:00'
(Get-Item -LiteralPath $sameTimeFirstPath).LastWriteTime = $sameTimestamp
(Get-Item -LiteralPath $sameTimeSecondPath).LastWriteTime = $sameTimestamp

$latestTiePath = Get-LatestGzhrbPath -GzhrbDir $tieGzhrbDir
Assert-Equal $latestTiePath $sameTimeSecondPath 'Should break latest-article ties deterministically by file path'

$eligibleHeadings = Get-EligibleArticleHeadings -Markdown (Read-TestUtf8File -Path $latestArticlePath)
Assert-Equal $eligibleHeadings.Count 6 'Should return only eligible level-2 and level-3 headings with content'
Assert-Equal $eligibleHeadings[0].Heading '## Market reset' 'Should keep the first real section heading'
Assert-Equal $eligibleHeadings[1].Heading '### Stack pressure' 'Should keep eligible level-3 headings'
Assert-Equal $eligibleHeadings[2].Heading '## Shipping reality' 'Should keep later level-2 headings'
Assert-Equal $eligibleHeadings[3].Heading ("## " + $strings.ChineseHeading) 'Should preserve UTF-8 headings'
Assert-Equal $eligibleHeadings[4].Heading '### Closing signal' 'Should keep later level-3 headings'
Assert-Equal $eligibleHeadings[5].Heading '## Final takeaway' 'Should skip empty sections and keep later populated sections'
Assert-True (-not ($eligibleHeadings.Heading -contains '## Alpha option')) 'Should exclude title-option candidate headings'
Assert-True (-not ($eligibleHeadings.Heading -contains '## Beta option')) 'Should exclude title-option sections'
Assert-True (-not ($eligibleHeadings.Heading -contains '## Intro candidate')) 'Should exclude intro-option headings'
Assert-True (-not ($eligibleHeadings.Heading -contains '## Tag candidate')) 'Should exclude topic-tag headings'
Assert-True (-not ($eligibleHeadings.Heading -contains '## Empty heading')) 'Should exclude headings without body content'

$duplicateHeadingArticle = [string]::Join("`n", @(
        "# $($strings.MainTitle)",
        '',
        ("## " + $strings.RepeatHeading),
        '',
        $strings.RepeatBodyOne,
        '',
        '## Unique heading',
        '',
        $strings.BodyOne,
        '',
        ("## " + $strings.RepeatHeading),
        '',
        $strings.RepeatBodyTwo,
        '',
        '## Another unique heading',
        '',
        $strings.BodyTwo
    ))
$duplicateEligible = Get-EligibleArticleHeadings -Markdown $duplicateHeadingArticle
Assert-True (-not ($duplicateEligible.Heading -contains ("## " + $strings.RepeatHeading))) 'Should exclude duplicate full headings from eligible placements'

$duplicatePlacements = New-PlacementPlan `
    -ArticlePath $latestArticlePath `
    -Markdown $duplicateHeadingArticle `
    -MaxPlacements 5
Assert-Equal $duplicatePlacements.Count 2 'Should only plan unambiguous headings when duplicates are present'
Assert-True (-not ($duplicatePlacements.after_heading -contains ("## " + $strings.RepeatHeading))) 'Should not materialize ambiguous duplicate headings into placement plans'

$placements = New-PlacementPlan `
    -ArticlePath $latestArticlePath `
    -Markdown (Read-TestUtf8File -Path $latestArticlePath) `
    -MaxPlacements 5

Assert-Equal $placements.Count 5 'Should cap placements at the default max of five'

for ($i = 0; $i -lt $placements.Count; $i++) {
    $placement = $placements[$i]
    Assert-Equal $placement.slot ($i + 1) 'Should assign sequential slot numbers'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$placement.after_heading)) 'Should include after_heading'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$placement.image)) 'Should include image file name'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$placement.alt)) 'Should include alt text'
}

$longHeadingText = (($strings.LongHeadingToken + ' ') * 40).Trim()
$longHeadingArticle = [string]::Join("`n", @(
        "# $($strings.MainTitle)",
        '',
        "## $longHeadingText",
        '',
        $strings.BodyOne
    ))
$longHeadingPlacement = New-PlacementPlan `
    -ArticlePath $latestArticlePath `
    -Markdown $longHeadingArticle `
    -MaxPlacements 1
$longHeadingStem = [System.IO.Path]::GetFileNameWithoutExtension($longHeadingPlacement[0].image)
Assert-True ($longHeadingStem.StartsWith('01-')) 'Should preserve the slot prefix when capping long stems'
Assert-True ($longHeadingStem.Length -le 48) 'Should cap long stems to a safe deterministic length'
Assert-Equal $longHeadingPlacement[0].image ($longHeadingStem + '.png') 'Should keep image name aligned with the capped stem'

Assert-Equal $placements[0].image '01-market-reset.png' 'Should generate deterministic image names from headings'
Assert-Equal $placements[1].image '02-stack-pressure.png' 'Should generate deterministic image names for level-3 headings'
Assert-Equal $placements[2].image '03-shipping-reality.png' 'Should keep image names stable across reruns'
Assert-Equal $placements[3].image '04-u4e2d-u6587-u89c2-u5bdf.png' 'Should create ASCII-safe image names for UTF-8 headings'
Assert-Equal $placements[4].image '05-closing-signal.png' 'Should include slot prefixes in image names'

$placementsAgain = New-PlacementPlan `
    -ArticlePath $latestArticlePath `
    -Markdown (Read-TestUtf8File -Path $latestArticlePath) `
    -MaxPlacements 5

for ($i = 0; $i -lt $placements.Count; $i++) {
    Assert-Equal $placementsAgain[$i].image $placements[$i].image 'Should keep image names deterministic across reruns'
    Assert-Equal $placementsAgain[$i].PromptFile $placements[$i].PromptFile 'Should keep prompt file names deterministic across reruns'
}

Start-GzhrbIllustrationPlan -GzhrbDir $gzhrbDir -IllustrationsRoot $illustrationsRoot -MaxPlacements 5

$promptsDir = Join-Path $expectedDir 'prompts'
$placementJsonPath = Join-Path $expectedDir 'placement.json'
$outlinePath = Join-Path $expectedDir 'outline.md'
$batchPath = Join-Path $expectedDir 'batch.json'
$expectedPromptFiles = @(
    '01-market-reset.md',
    '02-stack-pressure.md',
    '03-shipping-reality.md',
    '04-u4e2d-u6587-u89c2-u5bdf.md',
    '05-closing-signal.md'
)

Assert-True (Test-Path -LiteralPath $expectedDir) 'Should materialize the article-scoped illustration directory'
Assert-True (Test-Path -LiteralPath $promptsDir) 'Should create prompts directory'
Assert-True (Test-Path -LiteralPath $placementJsonPath) 'Should write placement.json'
Assert-True (Test-Path -LiteralPath $outlinePath) 'Should write outline.md'
Assert-True (Test-Path -LiteralPath $batchPath) 'Should write batch.json'

foreach ($promptFile in $expectedPromptFiles) {
    Assert-True (Test-Path -LiteralPath (Join-Path $promptsDir $promptFile)) "Should write prompt file $promptFile"
}

$materializedPlacements = @((ConvertFrom-Json -InputObject (Read-TestUtf8File -Path $placementJsonPath)))
Assert-Equal $materializedPlacements.Count 5 'placement.json should contain five placements'
Assert-Equal $materializedPlacements[0].slot 1 'placement.json should preserve slot'
Assert-Equal $materializedPlacements[0].after_heading '## Market reset' 'placement.json should preserve target heading'
Assert-Equal $materializedPlacements[0].image '01-market-reset.png' 'placement.json should preserve deterministic image names'
Assert-Equal $materializedPlacements[3].image '04-u4e2d-u6587-u89c2-u5bdf.png' 'placement.json should preserve ASCII-safe UTF-8-derived image names'

$batch = ConvertFrom-Json -InputObject (Read-TestUtf8File -Path $batchPath)
Assert-Equal $batch.jobs 2 'batch.json should set jobs for batch image generation'
Assert-Equal $batch.tasks.Count 5 'batch.json should include one task per placement'
Assert-Equal $batch.tasks[0].id '01-market-reset' 'batch.json should derive task id from prompt stem'
Assert-Equal $batch.tasks[0].promptFiles[0] 'prompts/01-market-reset.md' 'batch.json should use relative prompt paths'
Assert-Equal $batch.tasks[0].image '01-market-reset.png' 'batch.json should target the deterministic image file name'
Assert-Equal $batch.tasks[0].provider 'google' 'batch.json should set provider'
Assert-Equal $batch.tasks[0].model 'gemini-3-pro-image-preview' 'batch.json should set model'
Assert-Equal $batch.tasks[0].ar '16:9' 'batch.json should set aspect ratio'
Assert-Equal $batch.tasks[0].quality '2k' 'batch.json should set quality'

$outline = Read-TestUtf8File -Path $outlinePath
Assert-True ($outline.Contains($latestArticleId)) 'outline.md should mention the article id'
Assert-True ($outline.Contains('## Market reset')) 'outline.md should summarize placement headings'
Assert-True ($outline.Contains($strings.ChineseHeading)) 'outline.md should preserve UTF-8 heading text'

$utf8PromptPath = Join-Path $promptsDir '04-u4e2d-u6587-u89c2-u5bdf.md'
$utf8Prompt = Read-TestUtf8File -Path $utf8PromptPath
Assert-True ($utf8Prompt.Contains($strings.ChineseHeading)) 'Prompt files should preserve UTF-8 heading text'
Assert-True ($utf8Prompt.Contains($latestArticleId)) 'Prompt files should mention the article id'

Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Host 'All plan-gzhrb-illustrations tests passed.'
