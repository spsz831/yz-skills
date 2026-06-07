$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'finalize-gzhrb-article.ps1'

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
        MainTitle = New-StringFromCodePoints @(0x4E3B, 0x6807, 0x9898)
        SectionOne = New-StringFromCodePoints @(0x7B2C, 0x4E00, 0x8282)
        SectionOneBody = New-StringFromCodePoints @(0x7B2C, 0x4E00, 0x8282, 0x6B63, 0x6587)
        SectionOneExtra = New-StringFromCodePoints @(0x7B2C, 0x4E00, 0x8282, 0x8865, 0x5145)
        SectionOneExtraBody = New-StringFromCodePoints @(0x8865, 0x5145, 0x8BF4, 0x660E)
        SectionTwo = New-StringFromCodePoints @(0x7B2C, 0x4E8C, 0x8282)
        SectionTwoBody = New-StringFromCodePoints @(0x7B2C, 0x4E8C, 0x8282, 0x6B63, 0x6587)
        MissingHeading = New-StringFromCodePoints @(0x4E0D, 0x5B58, 0x5728, 0x7684, 0x5C0F, 0x8282)
        ImageAltOne = New-StringFromCodePoints @(0x6D4B, 0x8BD5, 0x56FE)
        ImageAltTwo = New-StringFromCodePoints @(0x7B2C, 0x4E8C, 0x5F20, 0x56FE)
        ExistingAlt = New-StringFromCodePoints @(0x65E7, 0x56FE, 0x6CE8)
        ReplacementAlt = New-StringFromCodePoints @(0x65B0, 0x56FE, 0x6CE8)
        MissingImageAlt = New-StringFromCodePoints @(0x7F3A, 0x5931, 0x56FE, 0x7247)
    }
}

function New-TestPlacement {
    param(
        [hashtable]$Strings,
        [int]$Slot = 1,
        [string]$Heading = ("## " + $Strings.SectionOne),
        [string]$Image = '01-test.png',
        [string]$Alt = $Strings.ImageAltOne
    )

    return [pscustomobject]@{
        slot = $Slot
        after_heading = $Heading
        image = $Image
        alt = $Alt
    }
}

function New-TestArticleContent {
    param([hashtable]$Strings)

    $lines = @(
        "# $($Strings.MainTitle)",
        '',
        "## $($Strings.SectionOne)",
        '',
        $Strings.SectionOneBody,
        '',
        "### $($Strings.SectionOneExtra)",
        '',
        $Strings.SectionOneExtraBody,
        '',
        "## $($Strings.SectionTwo)",
        '',
        $Strings.SectionTwoBody
    )

    return [string]::Join("`n", $lines)
}

function New-PlacementJson {
    param([object[]]$Placements)

    return ($Placements | ConvertTo-Json -Depth 4)
}

$strings = Get-TestStrings
$sectionOneHeading = "## $($strings.SectionOne)"
$sectionTwoHeading = "## $($strings.SectionTwo)"
$missingHeading = "## $($strings.MissingHeading)"
$sectionOneExtraHeading = "### $($strings.SectionOneExtra)"

$articleId = Get-ArticleIdFromPath 'E:\WorkCodex\ai-daily-digest\reports\gzhrb\articles\gzhrb-20260415-1639\article.md'
Assert-Equal $articleId 'gzhrb-20260415-1639' 'Should derive article id from article file name'

$tempRoot = Join-Path $env:TEMP ("gzhrb-finalize-test-" + [guid]::NewGuid().ToString('N'))
$gzhrbDir = Join-Path $tempRoot 'reports\gzhrb'
$illustrationsRoot = Join-Path $gzhrbDir 'illustrations'
$articlePath = Join-Path $gzhrbDir 'articles\gzhrb-20260415-1639\article.md'
$articleIllustrationsDir = Join-Path $illustrationsRoot 'gzhrb-20260415-1639'
$placementPath = Join-Path $articleIllustrationsDir 'placement.json'
$imagePath = Join-Path $articleIllustrationsDir '01-test.png'

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $articlePath), $articleIllustrationsDir | Out-Null
Write-TestUtf8File -Path $articlePath -Content (New-TestArticleContent -Strings $strings)
Write-TestUtf8File -Path $imagePath -Content 'image-binary'

