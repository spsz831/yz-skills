param(
    [int]$Last = 7,
    [string]$HealthDir,
    [string]$OutputPath
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
        [Parameter(Mandatory)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Get-RecentHealthLogs {
    param(
        [Parameter(Mandatory)][string]$HealthDir,
        [Parameter(Mandatory)][int]$Last
    )

    if (-not (Test-Path -LiteralPath $HealthDir)) {
        throw "Health directory not found: $HealthDir"
    }

    if ($Last -le 0) {
        throw "Last must be a positive integer."
    }

    $logs = Get-ChildItem -LiteralPath $HealthDir -Filter 'run-*.json' -File |
        Sort-Object `
            @{ Expression = { $_.LastWriteTime }; Descending = $true }, `
            @{ Expression = { $_.FullName }; Descending = $true } |
        Select-Object -First $Last

    if (-not $logs -or $logs.Count -eq 0) {
        throw "No health logs found in: $HealthDir"
    }

    return @($logs)
}

function Read-HealthPayload {
    param([Parameter(Mandatory)][string]$Path)

    $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
        if ($null -ne $parsed) {
            return $parsed
        }
    }
    catch {
    }

    $lines = Get-Content -Encoding UTF8 -LiteralPath $Path
    $entries = @()
    $current = $null
    $inEntries = $false

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if (-not $inEntries) {
            if ($trimmed -match '^"entries"\s*:\s*\[$') {
                $inEntries = $true
            }
            continue
        }

        if ($trimmed -eq '{') {
            $current = [ordered]@{}
            continue
        }

        if ($trimmed -eq '}' -or $trimmed -eq '},') {
            if ($null -ne $current -and $current.Contains('sourceName') -and $current.Contains('status')) {
                $articleCount = 0
                $errorCode = ''
                $xmlUrl = ''
                $sourceUrl = ''

                if ($current.Contains('articleCount')) {
                    $articleCount = [int]$current['articleCount']
                }
                if ($current.Contains('errorCode')) {
                    $errorCode = [string]$current['errorCode']
                }
                if ($current.Contains('xmlUrl')) {
                    $xmlUrl = [string]$current['xmlUrl']
                }
                if ($current.Contains('sourceUrl')) {
                    $sourceUrl = [string]$current['sourceUrl']
                }

                $entries += [pscustomobject]@{
                    sourceName = [string]$current['sourceName']
                    xmlUrl = $xmlUrl
                    sourceUrl = $sourceUrl
                    status = [string]$current['status']
                    articleCount = $articleCount
                    errorCode = $errorCode
                }
            }
            $current = $null
            continue
        }

        if ($trimmed -eq ']' -or $trimmed -eq '],') {
            break
        }

        if ($null -eq $current) {
            continue
        }

        if ($trimmed -match '^"([^"]+)"\s*:\s*"((?:\\.|[^"])*)"\s*,?$') {
            $name = $matches[1]
            $value = $matches[2]
            $value = [System.Text.RegularExpressions.Regex]::Unescape($value)
            $current[$name] = $value
            continue
        }

        if ($trimmed -match '^"([^"]+)"\s*:\s*(-?\d+)\s*,?$') {
            $current[$matches[1]] = [int]$matches[2]
            continue
        }
    }

    if (@($entries).Count -gt 0) {
        return [pscustomobject]@{
            entries = @($entries)
        }
    }

    throw "Health log is empty or invalid: $Path"
}

function New-SourceBucket {
    return [ordered]@{
        sourceName = ''
        xmlUrl = ''
        sourceUrl = ''
        total = 0
        ok = 0
        empty = 0
        error = 0
        timeout = 0
        http_403 = 0
        http_429 = 0
        http_other = 0
        network = 0
        other = 0
    }
}

function Get-Rate {
    param(
        [int]$Value,
        [int]$Total
    )

    if ($Total -le 0) {
        return 0
    }

    return [Math]::Round(($Value * 100.0) / $Total, 1)
}

