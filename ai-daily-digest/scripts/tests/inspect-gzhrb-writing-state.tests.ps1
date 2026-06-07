$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'inspect-gzhrb-writing-state.ps1'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Script not found: $scriptPath"
}

. $scriptPath -ArticlePath '__test__'

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

function New-TestJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    New-TestFile -Path $Path -Content ($Value | ConvertTo-Json -Depth 8)
}

function New-TestFixture {
    param([string]$Name)

    $root = Join-Path $env:TEMP ("inspect-gzhrb-writing-state-$Name-" + [guid]::NewGuid().ToString('N'))
    $gzhrbDir = Join-Path $root 'reports\gzhrb'
    $workitemDir = Join-Path $gzhrbDir 'workitems'
    $draftDir = Join-Path $gzhrbDir 'drafts'
    $articleRoot = Join-Path $gzhrbDir 'articles'
    $approvalRoot = Join-Path $gzhrbDir 'approvals'
    $provenanceRoot = Join-Path $gzhrbDir 'provenance'
    $illustrationRoot = Join-Path $gzhrbDir 'illustrations'
    $publishUnitRoot = Join-Path $gzhrbDir 'publish-units'

    New-Item -ItemType Directory -Force -Path $gzhrbDir, $workitemDir, $draftDir, $articleRoot, $approvalRoot, $provenanceRoot, $illustrationRoot, $publishUnitRoot | Out-Null

    $articleId = 'gzhrb-20260423-1200-topic'
    $articlePath = Join-Path $gzhrbDir "$articleId.md"
    $draftPath = Join-Path $draftDir "$articleId-khazix.md"
    $articleDir = Join-Path $articleRoot $articleId
    $optimizedArticlePath = Join-Path $articleDir 'article.md'
    $approvalDir = Join-Path $approvalRoot $articleId
    $provenanceDir = Join-Path $provenanceRoot $articleId
    $illustrationDir = Join-Path $illustrationRoot $articleId
    $publishUnitDir = Join-Path $publishUnitRoot $articleId
    $workitemPath = Join-Path $workitemDir "$articleId.json"

    New-Item -ItemType Directory -Force -Path $articleDir, $approvalDir, $provenanceDir, $illustrationDir, $publishUnitDir | Out-Null
    New-TestFile -Path $articlePath -Content '# article identity'
    New-TestFile -Path $draftPath -Content '# khazix draft'
    New-TestFile -Path $optimizedArticlePath -Content '# wechat article'
    New-TestJson -Path (Join-Path $provenanceDir 'khazix-execution.json') -Value ([ordered]@{
        article_id = $articleId
        skill_name = 'khazix-writer'
        output_path = $draftPath
        status = 'completed'
    })

    return [pscustomobject]@{
        Root = $root
        ArticlePath = $articlePath
        WorkitemPath = $workitemPath
        DraftPath = $draftPath
        OptimizedArticlePath = $optimizedArticlePath
        ApprovalDir = $approvalDir
        ProvenanceDir = $provenanceDir
        IllustrationDir = $illustrationDir
        PublishUnitDir = $publishUnitDir
    }
}

