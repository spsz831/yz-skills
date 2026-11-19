[CmdletBinding()]
param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$userProfile = [Environment]::GetFolderPath('UserProfile')
$targets = @(
    [pscustomobject]@{
        Source = Join-Path $repositoryRoot 'SKILL.md'
        Destinations = @(
            (Join-Path $userProfile '.codex\skills\ai-daily-digest\SKILL.md'),
            (Join-Path $userProfile '.agents\skills\ai-daily-digest\SKILL.md')
        )
    },
    [pscustomobject]@{
        Source = Join-Path $repositoryRoot 'docs\skills\ai-yang-detective-content-pipeline\SKILL.md'
        Destinations = @(
            (Join-Path $userProfile '.codex\skills\ai-yang-detective-content-pipeline\SKILL.md'),
            (Join-Path $userProfile '.agents\skills\ai-yang-detective-content-pipeline\SKILL.md'),
            (Join-Path $userProfile '.codex\skills\ai-daily-digest\docs\skills\ai-yang-detective-content-pipeline\SKILL.md')
        )
    }
)

$drifted = @()

foreach ($target in $targets) {
    $sourceHash = (Get-FileHash -LiteralPath $target.Source -Algorithm SHA256).Hash
    foreach ($destination in $target.Destinations) {
        $isCurrent = (Test-Path -LiteralPath $destination) -and
            ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $sourceHash)

        if ($Check) {
            $status = if ($isCurrent) { 'OK' } else { 'DRIFT' }
            Write-Output "[$status] $destination"
            if (-not $isCurrent) {
                $drifted += $destination
            }
            continue
        }

        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $target.Source -Destination $destination -Force
        Write-Output "[SYNCED] $destination"
    }
}

if ($Check -and $drifted.Count -gt 0) {
    exit 1
}
