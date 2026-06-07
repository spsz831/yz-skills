param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$IllustrationsRoot
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

    $resolvedPath = [System.IO.Path]::GetFullPath($ArticlePath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedPath)
    if ([string]::Equals($fileName, 'article', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($resolvedPath))
    }

    return $fileName
}

function Get-LatestGzhrbPath {
    param([Parameter(Mandatory)][string]$GzhrbDir)

    $articlesRoot = Join-Path $GzhrbDir 'articles'
    $latestFromArticles = @()
    if (Test-Path -LiteralPath $articlesRoot) {
        $latestFromArticles = Get-ChildItem -LiteralPath $articlesRoot -Recurse -File -Filter 'article.md'
    }

    if ($latestFromArticles.Count -gt 0) {
        $latest = $latestFromArticles |
            Sort-Object `
                @{ Expression = { $_.LastWriteTime }; Descending = $true }, `
                @{ Expression = { $_.FullName }; Descending = $true } |
            Select-Object -First 1
        return $latest.FullName
    }

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

function Get-HeadingLevel {
    param([Parameter(Mandatory)][string]$Heading)

    if ($Heading -notmatch '^(#+)\s+') {
        throw "Invalid markdown heading: $Heading"
    }

    return $Matches[1].Length
}

function Get-HeadingLevelFromLine {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    if ($Line -notmatch '^(#+)\s+') {
        return $null
    }

    return $Matches[1].Length
}

function Get-Newline {
    param([AllowEmptyString()][string]$Content)

    if ($Content -match "`r`n") {
        return "`r`n"
    }

    return "`n"
}

function Get-MarkdownImageBlock {
    param(
        [Parameter(Mandatory)][string]$ArticleId,
        [Parameter(Mandatory)][object]$Placement
    )

    return "![{0}](illustrations/{1})" -f $Placement.alt, $Placement.image
}

function Get-MarkdownImagePath {
    param(
        [Parameter(Mandatory)][string]$ArticleId,
        [Parameter(Mandatory)][object]$Placement
    )

    return "illustrations/{0}" -f $Placement.image
}

function Read-PlacementFile {
    param([Parameter(Mandatory)][string]$PlacementPath)

    if (-not (Test-Path -LiteralPath $PlacementPath)) {
        throw "Placement file not found: $PlacementPath"
    }

    $raw = Read-Utf8TextFile -Path $PlacementPath
    $parsed = ConvertFrom-Json -InputObject $raw

    if ($null -eq $parsed) {
        throw "Placement file is empty: $PlacementPath"
    }

    $placements = @($parsed)
    if ($placements.Count -eq 0) {
        throw "Placement file must contain at least one placement: $PlacementPath"
    }

    $validated = New-Object System.Collections.Generic.List[object]

    foreach ($placement in $placements) {
        foreach ($field in @('slot', 'after_heading', 'image', 'alt')) {
            if (-not ($placement.PSObject.Properties.Name -contains $field)) {
                throw "Placement record is missing required field '$field' in: $PlacementPath"
            }
        }

        $slotText = [string]$placement.slot
        $afterHeading = [string]$placement.after_heading
        $image = [string]$placement.image
        $alt = [string]$placement.alt

        if ([string]::IsNullOrWhiteSpace($slotText)) {
            throw "Placement record has blank slot in: $PlacementPath"
        }

        $slot = 0
        if (-not [int]::TryParse($slotText, [ref]$slot) -or $slot -le 0) {
            throw "Placement slot must be a positive integer in: $PlacementPath"
        }

        if ([string]::IsNullOrWhiteSpace($afterHeading)) {
            throw "Placement record has blank after_heading in: $PlacementPath"
        }

        if ($afterHeading -notmatch '^#{2,3}\s+\S') {
            throw "Placement after_heading must be a level-2 or level-3 markdown heading in: $PlacementPath"
        }

        if ([string]::IsNullOrWhiteSpace($image)) {
            throw "Placement record has blank image in: $PlacementPath"
        }

        if ($image.Contains('/') -or $image.Contains('\')) {
            throw "Placement image must be a file name, not a path, in: $PlacementPath"
        }

        if ([string]::IsNullOrWhiteSpace($alt)) {
            throw "Placement record has blank alt in: $PlacementPath"
        }

        $validated.Add([pscustomobject]@{
                slot = $slot
                after_heading = $afterHeading
                image = $image
                alt = $alt
            })
    }

    return @($validated | Sort-Object slot)
}

function Find-HeadingLineIndex {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Heading
    )

    $matches = @()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -ceq $Heading) {
            $matches += $i
        }
    }

    if ($matches.Count -gt 1) {
        throw "Heading occurs more than once in article: $Heading"
    }

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    throw "Heading not found in article: $Heading"
}

