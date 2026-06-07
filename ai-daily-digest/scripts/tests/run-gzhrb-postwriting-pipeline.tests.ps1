$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'run-gzhrb-postwriting-pipeline.ps1'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
}

. $scriptPath -ArticlePath '__test__'

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

function Write-TestFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, (New-Utf8NoBomEncoding))
}

function Write-TestJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 8
    Write-TestFile -Path $Path -Content $json
}

function New-TestFixture {
    $root = Join-Path $env:TEMP ("gzhrb-postwriting-test-" + [guid]::NewGuid().ToString('N'))
    $articleId = "gzhrb-test-" + [guid]::NewGuid().ToString('N')

    $gzhrbDir = Join-Path $root 'reports\gzhrb'
    $articleDir = Join-Path $gzhrbDir "articles\$articleId"
    $articlePath = Join-Path $articleDir 'article.md'
    $draftPath = Join-Path $gzhrbDir "drafts\$articleId-khazix.md"
    $workitemPath = Join-Path $gzhrbDir "workitems\$articleId.json"
    $approvalDir = Join-Path $gzhrbDir "approvals\$articleId"
    $provenanceDir = Join-Path $gzhrbDir "provenance\$articleId"
    $illustrationDir = Join-Path $gzhrbDir "illustrations\$articleId"
    $publishUnitDir = Join-Path $gzhrbDir "publish-units\$articleId"

    New-Item -ItemType Directory -Force -Path $articleDir, (Split-Path -Parent $draftPath), (Split-Path -Parent $workitemPath), $approvalDir, $provenanceDir, $illustrationDir, $publishUnitDir | Out-Null

    Write-TestFile -Path $articlePath -Content '# wechat article'
    Write-TestFile -Path $draftPath -Content '# khazix draft'

    return [pscustomobject]@{
        Root = $root
        ArticleId = $articleId
        ArticlePath = $articlePath
        DraftPath = $draftPath
        WorkitemPath = $workitemPath
        ApprovalDir = $approvalDir
        ProvenanceDir = $provenanceDir
        IllustrationDir = $illustrationDir
        PublishUnitDir = $publishUnitDir
    }
}

function Remove-TestFixture {
    param([Parameter(Mandatory)]$Fixture)

    if (Test-Path -LiteralPath $Fixture.Root) {
        Remove-Item -LiteralPath $Fixture.Root -Recurse -Force
    }
}

function Write-TestWorkitem {
    param(
        [Parameter(Mandatory)]$Fixture,
        [string]$Stage = 'awaiting_illustration_execution'
    )

    $record = [ordered]@{
        article_id = $Fixture.ArticleId
        stage = $Stage
        paths = [ordered]@{
            khazix_draft = $Fixture.DraftPath
            optimized_article = $Fixture.ArticlePath
            approval_dir = $Fixture.ApprovalDir
            provenance_dir = $Fixture.ProvenanceDir
            illustration_dir = $Fixture.IllustrationDir
            publish_unit_dir = $Fixture.PublishUnitDir
        }
    }

    Write-TestJson -Path $Fixture.WorkitemPath -Value $record
}

function Write-Approval {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$FileName
    )

    Write-TestJson -Path (Join-Path $Fixture.ApprovalDir $FileName) -Value ([ordered]@{
            approved = $true
            approved_at = (Get-Date).ToString('o')
        })
}

function Write-Provenance {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$SkillName,
        [Parameter(Mandatory)][string]$OutputPath
    )

    Write-TestJson -Path (Join-Path $Fixture.ProvenanceDir $FileName) -Value ([ordered]@{
            article_id = $Fixture.ArticleId
            skill_name = $SkillName
            output_path = $OutputPath
            status = 'completed'
        })
}

function Prepare-WechatReadyEvidence {
    param([Parameter(Mandatory)]$Fixture)

    Write-TestWorkitem -Fixture $Fixture
    Write-Approval -Fixture $Fixture -FileName 'topic-selected.json'
    Write-Approval -Fixture $Fixture -FileName 'khazix-approved.json'
    Write-TestFile -Path $Fixture.DraftPath -Content '# real khazix draft'
    Write-Provenance -Fixture $Fixture -FileName 'khazix-execution.json' -SkillName 'khazix-writer' -OutputPath $Fixture.DraftPath
    Write-Provenance -Fixture $Fixture -FileName 'wechat-execution.json' -SkillName 'wechat-article-writer' -OutputPath $Fixture.ArticlePath
}

$script:TestProjectDir = $null
$script:RecordedStages = @()

function Get-ProjectDir {
    return $script:TestProjectDir
}

function Invoke-Stage {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string]$ArticlePath
    )

    $script:RecordedStages += [pscustomobject]@{
        Name = $Name
        ScriptPath = $ScriptPath
        ArticlePath = $ArticlePath
    }
}

$missingWechatApproval = New-TestFixture
$script:TestProjectDir = $missingWechatApproval.Root
$script:RecordedStages = @()
Prepare-WechatReadyEvidence -Fixture $missingWechatApproval
try {
    Start-GzhrbPostwritingPipeline -ArticlePath $missingWechatApproval.ArticlePath
    throw 'Expected missing wechat approval fixture to be blocked.'
} catch {
    Assert-True ($_.Exception.Message.Contains('Post-writing pipeline blocked.')) 'Should block when wechat approval is missing'
    Assert-True ($_.Exception.Message.Contains('wechat')) 'Error should mention wechat-related gate'
}
Assert-Equal $script:RecordedStages.Count 0 'Should not run any stage when gate is blocked by missing wechat approval'
Remove-TestFixture -Fixture $missingWechatApproval

$missingWechatProvenance = New-TestFixture
$script:TestProjectDir = $missingWechatProvenance.Root
$script:RecordedStages = @()
Prepare-WechatReadyEvidence -Fixture $missingWechatProvenance
Remove-Item -LiteralPath (Join-Path $missingWechatProvenance.ProvenanceDir 'wechat-execution.json') -Force
Write-Approval -Fixture $missingWechatProvenance -FileName 'wechat-approved.json'
try {
    Start-GzhrbPostwritingPipeline -ArticlePath $missingWechatProvenance.ArticlePath
    throw 'Expected missing wechat provenance fixture to be blocked.'
} catch {
    Assert-True ($_.Exception.Message.Contains('Post-writing pipeline blocked.')) 'Should block when wechat provenance is missing'
    Assert-True ($_.Exception.Message.Contains('wechat')) 'Error should mention wechat-related gate'
}
Assert-Equal $script:RecordedStages.Count 0 'Should not run any stage when gate is blocked by missing wechat provenance'
Remove-TestFixture -Fixture $missingWechatProvenance

$readyFixture = New-TestFixture
$script:TestProjectDir = $readyFixture.Root
$script:RecordedStages = @()
Prepare-WechatReadyEvidence -Fixture $readyFixture
Write-Approval -Fixture $readyFixture -FileName 'wechat-approved.json'
Start-GzhrbPostwritingPipeline -ArticlePath $readyFixture.ArticlePath
Assert-Equal $script:RecordedStages.Count 5 'Should run all post-writing stages when wechat file, provenance, and approval exist'
Assert-Equal $script:RecordedStages[0].Name 'illustration planning' 'Should run illustration planning first'
Assert-Equal $script:RecordedStages[4].Name 'publish packaging' 'Should run publish packaging last'
Remove-TestFixture -Fixture $readyFixture

Write-Host 'All run-gzhrb-postwriting-pipeline tests passed.'
