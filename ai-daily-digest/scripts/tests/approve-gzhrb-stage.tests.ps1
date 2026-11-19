$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'approve-gzhrb-stage.ps1')
function Assert-Equal($Actual, $Expected, [string]$Message) { if ($Actual -ne $Expected) { throw "$Message. Expected '$Expected', got '$Actual'." } }
function Write-TestFile([string]$Path, [string]$Content) { New-Item -ItemType Directory -Force (Split-Path -Parent $Path) | Out-Null; [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false))) }
function Write-TestJson([string]$Path, $Value) { Write-TestFile $Path ($Value | ConvertTo-Json -Depth 8) }
$root = Join-Path $env:TEMP ('gzhrb-modern-approval-' + [guid]::NewGuid().ToString('N')); $id='approval-test'; $base=Join-Path $root 'reports\gzhrb'
$article=Join-Path $base "articles\$id\article.md"; $draft=Join-Path $base "drafts\$id-wechat-draft.md"; $workitem=Join-Path $base "workitems\$id.json"; $approval=Join-Path $base "approvals\$id"; $provenance=Join-Path $base "provenance\$id"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $article), (Split-Path -Parent $draft), (Split-Path -Parent $workitem), $approval, $provenance | Out-Null
Write-TestFile $article '# article'
$payload=[ordered]@{stage='awaiting_topic_approval';article_id=$id;writing_state=[ordered]@{wechat_draft=[ordered]@{status='pending'};wechat_refine=[ordered]@{status='pending'};humanizer=[ordered]@{status='pending'}};paths=[ordered]@{wechat_draft=$draft;optimized_article=$article;approval_dir=$approval;provenance_dir=$provenance}}
Write-TestJson $workitem $payload
$result=Set-GzhrbStageApproval -ArticlePath $article -WorkitemPath $workitem -Stage topic_selected -ApprovedBy tester
Assert-Equal $result.stage 'awaiting_wechat_draft_execution' 'Topic approval should enter wechat draft stage'
Write-TestFile $draft '# draft'; Write-TestJson (Join-Path $provenance 'wechat-draft-execution.json') ([ordered]@{skill_name='wechat-article-writer';status='completed';output_path=$draft})
$json=Get-Content $workitem -Raw | ConvertFrom-Json; $json.stage='awaiting_wechat_draft_approval'; Write-TestJson $workitem $json
$result=Set-GzhrbStageApproval -ArticlePath $article -WorkitemPath $workitem -Stage wechat_draft_approved -ApprovedBy tester
Assert-Equal $result.stage 'awaiting_wechat_refinement_execution' 'Draft approval should enter refinement stage'
Write-TestFile $article '# refined'; Write-TestJson (Join-Path $provenance 'humanizer-execution.json') ([ordered]@{skill_name='humanizer-zh';status='completed';output_path=$article})
$json=Get-Content $workitem -Raw | ConvertFrom-Json; $json.stage='awaiting_writing_approval'; Write-TestJson $workitem $json
$result=Set-GzhrbStageApproval -ArticlePath $article -WorkitemPath $workitem -Stage writing_approved -ApprovedBy tester
Assert-Equal $result.stage 'awaiting_illustration_execution' 'Writing approval should open illustration stage'
Remove-Item $root -Recurse -Force
Write-Host 'All modern approval tests passed.'
