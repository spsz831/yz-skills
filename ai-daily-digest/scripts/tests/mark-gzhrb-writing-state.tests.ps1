$ErrorActionPreference = 'Stop'

$khazixScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'mark-gzhrb-khazix-complete.ps1'
$wechatScriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'mark-gzhrb-wechat-complete.ps1'

if (-not (Test-Path -LiteralPath $khazixScriptPath)) {
    throw "Script not found: $khazixScriptPath"
}

if (-not (Test-Path -LiteralPath $wechatScriptPath)) {
    throw "Script not found: $wechatScriptPath"
}

. $khazixScriptPath -ArticlePath '__test__'
. $wechatScriptPath -ArticlePath '__test__'

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

function New-TestFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function New-TestFixture {
    $root = Join-Path $env:TEMP ("mark-gzhrb-writing-state-" + [guid]::NewGuid().ToString('N'))
    $gzhrbDir = Join-Path $root 'reports\gzhrb'
    $draftDir = Join-Path $gzhrbDir 'drafts'
    $workitemDir = Join-Path $gzhrbDir 'workitems'
    $articleRoot = Join-Path $gzhrbDir 'articles'
    $approvalRoot = Join-Path $gzhrbDir 'approvals'
    $provenanceRoot = Join-Path $gzhrbDir 'provenance'
    $illustrationRoot = Join-Path $gzhrbDir 'illustrations'
    $publishUnitRoot = Join-Path $gzhrbDir 'publish-units'
    New-Item -ItemType Directory -Force -Path $gzhrbDir, $draftDir, $workitemDir, $articleRoot, $approvalRoot, $provenanceRoot, $illustrationRoot, $publishUnitRoot | Out-Null

    $articleId = 'gzhrb-20260423-1200-topic'
    $articleDir = Join-Path $articleRoot $articleId
    $articlePath = Join-Path $articleDir 'article.md'
    $draftPath = Join-Path $draftDir "$articleId-khazix.md"
    $workitemPath = Join-Path $workitemDir "$articleId.json"
    $approvalDir = Join-Path $approvalRoot $articleId
    $provenanceDir = Join-Path $provenanceRoot $articleId
    $illustrationDir = Join-Path $illustrationRoot $articleId
    $publishUnitDir = Join-Path $publishUnitRoot $articleId

    New-Item -ItemType Directory -Force -Path $articleDir, $approvalDir, $provenanceDir, $illustrationDir, $publishUnitDir | Out-Null

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

function Write-TestWorkitem {
    param(
        [Parameter(Mandatory)]$Fixture,
        [string]$Stage = 'awaiting_khazix_execution'
    )

    $json = [ordered]@{
        stage = $Stage
        article_id = $Fixture.ArticleId
        writing_state = [ordered]@{
            khazix = [ordered]@{
                status = 'pending'
                completed_at = $null
                updated_at = $null
                updated_by = $null
                source_path = $null
            }
            wechat = [ordered]@{
                status = 'pending'
                completed_at = $null
                updated_at = $null
                updated_by = $null
                source_path = $null
            }
        }
        paths = [ordered]@{
            khazix_draft = $Fixture.DraftPath
            optimized_article = $Fixture.ArticlePath
            article_dir = (Split-Path -Parent $Fixture.ArticlePath)
            approval_dir = $Fixture.ApprovalDir
            provenance_dir = $Fixture.ProvenanceDir
            illustration_dir = $Fixture.IllustrationDir
            publish_unit_dir = $Fixture.PublishUnitDir
        }
        execution_log = @()
    } | ConvertTo-Json -Depth 6

    New-TestFile -Path $Fixture.WorkitemPath -Content $json
}

function Write-TestJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    New-TestFile -Path $Path -Content ($Value | ConvertTo-Json -Depth 8)
}