$latestArticlePath = Join-Path $gzhrbDir 'articles\gzhrb-20260415-9999\article.md'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $latestArticlePath) | Out-Null
Write-TestUtf8File -Path $latestArticlePath -Content (New-TestArticleContent -Strings $strings)
$detectedLatestArticle = Get-LatestGzhrbPath -GzhrbDir $gzhrbDir
Assert-Equal $detectedLatestArticle $latestArticlePath 'Should discover latest article from reports/gzhrb/articles/*/article.md'

$placementsSeed = @(
    [pscustomobject]@{
        slot = 1
        after_heading = $sectionOneHeading
        image = '01-test.png'
        alt = $strings.ImageAltOne
    },
    [pscustomobject]@{
        slot = 2
        after_heading = $sectionTwoHeading
        image = '02-test.png'
        alt = $strings.ImageAltTwo
    }
)

Write-TestUtf8File -Path $placementPath -Content (New-PlacementJson -Placements $placementsSeed)
Write-TestUtf8File -Path (Join-Path $articleIllustrationsDir '02-test.png') -Content 'image-binary-2'

$placements = Read-PlacementFile -PlacementPath $placementPath
Assert-Equal $placements.Count 2 'Should read two placement records'
Assert-Equal $placements[0].after_heading $sectionOneHeading 'Should preserve target heading'
Assert-Equal $placements[0].image '01-test.png' 'Should preserve image file name'
Assert-Equal $placements[0].alt $strings.ImageAltOne 'Should preserve alt text'

$invalidPlacementPath = Join-Path $articleIllustrationsDir 'placement-invalid.json'
$invalidPlacementSeed = @(
    [pscustomobject]@{
        slot = 1
        after_heading = $sectionOneHeading
        image = '01-test.png'
    }
)
Write-TestUtf8File -Path $invalidPlacementPath -Content (New-PlacementJson -Placements $invalidPlacementSeed)

Assert-ThrowsLike {
    Read-PlacementFile -PlacementPath $invalidPlacementPath
} 'alt' 'Should fail when a placement record misses required fields'

$lines = (New-TestArticleContent -Strings $strings) -split "`r?`n"
$headingIndex = Find-HeadingLineIndex -Lines $lines -Heading $sectionTwoHeading
Assert-Equal $headingIndex 10 'Should find heading line index for the target heading'

Assert-ThrowsLike {
    Find-HeadingLineIndex -Lines $lines -Heading $missingHeading
} $missingHeading 'Should fail when the heading does not exist'

$duplicateHeadingLines = @(
    "# $($strings.MainTitle)",
    '',
    $sectionOneHeading,
    '',
    $strings.SectionOneBody,
    '',
    $sectionOneHeading,
    '',
    $strings.SectionTwoBody
)

Assert-ThrowsLike {
    Find-HeadingLineIndex -Lines $duplicateHeadingLines -Heading $sectionOneHeading
} 'more than once' 'Should fail when a target heading occurs more than once'

$updated = Insert-IllustrationAfterHeadingSection `
    -Lines $lines `
    -ArticleId 'gzhrb-20260415-1639' `
    -Placement (New-TestPlacement -Strings $strings)

$expectedBlock = '![{0}](illustrations/01-test.png)' -f $strings.ImageAltOne
Assert-True ($updated.Contains($expectedBlock)) 'Should insert image markdown with archived path'
Assert-True ($updated.IndexOf($expectedBlock) -gt $updated.IndexOf($strings.SectionOneExtraBody)) 'Should insert after the target section content'
Assert-True ($updated.IndexOf($expectedBlock) -lt $updated.IndexOf($sectionTwoHeading)) 'Should insert before the next heading of same or higher level'

$updatedAgain = Insert-IllustrationAfterHeadingSection `
    -Lines ($updated -split "`r?`n") `
    -ArticleId 'gzhrb-20260415-1639' `
    -Placement (New-TestPlacement -Strings $strings)

$duplicateMatches = [regex]::Matches(
    $updatedAgain,
    [regex]::Escape($expectedBlock)
).Count
Assert-Equal $duplicateMatches 1 'Should not insert duplicate image blocks when rerun'

