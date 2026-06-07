param(
    [string]$ArticlePath
)

$ErrorActionPreference = 'Stop'

$validatorScriptPath = Join-Path $PSScriptRoot 'validate-gzhrb-writing-state.ps1'
if (-not (Test-Path -LiteralPath $validatorScriptPath)) {
    throw "Required script not found: $validatorScriptPath"
}

. $validatorScriptPath

function Get-ProjectDir {
    return Split-Path -Parent $PSScriptRoot
}

function Get-ArticleIdForWorkitem {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $resolvedArticlePath = [System.IO.Path]::GetFullPath($ArticlePath)
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedArticlePath)
    if ([string]::Equals($fileName, 'article', [System.StringComparison]::OrdinalIgnoreCase)) {
        return [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($resolvedArticlePath))
    }

    return $fileName
}

function Resolve-WorkitemPathForArticle {
    param([Parameter(Mandatory)][string]$ArticlePath)

    $projectDir = Get-ProjectDir
    $articleId = Get-ArticleIdForWorkitem -ArticlePath $ArticlePath
    return Join-Path $projectDir "reports\gzhrb\workitems\$articleId.json"
}

function Invoke-Stage {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$ArticlePath
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Required script not found: $ScriptPath"
    }

    Write-Host ""
    Write-Host "[INFO] Running $Name ..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -ArticlePath $ArticlePath
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed. Exit code: $LASTEXITCODE"
    }
}

function Get-WechatGateFailures {
    param([Parameter(Mandatory)]$Validation)

    $failures = New-Object System.Collections.Generic.List[string]
    $hasWechatArticle = Test-Path -LiteralPath $Validation.optimized_article_path
    if (-not $hasWechatArticle -or ($Validation.missing_evidence.files -contains 'wechat_article')) {
        $failures.Add('wechat article file missing or empty')
    }

    if ($null -eq $Validation.provenance_state.wechat_execution -or -not $Validation.provenance_state.wechat_execution.valid) {
        $failures.Add('wechat provenance missing or invalid')
    }

    if ($null -eq $Validation.approval_state -or -not [bool]$Validation.approval_state.wechat_approved) {
        $failures.Add('wechat approval missing')
    }

    return @($failures)
}

function Start-GzhrbPostwritingPipeline {
    param(
        [string]$ArticlePath
    )

    if ([string]::IsNullOrWhiteSpace($ArticlePath)) {
        throw 'Article path is required.'
    }

    if (-not (Test-Path -LiteralPath $ArticlePath)) {
        throw "Article not found: $ArticlePath"
    }

    $projectDir = Get-ProjectDir
    $workitemPath = Resolve-WorkitemPathForArticle -ArticlePath $ArticlePath
    $validation = Get-GzhrbWritingStateValidation -ArticlePath $ArticlePath -WorkitemPath $workitemPath
    $wechatGateFailures = Get-WechatGateFailures -Validation $validation

    if (-not $validation.is_ready_for_postwriting -or $wechatGateFailures.Count -gt 0) {
        $gateSummary = if ($wechatGateFailures.Count -gt 0) {
            $wechatGateFailures -join '; '
        } else {
            'wechat gate already satisfied'
        }

        throw @"
Post-writing pipeline blocked.
Current stage : $($validation.stage)
Reason        : $($validation.reason)
Wechat gate   : $gateSummary
Next step     : $($validation.next_step)
Workitem      : $($validation.workitem_path)
"@
    }

    Invoke-Stage -Name 'illustration planning' -ScriptPath (Join-Path $projectDir 'scripts\plan-gzhrb-illustrations.ps1') -ArticlePath $ArticlePath
    Invoke-Stage -Name 'illustration generation' -ScriptPath (Join-Path $projectDir 'scripts\generate-gzhrb-illustrations.ps1') -ArticlePath $ArticlePath
    Invoke-Stage -Name 'illustration organize' -ScriptPath (Join-Path $projectDir 'scripts\organize-gzhrb-illustrations.ps1') -ArticlePath $ArticlePath
    Invoke-Stage -Name 'article finalization' -ScriptPath (Join-Path $projectDir 'scripts\finalize-gzhrb-article.ps1') -ArticlePath $ArticlePath
    Invoke-Stage -Name 'publish packaging' -ScriptPath (Join-Path $projectDir 'scripts\package-gzhrb-article.ps1') -ArticlePath $ArticlePath

    Write-Host ""
    Write-Host "[OK] Post-writing pipeline completed."
    Write-Host "Article: $ArticlePath"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-GzhrbPostwritingPipeline -ArticlePath $ArticlePath
}