function New-ProvenanceRecord {
    param(
        [Parameter(Mandatory)]$Fixture,
        [Parameter(Mandatory)][string]$SkillName,
        [Parameter(Mandatory)][string]$OutputPath
    )

    return [ordered]@{
        article_id = $Fixture.ArticleId
        skill_name = $SkillName
        session_id = 'test-session'
        input_path = $Fixture.ArticlePath
        output_path = $OutputPath
        started_at = '2026-04-23T10:00:00+08:00'
        completed_at = '2026-04-23T10:05:00+08:00'
        status = 'completed'
    }
}

$khazixFixture = New-TestFixture
Write-TestWorkitem -Fixture $khazixFixture
New-TestFile -Path $khazixFixture.ArticlePath -Content '# target article exists'
New-TestFile -Path $khazixFixture.DraftPath -Content '# real khazix draft'
Write-TestJson -Path (Join-Path $khazixFixture.ProvenanceDir 'khazix-execution.json') -Value (New-ProvenanceRecord -Fixture $khazixFixture -SkillName 'khazix-writer' -OutputPath $khazixFixture.DraftPath)
$result = Set-GzhrbKhazixComplete -ArticlePath $khazixFixture.ArticlePath -WorkitemPath $khazixFixture.WorkitemPath -UpdatedBy 'manual-script'
$workitem = Get-Content -Raw -LiteralPath $khazixFixture.WorkitemPath | ConvertFrom-Json
Assert-Equal $result.stage 'awaiting_khazix_approval' 'Khazix complete should move to khazix approval stage'
Assert-Equal $workitem.writing_state.khazix.status 'completed' 'Khazix status should be completed'
Assert-Equal $workitem.writing_state.khazix.updated_by 'manual-script' 'Khazix updated_by should be recorded'
Assert-Equal $workitem.writing_state.khazix.source_path $khazixFixture.DraftPath 'Khazix source path should be recorded'
Assert-Equal $workitem.execution_log.Count 1 'Khazix complete should append one log entry'
Remove-Item -LiteralPath $khazixFixture.Root -Recurse -Force

$wechatFixture = New-TestFixture
Write-TestWorkitem -Fixture $wechatFixture -Stage 'awaiting_wechat_execution'
New-TestFile -Path $wechatFixture.DraftPath -Content '# real khazix draft'
New-TestFile -Path $wechatFixture.ArticlePath -Content '# real wechat article'
Write-TestJson -Path (Join-Path $wechatFixture.ApprovalDir 'topic-selected.json') -Value ([ordered]@{ approved = $true })
Write-TestJson -Path (Join-Path $wechatFixture.ApprovalDir 'khazix-approved.json') -Value ([ordered]@{ approved = $true })
Write-TestJson -Path (Join-Path $wechatFixture.ProvenanceDir 'khazix-execution.json') -Value (New-ProvenanceRecord -Fixture $wechatFixture -SkillName 'khazix-writer' -OutputPath $wechatFixture.DraftPath)
Write-TestJson -Path (Join-Path $wechatFixture.ProvenanceDir 'wechat-execution.json') -Value (New-ProvenanceRecord -Fixture $wechatFixture -SkillName 'wechat-article-writer' -OutputPath $wechatFixture.ArticlePath)
$preWorkitem = Get-Content -Raw -LiteralPath $wechatFixture.WorkitemPath | ConvertFrom-Json
$preWorkitem.writing_state.khazix.status = 'completed'
$preWorkitem | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $wechatFixture.WorkitemPath -Encoding UTF8
$result = Set-GzhrbWechatComplete -ArticlePath $wechatFixture.ArticlePath -WorkitemPath $wechatFixture.WorkitemPath -UpdatedBy 'codex'
$workitem = Get-Content -Raw -LiteralPath $wechatFixture.WorkitemPath | ConvertFrom-Json
Assert-Equal $result.stage 'awaiting_wechat_approval' 'Wechat complete should move to wechat approval stage'
Assert-Equal $workitem.writing_state.wechat.status 'completed' 'Wechat status should be completed'
Assert-Equal $workitem.writing_state.wechat.updated_by 'codex' 'Wechat updated_by should be recorded'
Assert-Equal $workitem.writing_state.wechat.source_path $wechatFixture.ArticlePath 'Wechat source path should be recorded'
Assert-Equal $workitem.execution_log.Count 1 'Wechat complete should append one log entry'
Remove-Item -LiteralPath $wechatFixture.Root -Recurse -Force