$existingDifferentAltLines = @(
    "# $($strings.MainTitle)",
    '',
    $sectionOneHeading,
    '',
    $strings.SectionOneBody,
    '',
    ('![{0}](illustrations/01-test.png)' -f $strings.ExistingAlt),
    '',
    $sectionOneExtraHeading,
    '',
    $strings.SectionOneExtraBody,
    '',
    $sectionTwoHeading,
    '',
    $strings.SectionTwoBody
)
$existingDifferentAlt = [string]::Join("`n", $existingDifferentAltLines)

$updatedWithExistingPath = Insert-IllustrationAfterHeadingSection `
    -Lines ($existingDifferentAlt -split "`r?`n") `
    -ArticleId 'gzhrb-20260415-1639' `
    -Placement (New-TestPlacement -Strings $strings -Alt $strings.ReplacementAlt)

$pathOnlyMatches = [regex]::Matches(
    $updatedWithExistingPath,
    [regex]::Escape('(illustrations/01-test.png)')
).Count
Assert-Equal $pathOnlyMatches 1 'Should not insert a duplicate when the same image path already exists with different alt text'
Assert-True (
    $updatedWithExistingPath.Contains(
        ('![{0}](illustrations/01-test.png)' -f $strings.ExistingAlt)
    )
) 'Should preserve the existing image block when duplicate detection matches by path'

$missingImageArticlePath = Join-Path $gzhrbDir 'articles\gzhrb-20260415-1700\article.md'
$missingImageArticleId = Get-ArticleIdFromPath $missingImageArticlePath
$missingImageDir = Join-Path $illustrationsRoot $missingImageArticleId
$missingImagePlacementPath = Join-Path $missingImageDir 'placement.json'

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $missingImageArticlePath), $missingImageDir | Out-Null
Write-TestUtf8File -Path $missingImageArticlePath -Content (New-TestArticleContent -Strings $strings)
$missingPlacementSeed = @(
    [pscustomobject]@{
        slot = 1
        after_heading = $sectionOneHeading
        image = '01-missing.png'
        alt = $strings.MissingImageAlt
    }
)
Write-TestUtf8File -Path $missingImagePlacementPath -Content (New-PlacementJson -Placements $missingPlacementSeed)

$originalMissingImageContent = Read-TestUtf8File -Path $missingImageArticlePath
Assert-ThrowsLike {
    Start-GzhrbArticleFinalize `
        -ArticlePath $missingImageArticlePath `
        -GzhrbDir $gzhrbDir `
        -IllustrationsRoot $illustrationsRoot
} '01-missing.png' 'Should fail before writing when a required image is missing'
$afterMissingImageFailure = Read-TestUtf8File -Path $missingImageArticlePath
Assert-Equal $afterMissingImageFailure $originalMissingImageContent 'Should not rewrite the article when validation fails'

$duplicateHeadingArticlePath = Join-Path $gzhrbDir 'articles\gzhrb-20260415-1750\article.md'
$duplicateHeadingArticleId = Get-ArticleIdFromPath $duplicateHeadingArticlePath
$duplicateHeadingDir = Join-Path $illustrationsRoot $duplicateHeadingArticleId
$duplicateHeadingPlacementPath = Join-Path $duplicateHeadingDir 'placement.json'
$duplicateHeadingImagePath = Join-Path $duplicateHeadingDir '01-duplicate.png'
$duplicateHeadingArticleContent = [string]::Join("`n", @(
        "# $($strings.MainTitle)",
        '',
        $sectionOneHeading,
        '',
        $strings.SectionOneBody,
        '',
        $sectionOneHeading,
        '',
        $strings.SectionTwoBody
    ))

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $duplicateHeadingArticlePath), $duplicateHeadingDir | Out-Null
Write-TestUtf8File -Path $duplicateHeadingArticlePath -Content $duplicateHeadingArticleContent
Write-TestUtf8File -Path $duplicateHeadingImagePath -Content 'image-binary-duplicate'
Write-TestUtf8File -Path $duplicateHeadingPlacementPath -Content (New-PlacementJson -Placements @(
        [pscustomobject]@{
            slot = 1
            after_heading = $sectionOneHeading
            image = '01-duplicate.png'
            alt = $strings.ImageAltOne
        }
    ))

