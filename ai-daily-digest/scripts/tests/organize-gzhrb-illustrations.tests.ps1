$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'organize-gzhrb-illustrations.ps1'

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

function New-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (New-Utf8NoBomEncoding))
}

function New-NonAsciiAltText {
    $chars = @(
        [char]0x63D2,
        [char]0x56FE,
        [char]0x89C4,
        [char]0x5212,
        [char]0x6D4B,
        [char]0x8BD5
    )

    return -join $chars
}

function New-NonAsciiArticleText {
    $chars = @(
        [char]0x4E2D,
        [char]0x6587,
        [char]0x6B63,
        [char]0x6587,
        [char]0x6D4B,
        [char]0x8BD5
    )

    return -join $chars
}

function New-TestEnvironment {
    $tempRoot = Join-Path $env:TEMP ("gzhrb-illustration-test-" + [guid]::NewGuid().ToString('N'))
    $gzhrbDir = Join-Path $tempRoot 'reports\gzhrb'
    $illustrationsRoot = Join-Path $gzhrbDir 'illustrations'
    $promptsRoot = Join-Path $illustrationsRoot 'prompts'
    $articleId = 'gzhrb-20260415-1639'
    $articleDir = Join-Path $gzhrbDir "articles\$articleId"
    $articlePath = Join-Path $articleDir 'article.md'

    New-Item -ItemType Directory -Force -Path $promptsRoot, $articleDir | Out-Null

    [pscustomobject]@{
        TempRoot          = $tempRoot
        GzhrbDir          = $gzhrbDir
        IllustrationsRoot = $illustrationsRoot
        PromptsRoot       = $promptsRoot
        ArticlePath       = $articlePath
        ArticleId         = $articleId
    }
}

function Remove-TestEnvironment {
    param([Parameter(Mandatory)]$Environment)

    if (Test-Path -LiteralPath $Environment.TempRoot) {
        Remove-Item -LiteralPath $Environment.TempRoot -Recurse -Force
    }
}

function Initialize-OrganizerFixture {
    param(
        [Parameter(Mandatory)]$Environment,
        [string]$OutlineArticleValue = $null,
        [string]$PlacementContent = $null,
        [string]$PlacementFileName = 'placement.json',
        [string]$ArticleContent = $null,
        [string[]]$MissingImageNames = @(),
        [switch]$CreateArticleScopedPlacement
    )

    if ([string]::IsNullOrEmpty($ArticleContent)) {
        $ArticleContent = @'
# Test

![图一](illustrations/01-a.png)
![图二](illustrations/02-b.png)
'@
    }

    Write-Utf8NoBomFile -Path $Environment.ArticlePath -Content $ArticleContent

    if ($MissingImageNames -notcontains '01-a.png') {
        'fake-image-1' | Set-Content -LiteralPath (Join-Path $Environment.IllustrationsRoot '01-a.png') -Encoding UTF8
    }

    if ($MissingImageNames -notcontains '02-b.png') {
        'fake-image-2' | Set-Content -LiteralPath (Join-Path $Environment.IllustrationsRoot '02-b.png') -Encoding UTF8
    }

    'prompt-1' | Set-Content -LiteralPath (Join-Path $Environment.PromptsRoot '01-a.md') -Encoding UTF8
    'prompt-2' | Set-Content -LiteralPath (Join-Path $Environment.PromptsRoot '02-b.md') -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($OutlineArticleValue)) {
        $OutlineArticleValue = [System.IO.Path]::GetFileName($Environment.ArticlePath)
    }

    "article: $OutlineArticleValue" | Set-Content -LiteralPath (Join-Path $Environment.IllustrationsRoot 'outline.md') -Encoding UTF8
    '{}' | Set-Content -LiteralPath (Join-Path $Environment.IllustrationsRoot 'batch.json') -Encoding UTF8

    if ($null -ne $PlacementContent) {
        $placementPath = Join-Path $Environment.IllustrationsRoot $PlacementFileName
        Write-Utf8NoBomFile -Path $placementPath -Content $PlacementContent
    }

    if ($CreateArticleScopedPlacement) {
        $targetDir = Join-Path $Environment.IllustrationsRoot $Environment.ArticleId
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Write-Utf8NoBomFile -Path (Join-Path $targetDir 'placement.json') -Content '{"slot":99}'
    }
}

$envInfo = New-TestEnvironment

try {
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent '{"article":"gzhrb-20260415-1639"}'

    $refs = Get-DirectIllustrationFiles -Content (Read-Utf8File -Path $envInfo.ArticlePath)
    Assert-Equal $refs.Count 2 'Should find two direct illustration refs'

    $articleId = Get-ArticleIllustrationId -ArticlePath $envInfo.ArticlePath
    Assert-Equal $articleId 'gzhrb-20260415-1639' 'Should derive article id from file name'
    Assert-True (Root-OutlineBelongsToArticle -OutlinePath (Join-Path $envInfo.IllustrationsRoot 'outline.md') -ArticlePath $envInfo.ArticlePath) 'Fixture outline should belong to article before organize'

    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath
    Start-GzhrbIllustrationOrganize

    $targetDir = Join-Path $envInfo.IllustrationsRoot $envInfo.ArticleId
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir '01-a.png')) 'Should move first image into article directory'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir '02-b.png')) 'Should move second image into article directory'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir 'prompts\01-a.md')) 'Should move first prompt into article directory'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir 'prompts\02-b.md')) 'Should move second prompt into article directory'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir 'outline.md')) 'Should move outline when it belongs to article'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir 'batch.json')) 'Should move batch with outline'
    Assert-True (Test-Path -LiteralPath (Join-Path $targetDir 'placement.json')) 'Should move placement metadata with outline and batch'

    $updatedArticle = Read-Utf8File -Path $envInfo.ArticlePath
    Assert-True ($updatedArticle.Contains('illustrations/gzhrb-20260415-1639/01-a.png')) 'Should rewrite first illustration ref'
    Assert-True ($updatedArticle.Contains('illustrations/gzhrb-20260415-1639/02-b.png')) 'Should rewrite second illustration ref'
    Assert-True (-not (Test-Path -LiteralPath $envInfo.PromptsRoot)) 'Should remove empty root prompts directory'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