function Get-SectionBounds {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Heading
    )

    $headingIndex = Find-HeadingLineIndex -Lines $Lines -Heading $Heading
    $headingLevel = Get-HeadingLevel -Heading $Heading
    $insertIndex = $Lines.Count

    for ($i = $headingIndex + 1; $i -lt $Lines.Count; $i++) {
        $lineHeadingLevel = Get-HeadingLevelFromLine -Line $Lines[$i]
        if ($null -ne $lineHeadingLevel -and $lineHeadingLevel -le $headingLevel) {
            $insertIndex = $i
            break
        }
    }

    return [pscustomobject]@{
        HeadingIndex = $headingIndex
        InsertIndex = $insertIndex
    }
}

function Insert-IllustrationAfterHeadingSection {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$ArticleId,
        [Parameter(Mandatory)][object]$Placement
    )

    $newline = "`n"
    $bounds = Get-SectionBounds -Lines $Lines -Heading $Placement.after_heading
    $imageBlock = Get-MarkdownImageBlock -ArticleId $ArticleId -Placement $Placement
    $imagePath = Get-MarkdownImagePath -ArticleId $ArticleId -Placement $Placement

    $sectionLength = $bounds.InsertIndex - $bounds.HeadingIndex
    $sectionLines = @()
    if ($sectionLength -gt 0) {
        $sectionLines = $Lines[$bounds.HeadingIndex..($bounds.InsertIndex - 1)]
    }

    $sectionText = [string]::Join($newline, $sectionLines)
    if ($sectionText.Contains("($imagePath)")) {
        return [string]::Join($newline, $Lines)
    }

    $before = @()
    if ($bounds.InsertIndex -gt 0) {
        $before = $Lines[0..($bounds.InsertIndex - 1)]
    }

    $after = @()
    if ($bounds.InsertIndex -lt $Lines.Count) {
        $after = $Lines[$bounds.InsertIndex..($Lines.Count - 1)]
    }

    $updatedLines = New-Object System.Collections.Generic.List[string]
    foreach ($line in $before) {
        $updatedLines.Add([string]$line)
    }

    if ($updatedLines.Count -gt 0 -and $updatedLines[$updatedLines.Count - 1] -ne '') {
        $updatedLines.Add('')
    }

    $updatedLines.Add($imageBlock)
    $updatedLines.Add('')

    if ($after.Count -gt 0 -and $after[0] -eq '') {
        $after = if ($after.Count -gt 1) { $after[1..($after.Count - 1)] } else { @() }
    }

    foreach ($line in $after) {
        $updatedLines.Add([string]$line)
    }

    return [string]::Join($newline, $updatedLines)
}

function Start-GzhrbArticleFinalize {
    param(
        [string]$ArticlePath,
        [string]$GzhrbDir,
        [string]$IllustrationsRoot
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

    if (-not (Test-Path -LiteralPath $IllustrationsRoot)) {
        throw "Illustrations root not found: $IllustrationsRoot"
    }

    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $articleIllustrationsDir = Join-Path $IllustrationsRoot $articleId
    $placementPath = Join-Path $articleIllustrationsDir 'placement.json'

    $articleContent = Read-Utf8TextFile -Path $ArticlePath
    $newline = Get-Newline -Content $articleContent
    $lines = $articleContent -split "`r?`n"
    $placements = Read-PlacementFile -PlacementPath $placementPath

    foreach ($placement in $placements) {
        $imagePath = Join-Path $articleIllustrationsDir $placement.image
        if (-not (Test-Path -LiteralPath $imagePath)) {
            throw "Required image not found for article '$articleId': $imagePath"
        }

        $null = Find-HeadingLineIndex -Lines $lines -Heading $placement.after_heading
    }

    $updatedContent = [string]::Join("`n", $lines)
    foreach ($placement in $placements) {
        $updatedContent = Insert-IllustrationAfterHeadingSection `
            -Lines ($updatedContent -split "`r?`n") `
            -ArticleId $articleId `
            -Placement $placement
    }

    if ($newline -eq "`r`n") {
        $updatedContent = $updatedContent -replace "(?<!`r)`n", "`r`n"
    }

    Write-Utf8TextFile -Path $ArticlePath -Content $updatedContent

    Write-Host '[OK] GZHRB article finalized.'
    Write-Host "Article       : $ArticlePath"
    Write-Host "Placement     : $placementPath"
    Write-Host "Illustrations : $articleIllustrationsDir"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbArticleFinalize -ArticlePath $ArticlePath -GzhrbDir $GzhrbDir -IllustrationsRoot $IllustrationsRoot
}