$invalidFixture = New-TestFixture
Write-TestWorkitem -Fixture $invalidFixture
New-TestFile -Path $invalidFixture.ArticlePath -Content '# target article exists'
New-TestFile -Path $invalidFixture.DraftPath -Content "# topic`n`n> khazix-writer 初稿占位文件"
try {
    Set-GzhrbKhazixComplete -ArticlePath $invalidFixture.ArticlePath -WorkitemPath $invalidFixture.WorkitemPath -UpdatedBy 'manual-script'
    throw 'Expected placeholder khazix draft to be rejected.'
} catch {
    Assert-True ($_.Exception.Message.Contains('placeholder')) 'Placeholder khazix draft should be rejected'
}
Remove-Item -LiteralPath $invalidFixture.Root -Recurse -Force

$missingKhazixProvenanceFixture = New-TestFixture
Write-TestWorkitem -Fixture $missingKhazixProvenanceFixture
New-TestFile -Path $missingKhazixProvenanceFixture.ArticlePath -Content '# target article exists'
New-TestFile -Path $missingKhazixProvenanceFixture.DraftPath -Content '# real khazix draft'
try {
    Set-GzhrbKhazixComplete -ArticlePath $missingKhazixProvenanceFixture.ArticlePath -WorkitemPath $missingKhazixProvenanceFixture.WorkitemPath -UpdatedBy 'manual-script'
    throw 'Expected missing khazix provenance to be rejected.'
} catch {
    Assert-True ($_.Exception.Message.Contains('provenance')) 'Khazix complete should require provenance evidence'
}
Remove-Item -LiteralPath $missingKhazixProvenanceFixture.Root -Recurse -Force

$missingWechatProvenanceFixture = New-TestFixture
Write-TestWorkitem -Fixture $missingWechatProvenanceFixture -Stage 'awaiting_wechat_execution'
New-TestFile -Path $missingWechatProvenanceFixture.DraftPath -Content '# real khazix draft'
New-TestFile -Path $missingWechatProvenanceFixture.ArticlePath -Content '# real wechat article'
Write-TestJson -Path (Join-Path $missingWechatProvenanceFixture.ApprovalDir 'topic-selected.json') -Value ([ordered]@{ approved = $true })
Write-TestJson -Path (Join-Path $missingWechatProvenanceFixture.ApprovalDir 'khazix-approved.json') -Value ([ordered]@{ approved = $true })
Write-TestJson -Path (Join-Path $missingWechatProvenanceFixture.ProvenanceDir 'khazix-execution.json') -Value (New-ProvenanceRecord -Fixture $missingWechatProvenanceFixture -SkillName 'khazix-writer' -OutputPath $missingWechatProvenanceFixture.DraftPath)
$preWorkitem = Get-Content -Raw -LiteralPath $missingWechatProvenanceFixture.WorkitemPath | ConvertFrom-Json
$preWorkitem.writing_state.khazix.status = 'completed'
$preWorkitem | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $missingWechatProvenanceFixture.WorkitemPath -Encoding UTF8
try {
    Set-GzhrbWechatComplete -ArticlePath $missingWechatProvenanceFixture.ArticlePath -WorkitemPath $missingWechatProvenanceFixture.WorkitemPath -UpdatedBy 'codex'
    throw 'Expected missing wechat provenance to be rejected.'
} catch {
    Assert-True ($_.Exception.Message.Contains('provenance')) 'Wechat complete should require provenance evidence'
}
Remove-Item -LiteralPath $missingWechatProvenanceFixture.Root -Recurse -Force

Write-Host 'All mark-gzhrb-writing-state tests passed.'
