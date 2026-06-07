$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assert-True failed: $Message"
    }
}

$digestPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'digest.ts'
$content = Get-Content -LiteralPath $digestPath -Raw

Assert-True ($content.Contains('{ name: "wise.readwise.io", xmlUrl: "https://wise.readwise.io/feed", htmlUrl: "https://wise.readwise.io" }')) 'RSS_FEEDS should include the Readwise Wise Reads feed'
Assert-True ($content.Contains("const HUGGINGFACE_PAPERS_SOURCE_NAME = 'huggingface.co/papers';")) 'digest should define a dedicated Hugging Face Papers source name'
Assert-True ($content.Contains("const HUGGINGFACE_PAPERS_SOURCE_URL = 'https://huggingface.co/papers';")) 'digest should define a dedicated Hugging Face Papers source URL'
Assert-True ($content.Contains('async function fetchHuggingFacePapersLatest(): Promise<FeedFetchResult> {')) 'digest should provide a custom fetcher for Hugging Face Papers'

Write-Host 'All source-catalog tests passed.'
