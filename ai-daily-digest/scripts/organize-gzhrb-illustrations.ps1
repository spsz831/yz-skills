param(
    [string]$ArticlePath,
    [string]$GzhrbDir,
    [string]$IllustrationsRoot
)

$ErrorActionPreference = 'Stop'

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Get-LatestGzhrbPath {
    param([Parameter(Mandatory)][string]$GzhrbDir)

    $latest = Get-ChildItem -LiteralPath $GzhrbDir -Filter 'gzhrb-*.md' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "No GZHRB article found in: $GzhrbDir"
    }

    return $latest.FullName
}

function Get-ArticleIllustrationId {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
    if ($fileName -eq 'article') {
        $parentDir = Split-Path -Parent $ArticlePath
        return Split-Path -Leaf $parentDir
    }

    return $fileName
}

function Get-DirectIllustrationFiles {
    param([Parameter(Mandatory)][string]$Content)

    $matches = [regex]::Matches($Content, '!\[[^\]]*\]\(illustrations/([^)]+)\)')
    $files = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $relative = $match.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($relative)) { continue }
        if ($relative.Contains('/') -or $relative.Contains('\')) { continue }
        $files.Add($relative)
    }

    return $files | Select-Object -Unique
}

function Move-IfPresent {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return $false
    }

    if (Test-Path -LiteralPath $TargetPath) {
        return $false
    }

    Move-Item -LiteralPath $SourcePath -Destination $TargetPath
    return $true
}

function Root-OutlineBelongsToArticle {
    param(
        [Parameter(Mandatory)][string]$OutlinePath,
        [Parameter(Mandatory)][string]$ArticlePath
    )

    if (-not (Test-Path -LiteralPath $OutlinePath)) {
        return $false
    }

    $content = Get-Content -Raw -LiteralPath $OutlinePath
    $fileName = Split-Path -Leaf $ArticlePath

    return $content.Contains($ArticlePath) -or $content.Contains($fileName)
}

