## OpenAI-compatible batch illustration wrapper.
param(
    [Parameter(Mandatory)][string]$BatchFile,
    [int]$Jobs = 2,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Get-Utf8NoBomEncoding {
    return New-Object System.Text.UTF8Encoding($false)
}

function Read-Utf8TextFile {
    param([Parameter(Mandatory)][string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8TextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Get-OpenAICompatibleApiKey {
    foreach ($name in @(
        'OPENAI_API_KEY',
        'OPENAI_API_TOKEN',
        'APIHUB_OPENAI_API_KEY',
        'LLM_API_KEY'
    )) {
        $value = [string](Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue).Value
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    throw 'Missing OpenAI-compatible API key. Set OPENAI_API_KEY, OPENAI_API_TOKEN, APIHUB_OPENAI_API_KEY, or LLM_API_KEY.'
}

function Get-OpenAICompatibleBaseUrl {
    foreach ($name in @('OPENAI_BASE_URL', 'OPENAI_API_BASE', 'LLM_BASE_URL')) {
        $value = [string](Get-Item -Path "Env:$name" -ErrorAction SilentlyContinue).Value
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.TrimEnd('/')
        }
    }

    return 'https://jiuuij.de5.net/v1'
}

function Invoke-OpenAICompatibleJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Body
    )

    $payload = $Body | ConvertTo-Json -Depth 20 -Compress
    $headers = @{
        Authorization  = "Bearer $(Get-OpenAICompatibleApiKey)"
        'Content-Type' = 'application/json'
    }
    $baseUrl = Get-OpenAICompatibleBaseUrl

    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            return Invoke-RestMethod -Method Post -Uri "$baseUrl$Path" -Headers $headers -Body $payload
        }
        catch {
            $response = $_.Exception.Response
            $statusCode = $null
            $detail = $null

            if ($response) {
                $statusCode = $response.StatusCode.value__
                if ($response.GetResponseStream()) {
                    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
                    $detail = $reader.ReadToEnd()
                }
            }

            $shouldRetry = ($statusCode -eq 503) -or ($_.Exception.Message -like '*connection was closed*')
            if ($attempt -lt $maxAttempts -and $shouldRetry) {
                Start-Sleep -Seconds (5 * $attempt)
                continue
            }

            if ($statusCode) {
                throw ("HTTP {0} from {1}: {2}" -f $statusCode, $Path, $detail)
            }

            throw
        }
    }
}

function Get-PromptTextFromFile {
    param([Parameter(Mandatory)][string]$Path)

    $content = Read-Utf8TextFile -Path $Path
    if ($content.StartsWith("---")) {
        $parts = $content -split "`r?`n---`r?`n", 3
        if ($parts.Count -ge 3) {
            return $parts[2].Trim()
        }
    }

    return $content.Trim()
}

function Extract-ImageUrl {
    param([Parameter(Mandatory)]$Response)

    if ($Response.url) {
        return [string]$Response.url
    }

    if ($Response.image_url) {
        return [string]$Response.image_url
    }

    if ($Response.data -is [System.Collections.IEnumerable]) {
        foreach ($item in $Response.data) {
            if ($item.url) {
                return [string]$item.url
            }
            if ($item.image_url) {
                return [string]$item.image_url
            }
            if ($item.b64_json) {
                return [string]$item.b64_json
            }
        }
    }

    if ($Response.b64_json) {
        return [string]$Response.b64_json
    }

    throw "Image generation response did not contain a URL or base64 payload: $($Response | ConvertTo-Json -Depth 20 -Compress)"
}

function Write-ImageBytes {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    $isBase64 = $Content -match '^[A-Za-z0-9+/=\r\n]+$' -and $Content.Length -gt 100
    if ($isBase64) {
        $bytes = [Convert]::FromBase64String($Content)
        [System.IO.File]::WriteAllBytes($DestinationPath, $bytes)
        return
    }

    Invoke-WebRequest -Uri $Content -OutFile $DestinationPath
}

if (-not (Test-Path -LiteralPath $BatchFile)) {
    throw "Batch file not found: $BatchFile"
}

$batchPath = [System.IO.Path]::GetFullPath($BatchFile)
$batchDir = Split-Path -Parent $batchPath
$batch = Get-Content -Raw -LiteralPath $batchPath | ConvertFrom-Json

if (-not $batch.tasks) {
    throw "Invalid batch file: no tasks found in $BatchFile"
}

$results = New-Object System.Collections.Generic.List[object]

foreach ($task in @($batch.tasks)) {
    $promptTextParts = New-Object System.Collections.Generic.List[string]
    foreach ($promptFile in @($task.promptFiles)) {
        $promptPath = Join-Path $batchDir $promptFile
        if (-not (Test-Path -LiteralPath $promptPath)) {
            throw "Prompt file not found: $promptPath"
        }

        $promptTextParts.Add((Get-PromptTextFromFile -Path $promptPath))
    }

    $prompt = ($promptTextParts -join "`n`n").Trim()
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        throw "Prompt is empty for task $($task.id)"
    }

    $imageModel = if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_IMAGE_MODEL)) { $env:OPENAI_IMAGE_MODEL } else { 'gpt-image-2' }
    $size = if ($task.ar -eq '16:9') { '2560x1440' } else { '1024x1024' }
    $body = @{
        model = $imageModel
        prompt = $prompt
        size = $size
    }

    $response = Invoke-OpenAICompatibleJson -Path '/images/generations' -Body $body
    $imagePayload = Extract-ImageUrl -Response $response
    $targetPath = Join-Path $batchDir $task.image
    Write-ImageBytes -Content $imagePayload -DestinationPath $targetPath

    $results.Add([pscustomobject]@{
        id = $task.id
        image = $task.image
        prompt_used = $prompt
        payload = if ($imagePayload.Length -gt 120) { $imagePayload.Substring(0, 120) + '...' } else { $imagePayload }
    })
}

if ($Json) {
    $results | ConvertTo-Json -Depth 20
}
else {
    Write-Host "[OK] Generated $($results.Count) illustration(s) with gpt-image-2."
    foreach ($item in $results) {
        Write-Host ("{0} -> {1}" -f $item.id, $item.image)
    }
}