$envInfo = New-TestEnvironment

try {
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent '{"article":"gzhrb-20260415-1639"}'

    $targetDir = Join-Path $envInfo.IllustrationsRoot $envInfo.ArticleId
    $targetPlacementPath = Join-Path $targetDir 'placement.json'
    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath
    Start-GzhrbIllustrationOrganize

    $expectedPlacement = Get-Content -Raw -LiteralPath $targetPlacementPath
    $expectedArticle = Read-Utf8File -Path $envInfo.ArticlePath

    Start-GzhrbIllustrationOrganize

    $actualPlacement = Get-Content -Raw -LiteralPath $targetPlacementPath
    Assert-Equal $actualPlacement $expectedPlacement 'Should not overwrite article-scoped placement on rerun'
    Assert-Equal (Read-Utf8File -Path $envInfo.ArticlePath) $expectedArticle 'Should not rewrite article refs again on rerun'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $envInfo.IllustrationsRoot 'placement.json'))) 'Should not recreate root placement on rerun'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

$envInfo = New-TestEnvironment

try {
    $nonAsciiAlt = New-NonAsciiAltText
    $placementContent = "[{`"image`":`"01-a.png`",`"alt`":`"$nonAsciiAlt`"}]"
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent $placementContent

    $placementPath = Join-Path $envInfo.IllustrationsRoot 'placement.json'
    Assert-True (Root-PlacementBelongsToArticle -PlacementPath $placementPath -ArticlePath $envInfo.ArticlePath -DirectFiles @('01-a.png', '02-b.png')) 'Should read UTF-8 no BOM placement.json with non-ASCII content'

    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath
    Start-GzhrbIllustrationOrganize

    $targetPlacementPath = Join-Path (Join-Path $envInfo.IllustrationsRoot $envInfo.ArticleId) 'placement.json'
    $movedPlacement = Read-Utf8File -Path $targetPlacementPath
    Assert-True ($movedPlacement.Contains($nonAsciiAlt)) 'Should preserve non-ASCII placement content after move'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

$envInfo = New-TestEnvironment

try {
    $nonAsciiArticle = New-NonAsciiArticleText
    $articleContent = "# $nonAsciiArticle`n`n$nonAsciiArticle`n`n![图一](illustrations/01-a.png)`n![图二](illustrations/02-b.png)`n"
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent '{"article":"gzhrb-20260415-1639"}' -ArticleContent $articleContent

    $beforeBytes = [System.IO.File]::ReadAllBytes($envInfo.ArticlePath)
    Assert-True (-not (($beforeBytes.Length -ge 3) -and $beforeBytes[0] -eq 0xEF -and $beforeBytes[1] -eq 0xBB -and $beforeBytes[2] -eq 0xBF)) 'Fixture article should be UTF-8 without BOM'

    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath
    Start-GzhrbIllustrationOrganize

    $updatedArticle = Read-Utf8File -Path $envInfo.ArticlePath
    $afterBytes = [System.IO.File]::ReadAllBytes($envInfo.ArticlePath)
    Assert-True ($updatedArticle.Contains($nonAsciiArticle)) 'Should preserve non-ASCII article content after rewrite'
    Assert-True ($updatedArticle.Contains('illustrations/gzhrb-20260415-1639/01-a.png')) 'Should rewrite refs for UTF-8 article content'
    Assert-True (-not (($afterBytes.Length -ge 3) -and $afterBytes[0] -eq 0xEF -and $afterBytes[1] -eq 0xBB -and $afterBytes[2] -eq 0xBF)) 'Should not add BOM when rewriting article'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

$envInfo = New-TestEnvironment

try {
    $originalArticle = "# Test`n`n![图一](illustrations/01-a.png)`n![图二](illustrations/02-b.png)`n"
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent '{"article":"gzhrb-20260415-1639"}' -ArticleContent $originalArticle -MissingImageNames @('02-b.png')

    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath

    $failed = $false
    try {
        Start-GzhrbIllustrationOrganize
    }
    catch {
        $failed = $true
    }

    Assert-True $failed 'Should fail when a referenced root image is missing from both source and target'
    Assert-Equal (Read-Utf8File -Path $envInfo.ArticlePath) $originalArticle 'Should not rewrite article when a referenced image is missing'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

$envInfo = New-TestEnvironment

try {
    Initialize-OrganizerFixture -Environment $envInfo -PlacementContent '{"article":"gzhrb-20260416-0900"}' -OutlineArticleValue 'gzhrb-20260416-0900.md'

    $GzhrbDir = $envInfo.GzhrbDir
    $IllustrationsRoot = $envInfo.IllustrationsRoot
    $ArticlePath = $envInfo.ArticlePath
    Start-GzhrbIllustrationOrganize

    $targetDir = Join-Path $envInfo.IllustrationsRoot $envInfo.ArticleId
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $targetDir 'placement.json'))) 'Should not move root placement for another article'
    Assert-True (Test-Path -LiteralPath (Join-Path $envInfo.IllustrationsRoot 'placement.json')) 'Should keep unrelated root placement metadata'
}
finally {
    Remove-TestEnvironment -Environment $envInfo
}

Write-Host 'All organize-gzhrb-illustrations tests passed.'