function Read-Utf8File {
    param([Parameter(Mandatory)][string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Test-PlacementArticleMatch {
    param(
        [AllowNull()]$Value,
        [Parameter(Mandatory)][string]$ArticleId,
        [Parameter(Mandatory)][string]$ArticlePath
    )

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $fileName = Split-Path -Leaf $ArticlePath
    if ($text -eq $ArticleId -or $text -eq $fileName -or $text -eq $ArticlePath) {
        return $true
    }

    return $false
}

function Root-PlacementBelongsToArticle {
    param(
        [Parameter(Mandatory)][string]$PlacementPath,
        [Parameter(Mandatory)][string]$ArticlePath,
        [string[]]$DirectFiles = @()
    )

    if (-not (Test-Path -LiteralPath $PlacementPath)) {
        return $false
    }

    $articleId = Get-ArticleIllustrationId -ArticlePath $ArticlePath
    $content = Read-Utf8File -Path $PlacementPath
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $false
    }

    try {
        $placement = ConvertFrom-Json -InputObject $content -ErrorAction Stop
    }
    catch {
        return $false
    }

    $articleMatch = Test-PlacementArticleMatch -Value $placement.article -ArticleId $articleId -ArticlePath $ArticlePath
    if ($null -ne $articleMatch) {
        return $articleMatch
    }

    $articleMatch = Test-PlacementArticleMatch -Value $placement.article_id -ArticleId $articleId -ArticlePath $ArticlePath
    if ($null -ne $articleMatch) {
        return $articleMatch
    }

    $articleMatch = Test-PlacementArticleMatch -Value $placement.articlePath -ArticleId $articleId -ArticlePath $ArticlePath
    if ($null -ne $articleMatch) {
        return $articleMatch
    }

    $articleMatch = Test-PlacementArticleMatch -Value $placement.article_path -ArticleId $articleId -ArticlePath $ArticlePath
    if ($null -ne $articleMatch) {
        return $articleMatch
    }

    $records = @()
    if ($placement -is [System.Collections.IEnumerable] -and -not ($placement -is [string])) {
        foreach ($record in $placement) {
            $records += $record
        }
    }
    else {
        $records = @($placement)
    }

    if ($records.Count -eq 0 -or $DirectFiles.Count -eq 0) {
        return $false
    }

    foreach ($record in $records) {
        if ($null -eq $record) {
            return $false
        }

        $imageName = [string]$record.image
        if ([string]::IsNullOrWhiteSpace($imageName)) {
            return $false
        }

        $leafName = Split-Path -Leaf $imageName
        if ($DirectFiles -notcontains $leafName) {
            return $false
        }
    }

    return $true
}

function Remove-EmptyDirectory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $items = Get-ChildItem -LiteralPath $Path -Force
    if ($items.Count -eq 0) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Assert-DirectIllustrationFilesResolvable {
    param(
        [string[]]$Files = @(),
        [Parameter(Mandatory)][string]$IllustrationsRoot,
        [Parameter(Mandatory)][string]$TargetDir,
        [Parameter(Mandatory)][string]$ArticlePath
    )

    foreach ($file in $Files) {
        $sourceImage = Join-Path $IllustrationsRoot $file
        $targetImage = Join-Path $TargetDir $file
        if ((-not (Test-Path -LiteralPath $sourceImage)) -and (-not (Test-Path -LiteralPath $targetImage))) {
            throw "Illustration asset missing for article '$ArticlePath': $file. Expected at '$sourceImage' or '$targetImage'."
        }
    }
}

function Start-GzhrbIllustrationOrganize {
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

    $articleId = Get-ArticleIllustrationId -ArticlePath $ArticlePath
    $targetDir = Join-Path $IllustrationsRoot $articleId
    $targetPromptsDir = Join-Path $targetDir 'prompts'
    $rootPromptsDir = Join-Path $IllustrationsRoot 'prompts'
    $rootOutlinePath = Join-Path $IllustrationsRoot 'outline.md'
    $rootBatchPath = Join-Path $IllustrationsRoot 'batch.json'
    $rootPlacementPath = Join-Path $IllustrationsRoot 'placement.json'

    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    New-Item -ItemType Directory -Force -Path $targetPromptsDir | Out-Null

    $articleContent = Read-Utf8File -Path $ArticlePath
    $directFiles = @(Get-DirectIllustrationFiles -Content $articleContent)

    $movedImages = 0
    $movedPrompts = 0

    foreach ($file in $directFiles) {
        $sourceImage = Join-Path $IllustrationsRoot $file
        $targetImage = Join-Path $targetDir $file
        if (Move-IfPresent -SourcePath $sourceImage -TargetPath $targetImage) {
            $movedImages++
        }

        $promptName = [System.IO.Path]::ChangeExtension($file, '.md')
        $sourcePrompt = Join-Path $rootPromptsDir $promptName
        $targetPrompt = Join-Path $targetPromptsDir $promptName
        if (Move-IfPresent -SourcePath $sourcePrompt -TargetPath $targetPrompt) {
            $movedPrompts++
        }
    }

    $movedOutline = $false
    $movedBatch = $false
    $movedPlacement = $false
    if (Root-OutlineBelongsToArticle -OutlinePath $rootOutlinePath -ArticlePath $ArticlePath) {
        $movedOutline = Move-IfPresent -SourcePath $rootOutlinePath -TargetPath (Join-Path $targetDir 'outline.md')
        $movedBatch = Move-IfPresent -SourcePath $rootBatchPath -TargetPath (Join-Path $targetDir 'batch.json')
    }

    if (Root-PlacementBelongsToArticle -PlacementPath $rootPlacementPath -ArticlePath $ArticlePath -DirectFiles $directFiles) {
        $movedPlacement = Move-IfPresent -SourcePath $rootPlacementPath -TargetPath (Join-Path $targetDir 'placement.json')
    }

    if ($directFiles.Count -gt 0) {
        Assert-DirectIllustrationFilesResolvable -Files $directFiles -IllustrationsRoot $IllustrationsRoot -TargetDir $targetDir -ArticlePath $ArticlePath

        foreach ($file in $directFiles) {
            $escaped = [regex]::Escape("](illustrations/$file)")
            $replacement = "](illustrations/$articleId/$file)"
            $articleContent = [regex]::Replace($articleContent, $escaped, $replacement)
        }

        Write-Utf8File -Path $ArticlePath -Content $articleContent
    }

    Remove-EmptyDirectory -Path $rootPromptsDir

    Write-Host '[OK] GZHRB illustration assets organized.'
    Write-Host "Article        : $ArticlePath"
    Write-Host "Target dir     : $targetDir"
    Write-Host "Images moved   : $movedImages"
    Write-Host "Prompts moved  : $movedPrompts"
    Write-Host "Outline moved  : $movedOutline"
    Write-Host "Batch moved    : $movedBatch"
    Write-Host "Placement moved: $movedPlacement"
    Write-Host "Refs rewritten : $($directFiles.Count)"
    Write-Host "Saved article  : $ArticlePath"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbIllustrationOrganize
}