$originalDuplicateHeadingContent = Read-TestUtf8File -Path $duplicateHeadingArticlePath
Assert-ThrowsLike {
    Start-GzhrbArticleFinalize `
        -ArticlePath $duplicateHeadingArticlePath `
        -GzhrbDir $gzhrbDir `
        -IllustrationsRoot $illustrationsRoot
} 'more than once' 'Should fail before writing when a placement heading is ambiguous in the article'
$afterDuplicateHeadingFailure = Read-TestUtf8File -Path $duplicateHeadingArticlePath
Assert-Equal $afterDuplicateHeadingFailure $originalDuplicateHeadingContent 'Should not rewrite the article when duplicate headings make a placement ambiguous'

$utf8ArticlePath = Join-Path $gzhrbDir 'articles\gzhrb-20260415-1800\article.md'
$utf8ArticleId = Get-ArticleIdFromPath $utf8ArticlePath
$utf8IllustrationsDir = Join-Path $illustrationsRoot $utf8ArticleId
$utf8PlacementPath = Join-Path $utf8IllustrationsDir 'placement.json'
$utf8ImageName = '01-utf8.png'
$utf8Placement = [pscustomobject]@{
    slot = 1
    after_heading = $sectionOneHeading
    image = $utf8ImageName
    alt = $strings.ImageAltOne
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $utf8ArticlePath), $utf8IllustrationsDir | Out-Null
Write-TestUtf8File -Path $utf8ArticlePath -Content (New-TestArticleContent -Strings $strings)
Write-TestUtf8File -Path (Join-Path $utf8IllustrationsDir $utf8ImageName) -Content 'image-binary-utf8'
Write-TestUtf8File -Path $utf8PlacementPath -Content (New-PlacementJson -Placements @($utf8Placement))

Start-GzhrbArticleFinalize `
    -ArticlePath $utf8ArticlePath `
    -GzhrbDir $gzhrbDir `
    -IllustrationsRoot $illustrationsRoot

$utf8Finalized = Read-TestUtf8File -Path $utf8ArticlePath
$utf8ExpectedBlock = '![{0}](illustrations/{1})' -f $strings.ImageAltOne, $utf8ImageName
Assert-True ($utf8Finalized.Contains("# $($strings.MainTitle)")) 'Should preserve UTF-8 title text during finalization'
Assert-True ($utf8Finalized.Contains($sectionOneHeading)) 'Should preserve UTF-8 heading text during finalization'
Assert-True ($utf8Finalized.Contains($strings.SectionOneBody)) 'Should preserve UTF-8 body text during finalization'
Assert-True ($utf8Finalized.Contains($utf8ExpectedBlock)) 'Should insert UTF-8 alt text without corruption'

Start-GzhrbArticleFinalize `
    -ArticlePath $articlePath `
    -GzhrbDir $gzhrbDir `
    -IllustrationsRoot $illustrationsRoot

$finalized = Read-TestUtf8File -Path $articlePath
Assert-True ($finalized.Contains('![{0}](illustrations/01-test.png)' -f $strings.ImageAltOne)) 'Should write the first placement block into the article'
Assert-True ($finalized.Contains('![{0}](illustrations/02-test.png)' -f $strings.ImageAltTwo)) 'Should write the second placement block into the article'

Start-GzhrbArticleFinalize `
    -ArticlePath $articlePath `
    -GzhrbDir $gzhrbDir `
    -IllustrationsRoot $illustrationsRoot

$finalizedAgain = Read-TestUtf8File -Path $articlePath
$allFirstMatches = [regex]::Matches(
    $finalizedAgain,
    [regex]::Escape('![{0}](illustrations/01-test.png)' -f $strings.ImageAltOne)
).Count
$allSecondMatches = [regex]::Matches(
    $finalizedAgain,
    [regex]::Escape('![{0}](illustrations/02-test.png)' -f $strings.ImageAltTwo)
).Count
Assert-Equal $allFirstMatches 1 'Should keep first placement idempotent across full finalizer runs'
Assert-Equal $allSecondMatches 1 'Should keep second placement idempotent across full finalizer runs'

Remove-Item -LiteralPath $tempRoot -Recurse -Force

Write-Host 'All finalize-gzhrb-article tests passed.'
