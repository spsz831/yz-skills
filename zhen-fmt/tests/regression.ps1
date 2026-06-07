Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-HasProperty {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Message
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        throw $Message
    }
}

function Assert-Match {
    param(
        [string]$Value,
        [string]$Pattern,
        [string]$Message
    )

    if ($Value -notmatch $Pattern) {
        throw "$Message`nValue: $Value`nPattern: $Pattern"
    }
}

function Invoke-GenerateScriptJson {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        $psArgs = @(
            "-NoProfile"
            "-ExecutionPolicy"
            "Bypass"
            "-File"
            $ScriptPath
        ) + $ArgumentList

        $proc = Start-Process -FilePath "powershell.exe" `
            -ArgumentList $psArgs `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $stdout = ""
        $stderr = ""
        if (Test-Path -LiteralPath $stdoutPath) {
            $stdout = Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $stderr = Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
        }

        if ($proc.ExitCode -ne 0) {
            throw "generate-image.ps1 failed.`nSTDERR:`n$stderr`nSTDOUT:`n$stdout"
        }

        return $stdout
    }
    finally {
        if (Test-Path -LiteralPath $stdoutPath) {
            Remove-Item -LiteralPath $stdoutPath -Force
        }
        if (Test-Path -LiteralPath $stderrPath) {
            Remove-Item -LiteralPath $stderrPath -Force
        }
    }
}

function Read-Utf8Json {
    param([string]$Path)

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

$scriptRoot = Split-Path -Parent $PSCommandPath
$skillRoot = Split-Path -Parent $scriptRoot
$repoRoot = Split-Path -Parent $skillRoot
$generateScript = Join-Path $skillRoot "scripts\generate-image.ps1"
$defaultsPath = Join-Path $skillRoot "config\defaults.json"
$fixturesPath = Join-Path $scriptRoot "fixtures\requests.json"
$tmpRoot = Join-Path $repoRoot "_tmp_tests"

if (Test-Path -LiteralPath $tmpRoot) {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

try {
    $defaults = Get-Content -LiteralPath $defaultsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $fixtures = Read-Utf8Json -Path $fixturesPath
    $vagueRequest = [string]$fixtures.vague_request
    Assert-True -Condition ([int]$defaults.defaultVariants -eq 3) -Message "defaultVariants should default to 3."

    $vagueArgs = @()
    $vagueArgs += "-Request"
    $vagueArgs += $vagueRequest
    $vagueArgs += "-OutputRoot"
    $vagueArgs += $tmpRoot
    $vagueJson = Invoke-GenerateScriptJson -ScriptPath $generateScript -ArgumentList $vagueArgs
    $vagueResult = $vagueJson | ConvertFrom-Json

    Assert-HasProperty -Object $vagueResult -Name "NeedsConfirmation" -Message "Vague request flow must expose NeedsConfirmation."
    Assert-True -Condition ([bool]$vagueResult.NeedsConfirmation) -Message "Vague requests should require confirmation."
    Assert-HasProperty -Object $vagueResult -Name "PromptChoices" -Message "Vague request flow must expose PromptChoices."
    Assert-True -Condition (@($vagueResult.PromptChoices).Count -eq 3) -Message "Vague request flow should return exactly 3 prompt choices."
    Assert-True -Condition ([string]::IsNullOrWhiteSpace([string]$vagueResult.ImageFile)) -Message "Vague request flow should not render before confirmation."

    $confirmArgs = @()
    $confirmArgs += "-Request"
    $confirmArgs += $vagueRequest
    $confirmArgs += "-ConfirmPromptChoice"
    $confirmArgs += "2"
    $confirmArgs += "-OutputRoot"
    $confirmArgs += $tmpRoot
    $confirmJson = Invoke-GenerateScriptJson -ScriptPath $generateScript -ArgumentList $confirmArgs
    $confirmItems = @()
    $confirmItems = @(($confirmJson | ConvertFrom-Json))

    Assert-True -Condition ($confirmItems.Count -eq 3) -Message "Confirmed render flow should emit 3 variants."
    foreach ($item in $confirmItems) {
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$item.ImageFile)) -Message "Confirmed render flow must save an image file."
        Assert-Match -Value ([string]$item.ImageFile) -Pattern '\\outputs\\\d{4}-\d{2}-\d{2}\\\d{2}\\' -Message "Image output path must include date and hour directories."
        Assert-True -Condition (Test-Path -LiteralPath ([string]$item.ImageFile)) -Message "Rendered image file must exist."
    }

    $pathOnlyArgs = @()
    $pathOnlyArgs += "-Request"
    $pathOnlyArgs += $vagueRequest
    $pathOnlyArgs += "-ConfirmPromptChoice"
    $pathOnlyArgs += "2"
    $pathOnlyArgs += "-PathOnly"
    $pathOnlyArgs += "-OutputRoot"
    $pathOnlyArgs += $tmpRoot
    $pathOnlyJson = Invoke-GenerateScriptJson -ScriptPath $generateScript -ArgumentList $pathOnlyArgs
    $pathOnlyItems = @()
    $pathOnlyItems = @(($pathOnlyJson | ConvertFrom-Json))
    Assert-True -Condition ($pathOnlyItems.Count -eq 3) -Message "PathOnly flow should emit exactly 3 image paths."
    foreach ($pathItem in $pathOnlyItems) {
        Assert-True -Condition (Test-Path -LiteralPath ([string]$pathItem)) -Message "PathOnly flow must return existing image paths."
    }
}
finally {
    if (Test-Path -LiteralPath $tmpRoot) {
        Remove-Item -LiteralPath $tmpRoot -Recurse -Force
    }
}
