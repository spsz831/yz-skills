param(
    [string]$ArticlePath,
    [string]$SkillName,
    [string]$InputPath,
    [string]$OutputPath,
    [string]$SessionId,
    [string]$Status = 'completed',
    [string]$Note
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

function Get-ArticleIdFromPath {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
    if ($fileName -eq 'article') {
        $parentDir = Split-Path -Parent $ArticlePath
        return Split-Path -Leaf $parentDir
    }

    return $fileName
}

function Get-ProvenanceFileName {
    param([Parameter(Mandatory)][string]$SkillName)

    switch ($SkillName) {
        'khazix-writer' { return 'khazix-execution.json' }
        'wechat-article-writer' { return 'wechat-execution.json' }
        'baoyu-article-illustrator' { return 'illustration-execution.json' }
        default { throw "Unsupported skill name for provenance: $SkillName" }
    }
}

function Write-GzhrbProvenance {
    param(
        [Parameter(Mandatory)][string]$ArticlePath,
        [Parameter(Mandatory)][string]$SkillName,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [string]$SessionId,
        [string]$Status = 'completed',
        [string]$Note
    )

    $projectDir = Get-ProjectDir
    $articleId = Get-ArticleIdFromPath -ArticlePath $ArticlePath
    $provenanceDir = Join-Path $projectDir "reports\gzhrb\provenance\$articleId"
    $fileName = Get-ProvenanceFileName -SkillName $SkillName
    $path = Join-Path $provenanceDir $fileName
    $timestamp = (Get-Date).ToString('o')

    New-Item -ItemType Directory -Force -Path $provenanceDir | Out-Null

    $payload = [ordered]@{
        article_id = $articleId
        skill_name = $SkillName
        session_id = $SessionId
        input_path = $InputPath
        output_path = $OutputPath
        started_at = $timestamp
        completed_at = $timestamp
        status = $Status
        note = $Note
    }

    Write-Utf8TextFile -Path $path -Content ($payload | ConvertTo-Json -Depth 5)

    return [pscustomobject]@{
        article_id = $articleId
        skill_name = $SkillName
        path = $path
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    foreach ($required in @('ArticlePath', 'SkillName', 'InputPath', 'OutputPath')) {
        if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $required -ValueOnly))) {
            throw "Missing required parameter: $required"
        }
    }

    Write-GzhrbProvenance `
        -ArticlePath $ArticlePath `
        -SkillName $SkillName `
        -InputPath $InputPath `
        -OutputPath $OutputPath `
        -SessionId $SessionId `
        -Status $Status `
        -Note $Note | ConvertTo-Json -Depth 5
}
