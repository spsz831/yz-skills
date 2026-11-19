$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'validate-gzhrb-writing-state.ps1')

function Assert-Equal($Actual, $Expected, [string]$Message) { if ($Actual -ne $Expected) { throw "$Message. Expected '$Expected', got '$Actual'." } }
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-TestFile([string]$Path, [string]$Content) { New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false))) }
function Write-TestJson([string]$Path, $Value) { Write-TestFile $Path ($Value | ConvertTo-Json -Depth 8) }
function New-Fixture {
    $root = Join-Path $env:TEMP ('gzhrb-modern-state-' + [guid]::NewGuid().ToString('N'))
    $id = 'gzhrb-test-modern'
    $base = Join-Path $root 'reports\gzhrb'
    $paths = [ordered]@{
        article = Join-Path $base "articles\$id\article.md"
        draft = Join-Path $base "drafts\$id-wechat-draft.md"
        workitem = Join-Path $base "workitems\$id.json"
        approval = Join-Path $base "approvals\$id"
        provenance = Join-Path $base "provenance\$id"
        illustration = Join-Path $base "illustrations\$id"
        publish = Join-Path $base "publish-units\$id"
    }
    New-Item -ItemType Directory -Force -Path $paths.approval,$paths.provenance,$paths.illustration,$paths.publish | Out-Null
    Write-TestFile $paths.article '# article identity'
    $workitem = [ordered]@{ workflow='ai-yang-detective-content-pipeline'; article_id=$id; stage='awaiting_topic_approval'; writing_state=[ordered]@{ wechat_draft=[ordered]@{status='pending'}; wechat_refine=[ordered]@{status='pending'}; humanizer=[ordered]@{status='pending'} }; paths=[ordered]@{ wechat_draft=$paths.draft; optimized_article=$paths.article; approval_dir=$paths.approval; provenance_dir=$paths.provenance; illustration_dir=$paths.illustration; publish_unit_dir=$paths.publish }; execution_log=@() }
    Write-TestJson $paths.workitem $workitem
    return [pscustomobject]$paths
}
function Approve($Fixture, [string]$Name) { Write-TestJson (Join-Path $Fixture.approval "$Name.json") ([ordered]@{ approved=$true }) }
function Provenance($Fixture, [string]$Name, [string]$Skill, [string]$Output) { Write-TestJson (Join-Path $Fixture.provenance $Name) ([ordered]@{ skill_name=$Skill; status='completed'; output_path=$Output }) }

$f = New-Fixture
$r = Get-GzhrbWritingStateValidation $f.article $f.workitem
Assert-Equal $r.stage 'awaiting_topic_approval' 'New workitem should wait for topic approval'
Approve $f 'topic-selected'
Write-TestFile $f.draft '# first draft'
Provenance $f 'wechat-draft-execution.json' 'wechat-article-writer' $f.draft
$r = Get-GzhrbWritingStateValidation $f.article $f.workitem
Assert-Equal $r.stage 'awaiting_wechat_draft_approval' 'Draft evidence should wait for human inspection'
Approve $f 'wechat-draft-approved'
Write-TestFile $f.article '# refined article'
Provenance $f 'wechat-refine-execution.json' 'wechat-article-writer' $f.article
$r = Get-GzhrbWritingStateValidation $f.article $f.workitem
Assert-Equal $r.stage 'awaiting_humanizer_execution' 'Refined article should wait for humanizer evidence'
Provenance $f 'humanizer-execution.json' 'humanizer-zh' $f.article
$r = Get-GzhrbWritingStateValidation $f.article $f.workitem
Assert-Equal $r.stage 'awaiting_writing_approval' 'Humanized article should wait for final writing approval'
Approve $f 'writing-approved'
$r = Get-GzhrbWritingStateValidation $f.article $f.workitem
Assert-Equal $r.stage 'awaiting_illustration_execution' 'Final writing approval should open illustration stage'
Assert-True ($r.provenance_state.humanizer_execution.valid) 'Humanizer provenance should be valid'
Remove-Item -LiteralPath $f.workitem -Force
Remove-Item -LiteralPath (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $f.workitem))) -Recurse -Force
Write-Host 'All modern writing-state validation tests passed.'