function Write-TestWorkitem {
    param(
        [Parameter(Mandatory)]$Fixture,
        [string]$Stage
    )

    New-TestJson -Path $Fixture.WorkitemPath -Value ([ordered]@{
        stage = $Stage
        writing_state = [ordered]@{
            khazix = [ordered]@{
                status = 'completed'
                completed_at = '2026-04-23T18:00:00+08:00'
                updated_at = '2026-04-23T18:00:00+08:00'
                updated_by = 'manual-script'
                source_path = $Fixture.DraftPath
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
            optimized_article = $Fixture.OptimizedArticlePath
            article_dir = (Split-Path -Parent $Fixture.OptimizedArticlePath)
            approval_dir = $Fixture.ApprovalDir
            provenance_dir = $Fixture.ProvenanceDir
            illustration_dir = $Fixture.IllustrationDir
            publish_unit_dir = $Fixture.PublishUnitDir
        }
        execution_log = @(
            [ordered]@{
                timestamp = '2026-04-23T18:00:00+08:00'
                action = 'mark_khazix_complete'
                stage_after = 'awaiting_khazix_approval'
                updated_by = 'manual-script'
            }
        )
    })
}

$missingEvidenceFixture = New-TestFixture -Name 'missing-evidence'
Write-TestWorkitem -Fixture $missingEvidenceFixture -Stage 'awaiting_wechat_execution'
New-TestJson -Path (Join-Path $missingEvidenceFixture.ApprovalDir 'topic-selected.json') -Value ([ordered]@{
    approved = $true
})
New-TestJson -Path (Join-Path $missingEvidenceFixture.ApprovalDir 'khazix-approved.json') -Value ([ordered]@{
    approved = $true
})
$report = Get-GzhrbWritingStateReport -ArticlePath $missingEvidenceFixture.ArticlePath -WorkitemPath $missingEvidenceFixture.WorkitemPath

Assert-True ($report.Contains('Topic approval')) 'Report should include topic approval status'
Assert-True ($report.Contains('Khazix provenance')) 'Report should include khazix provenance status'
Assert-True ($report.Contains('Wechat provenance')) 'Report should include wechat provenance status'
Assert-True ($report.Contains('Illustration approval')) 'Report should include illustration approval status'
Assert-True ($report.Contains('Missing files')) 'Report should include missing file evidence section'
Assert-True ($report.Contains('Missing provenance')) 'Report should include missing provenance evidence section'
Assert-True ($report.Contains('Missing approvals')) 'Report should include missing approval evidence section'
Assert-True ($report.Contains('wechat_execution')) 'Report should print missing wechat provenance key'
Assert-True ($report.Contains('manual-script')) 'Report should include execution log content'

Remove-Item -LiteralPath $missingEvidenceFixture.Root -Recurse -Force

$completedFixture = New-TestFixture -Name 'completed'
Write-TestWorkitem -Fixture $completedFixture -Stage 'completed'
New-TestJson -Path (Join-Path $completedFixture.ApprovalDir 'topic-selected.json') -Value ([ordered]@{ approved = $true })
New-TestJson -Path (Join-Path $completedFixture.ApprovalDir 'khazix-approved.json') -Value ([ordered]@{ approved = $true })
New-TestJson -Path (Join-Path $completedFixture.ApprovalDir 'wechat-approved.json') -Value ([ordered]@{ approved = $true })
New-TestJson -Path (Join-Path $completedFixture.ApprovalDir 'illustrations-approved.json') -Value ([ordered]@{ approved = $true })
New-TestJson -Path (Join-Path $completedFixture.ProvenanceDir 'wechat-execution.json') -Value ([ordered]@{
    skill_name = 'wechat-article-writer'
    output_path = $completedFixture.OptimizedArticlePath
    status = 'completed'
})
New-TestJson -Path (Join-Path $completedFixture.ProvenanceDir 'illustration-execution.json') -Value ([ordered]@{
    skill_name = 'baoyu-article-illustrator'
    output_path = $completedFixture.IllustrationDir
    status = 'completed'
})
New-TestJson -Path (Join-Path $completedFixture.IllustrationDir 'placement.json') -Value ([ordered]@{ slots = @('cover') })
New-TestJson -Path (Join-Path $completedFixture.IllustrationDir 'batch.json') -Value ([ordered]@{ images = @('cover.png') })
New-TestFile -Path (Join-Path $completedFixture.IllustrationDir 'outline.md') -Content '# outline'
New-Item -ItemType Directory -Force -Path (Join-Path $completedFixture.IllustrationDir 'prompts') | Out-Null
New-TestFile -Path (Join-Path $completedFixture.IllustrationDir 'cover.png') -Content 'fake-png'
New-TestFile -Path (Join-Path $completedFixture.PublishUnitDir 'article.md') -Content '# packaged article'
New-TestFile -Path (Join-Path $completedFixture.PublishUnitDir 'titles.txt') -Content 'title-a'
New-TestFile -Path (Join-Path $completedFixture.PublishUnitDir 'intro-lines.txt') -Content 'intro-a'
New-TestFile -Path (Join-Path $completedFixture.PublishUnitDir 'topic-tags.txt') -Content '#tag'
New-TestJson -Path (Join-Path $completedFixture.PublishUnitDir 'package.json') -Value ([ordered]@{ ok = $true })
New-TestFile -Path (Join-Path $completedFixture.PublishUnitDir 'review-checklist.md') -Content '- [ ] review'
New-Item -ItemType Directory -Force -Path (Join-Path $completedFixture.PublishUnitDir 'illustrations') | Out-Null

$completedReport = Get-GzhrbWritingStateReport -ArticlePath $completedFixture.ArticlePath -WorkitemPath $completedFixture.WorkitemPath
Assert-True ($completedReport.Contains('Evidence stage         : completed')) 'Completed report should include completed evidence stage'
Assert-True ($completedReport.Contains('Missing files          : <none>')) 'Completed report should have no missing files'
Assert-True ($completedReport.Contains('Missing provenance     : <none>')) 'Completed report should have no missing provenance'
Assert-True ($completedReport.Contains('Missing approvals      : <none>')) 'Completed report should have no missing approvals'

Remove-Item -LiteralPath $completedFixture.Root -Recurse -Force

Write-Host 'All inspect-gzhrb-writing-state tests passed.'