function Get-HealthSummary {
    param([Parameter(Mandatory)][object[]]$Payloads)

    $sourceMap = @{}
    $totals = [ordered]@{
        logs = $Payloads.Count
        totalFeeds = 0
        ok = 0
        empty = 0
        error = 0
    }

    foreach ($payload in $Payloads) {
        $entries = @($payload.entries)
        foreach ($entry in $entries) {
            $sourceName = [string]$entry.sourceName
            if ([string]::IsNullOrWhiteSpace($sourceName)) {
                $sourceName = [string]$entry.xmlUrl
            }
            if ([string]::IsNullOrWhiteSpace($sourceName)) {
                $sourceName = 'unknown-source'
            }

            if (-not $sourceMap.ContainsKey($sourceName)) {
                $bucket = New-SourceBucket
                $bucket.sourceName = $sourceName
                $bucket.xmlUrl = [string]$entry.xmlUrl
                $bucket.sourceUrl = [string]$entry.sourceUrl
                $sourceMap[$sourceName] = $bucket
            }

            $bucket = $sourceMap[$sourceName]
            $bucket.total++
            $totals.totalFeeds++

            switch ([string]$entry.status) {
                'ok' {
                    $bucket.ok++
                    $totals.ok++
                }
                'empty' {
                    $bucket.empty++
                    $totals.empty++
                }
                'error' {
                    $bucket.error++
                    $totals.error++

                    $errorCode = [string]$entry.errorCode
                    switch ($errorCode) {
                        'timeout' { $bucket.timeout++ }
                        'http_403' { $bucket.http_403++ }
                        'http_429' { $bucket.http_429++ }
                        'http_other' { $bucket.http_other++ }
                        'network' { $bucket.network++ }
                        default { $bucket.other++ }
                    }
                }
                default {
                    $bucket.other++
                }
            }
        }
    }

    $sources = foreach ($item in $sourceMap.GetEnumerator()) {
        [pscustomobject]$item.Value
    }

    return [pscustomobject]@{
        Totals  = [pscustomobject]$totals
        Sources = @($sources | Sort-Object `
            @{ Expression = { $_.error }; Descending = $true }, `
            @{ Expression = { $_.timeout + $_.http_403 + $_.http_429 + $_.http_other + $_.network + $_.other }; Descending = $true }, `
            @{ Expression = { $_.sourceName } })
    }
}

function Get-SourceRecommendation {
    param([Parameter(Mandatory)][object]$Source)

    $total = [int]$Source.total
    $ok = [int]$Source.ok
    $error = [int]$Source.error
    $empty = [int]$Source.empty
    $timeout = [int]$Source.timeout
    $http403 = [int]$Source.http_403
    $http429 = [int]$Source.http_429
    $httpOther = [int]$Source.http_other
    $network = [int]$Source.network
    $other = [int]$Source.other

    if ($http403 -ge 2 -and $ok -eq 0) {
        return [pscustomobject]@{
            Level = 'disable'
            Reason = "Repeated HTTP 403 ($http403 times) with no successful runs in the current window"
        }
    }

    if (($timeout + $network) -ge 3 -and $ok -eq 0) {
        return [pscustomobject]@{
            Level = 'disable'
            Reason = "Repeated timeout/network failures ($($timeout + $network) times) with no successful runs in the current window"
        }
    }

    if (($httpOther + $other) -ge 3 -and $ok -eq 0) {
        return [pscustomobject]@{
            Level = 'disable'
            Reason = "Repeated non-transient failures ($($httpOther + $other) times) with no successful runs in the current window"
        }
    }

    if ($error -ge 2 -or $empty -ge 3 -or (Get-Rate -Value $ok -Total $total) -lt 60) {
        $reasonParts = New-Object System.Collections.Generic.List[string]
        if ($error -ge 2) {
            $reasonParts.Add("errors=$error")
        }
        if ($empty -ge 3) {
            $reasonParts.Add("empty=$empty")
        }
        if ((Get-Rate -Value $ok -Total $total) -lt 60) {
            $reasonParts.Add("ok-rate=$(Get-Rate -Value $ok -Total $total)%")
        }

        return [pscustomobject]@{
            Level = 'observe'
            Reason = ($reasonParts -join '; ')
        }
    }

    return [pscustomobject]@{
        Level = 'keep'
        Reason = "healthy in the current window ($ok/$total successful runs)"
    }
}

function Format-SourceLine {
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter(Mandatory)][object]$Recommendation
    )

    $parts = @(
        "- ``$($Source.sourceName)``",
        "total ``$($Source.total)``",
        "ok ``$($Source.ok)``",
        "empty ``$($Source.empty)``",
        "error ``$($Source.error)``"
    )

    $errorBreakdown = @()
    foreach ($code in @('timeout', 'http_403', 'http_429', 'http_other', 'network', 'other')) {
        $value = [int]$Source.$code
        if ($value -gt 0) {
            $errorBreakdown += "$code=$value"
        }
    }

    if ($errorBreakdown.Count -gt 0) {
        $parts += "errors ``$($errorBreakdown -join ', ')``"
    }

    $parts += "recommendation: $($Recommendation.Reason)"
    return ($parts -join ' | ')
}

function Build-HealthAnalysisMarkdown {
    param(
        [Parameter(Mandatory)][object[]]$Logs,
        [Parameter(Mandatory)][object]$Summary,
        [Parameter(Mandatory)][string]$HealthDir
    )

    $disableLines = New-Object System.Collections.Generic.List[string]
    $observeLines = New-Object System.Collections.Generic.List[string]
    $keepLines = New-Object System.Collections.Generic.List[string]
    $detailLines = New-Object System.Collections.Generic.List[string]

    foreach ($source in $Summary.Sources) {
        $recommendation = Get-SourceRecommendation -Source $source
        $line = Format-SourceLine -Source $source -Recommendation $recommendation
        $detailLines.Add($line)

        switch ($recommendation.Level) {
            'disable' { $disableLines.Add($line) }
            'observe' { $observeLines.Add($line) }
            default { $keepLines.Add($line) }
        }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# AI Digest Health Analysis')
    $lines.Add('')
    $lines.Add("Generated at: ``$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')``")
    $lines.Add("Health dir: ``$HealthDir``")
    $lines.Add("Logs analyzed: ``$($Logs.Count)``")
    $lines.Add('')
    $lines.Add('## Overview')
    $lines.Add('')
    $lines.Add("- Total sampled source records: ``$($Summary.Totals.totalFeeds)``")
    $lines.Add("- OK: ``$($Summary.Totals.ok)``")
    $lines.Add("- Empty: ``$($Summary.Totals.empty)``")
    $lines.Add("- Error: ``$($Summary.Totals.error)``")
    $lines.Add('')
    $lines.Add('## Suggested Disable')
    $lines.Add('')
    if ($disableLines.Count -eq 0) {
        $lines.Add('- No sources crossed the disable threshold in the current window.')
    } else {
        foreach ($line in $disableLines) { $lines.Add($line) }
    }
    $lines.Add('')
    $lines.Add('## Suggested Observe')
    $lines.Add('')
    if ($observeLines.Count -eq 0) {
        $lines.Add('- No sources crossed the observe threshold in the current window.')
    } else {
        foreach ($line in $observeLines) { $lines.Add($line) }
    }
    $lines.Add('')
    $lines.Add('## Keep')
    $lines.Add('')
    if ($keepLines.Count -eq 0) {
        $lines.Add('- No sources qualified as stable keepers in the current window.')
    } else {
        foreach ($line in $keepLines) { $lines.Add($line) }
    }
    $lines.Add('')
    $lines.Add('## Full Details')
    $lines.Add('')
    foreach ($line in $detailLines) { $lines.Add($line) }
    $lines.Add('')
    $lines.Add('## Sampled Logs')
    $lines.Add('')
    foreach ($log in $Logs) {
        $lines.Add("- ``$($log.FullName)``")
    }
    $lines.Add('')

    return ($lines -join "`r`n")
}

function Start-AiDigestHealthAnalysis {
    $projectDir = Get-ProjectDir

    if ([string]::IsNullOrWhiteSpace($HealthDir)) {
        $HealthDir = Join-Path $projectDir 'reports\health'
    }

    $logs = Get-RecentHealthLogs -HealthDir $HealthDir -Last $Last
    $payloads = @()
    foreach ($log in $logs) {
        $payloads += Read-HealthPayload -Path $log.FullName
    }

    $summary = Get-HealthSummary -Payloads $payloads

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $ts = Get-Date -Format 'yyyyMMdd-HHmm'
        $OutputPath = Join-Path $HealthDir "health-analysis-$ts.md"
    }

    $markdown = Build-HealthAnalysisMarkdown -Logs $logs -Summary $summary -HealthDir $HealthDir
    Write-Utf8TextFile -Path $OutputPath -Content $markdown

    Write-Host '[OK] AI digest health analysis generated.'
    Write-Host "Logs analyzed : $($logs.Count)"
    Write-Host "Output report : $OutputPath"
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-AiDigestHealthAnalysis
}
