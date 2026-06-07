param(
    [Parameter(Mandatory = $false)]
    [string]$Request,

    [Parameter(Mandatory = $false)]
    [string]$OutputRoot = $(if ($env:ZHEN_FMT_OUTPUT_ROOT) { $env:ZHEN_FMT_OUTPUT_ROOT } else { "" }),

    [Parameter(Mandatory = $false)]
    [string]$Model = $(if ($env:ZHEN_FMT_GEMINI_MODEL) { $env:ZHEN_FMT_GEMINI_MODEL } else { "" }),

    [Parameter(Mandatory = $false)]
    [int]$Variants = 0,

    [Parameter(Mandatory = $false)]
    [string]$Seed,

    [Parameter(Mandatory = $false)]
    [string]$ReferenceImage,

    [Parameter(Mandatory = $false)]
    [int]$ConfirmPromptChoice = 0,

    [switch]$PathOnly,

    [switch]$SaveDebugArtifacts,

    [switch]$PromptOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::Expect100Continue = $false

if ([string]::IsNullOrWhiteSpace($Request)) {
    throw "Provide -Request."
}

function Get-ScriptRoot {
    if ($PSCommandPath) {
        return Split-Path -Parent $PSCommandPath
    }

    return Split-Path -Parent $MyInvocation.MyCommand.Definition
}

function Read-JsonConfig {
    param([string]$Path)

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Read-TextFile {
    param([string]$Path)

    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8
}

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name,
        $Fallback = $null
    )

    if ($null -eq $Config) {
        return $Fallback
    }

    $prop = $Config.PSObject.Properties[$Name]
    if ($null -ne $prop -and $null -ne $prop.Value -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
        return $prop.Value
    }

    return $Fallback
}

function Get-ApiKey {
    if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY }
    if ($env:GOOGLE_API_KEY) { return $env:GOOGLE_API_KEY }
    return $null
}

function Get-ScaledDimensions {
    param(
        [int]$Width,
        [int]$Height,
        [int]$MaxWidth,
        [int]$MaxHeight
    )

    if ($Width -le $MaxWidth -and $Height -le $MaxHeight) {
        return @{ Width = $Width; Height = $Height }
    }

    $ratioX = [double]$MaxWidth / [double]$Width
    $ratioY = [double]$MaxHeight / [double]$Height
    $ratio = [Math]::Min($ratioX, $ratioY)

    return @{
        Width = [Math]::Max(1, [int][Math]::Round($Width * $ratio))
        Height = [Math]::Max(1, [int][Math]::Round($Height * $ratio))
    }
}

function Convert-ReferenceImageToUploadBytes {
    param([string]$Path)

    Add-Type -AssemblyName System.Drawing
    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        $target = Get-ScaledDimensions -Width $image.Width -Height $image.Height -MaxWidth 1600 -MaxHeight 1600
        if ($target.Width -eq $image.Width -and $target.Height -eq $image.Height) {
            return [System.IO.File]::ReadAllBytes($Path)
        }

        $bitmap = New-Object System.Drawing.Bitmap($target.Width, $target.Height)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.DrawImage($image, 0, 0, $target.Width, $target.Height)
            }
            finally {
                $graphics.Dispose()
            }

            $stream = New-Object System.IO.MemoryStream
            try {
                $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" } | Select-Object -First 1
                $qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
                $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
                $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, 88L)
                $bitmap.Save($stream, $codec, $encoderParams)
                return $stream.ToArray()
            }
            finally {
                $stream.Dispose()
            }
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $image.Dispose()
    }
}

function Get-ScaledTargetSize {
    param(
        [int]$Width,
        [int]$Height,
        [int]$TargetWidth,
        [int]$TargetHeight
    )

    return @{
        Width = [Math]::Max(1, $TargetWidth)
        Height = [Math]::Max(1, $TargetHeight)
    }
}

function Get-OutputExtension {
    param([string]$Format)

    switch ($Format.ToLowerInvariant()) {
        "jpg" { return ".jpg" }
        "jpeg" { return ".jpg" }
        "png" { return ".png" }
        default { throw "Unsupported output format: $Format" }
    }
}

function Save-BitmapWithFormat {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path,
        [string]$Format,
        [int]$JpegQuality
    )

    $normalized = $Format.ToLowerInvariant()
    if ($normalized -eq "png") {
        $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        return
    }

    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" } | Select-Object -First 1
    $qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, [long]$JpegQuality)
    $Bitmap.Save($Path, $codec, $encoderParams)
}

function Invoke-ImageFinalize {
    param(
        [string]$Path,
        [int]$TargetWidth,
        [int]$TargetHeight,
        [string]$OutputFormat,
        [int]$JpegQuality
    )

    Add-Type -AssemblyName System.Drawing
    $source = [System.Drawing.Image]::FromFile($Path)
    try {
        $target = Get-ScaledTargetSize -Width $source.Width -Height $source.Height -TargetWidth $TargetWidth -TargetHeight $TargetHeight
        $bitmap = New-Object System.Drawing.Bitmap($target.Width, $target.Height)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.Clear([System.Drawing.Color]::Black)

                $srcRatio = [double]$source.Width / [double]$source.Height
                $dstRatio = [double]$target.Width / [double]$target.Height
                $srcX = 0
                $srcY = 0
                $srcW = $source.Width
                $srcH = $source.Height

                if ($srcRatio -gt $dstRatio) {
                    $srcW = [int][Math]::Round($source.Height * $dstRatio)
                    $srcX = [int][Math]::Floor(($source.Width - $srcW) / 2)
                }
                elseif ($srcRatio -lt $dstRatio) {
                    $srcH = [int][Math]::Round($source.Width / $dstRatio)
                    $srcY = [int][Math]::Floor(($source.Height - $srcH) / 2)
                }

                $destRect = New-Object System.Drawing.Rectangle(0, 0, $target.Width, $target.Height)
                $srcRect = New-Object System.Drawing.Rectangle($srcX, $srcY, $srcW, $srcH)
                $graphics.DrawImage($source, $destRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $graphics.Dispose()
            }

            $extension = Get-OutputExtension -Format $OutputFormat
            $tempPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Path), ([System.IO.Path]::GetFileNameWithoutExtension($Path) + ".final.tmp" + $extension))
            Save-BitmapWithFormat -Bitmap $bitmap -Path $tempPath -Format $OutputFormat -JpegQuality $JpegQuality
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
    }
    $finalPath = [System.IO.Path]::ChangeExtension($Path, (Get-OutputExtension -Format $OutputFormat))
    if (Test-Path -LiteralPath $finalPath) {
        Remove-Item -LiteralPath $finalPath -Force
    }
    Move-Item -LiteralPath $tempPath -Destination $finalPath -Force
    return $finalPath
}

function Read-ReferenceImagePart {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Reference image not found: $Path"
    }

    $bytes = Convert-ReferenceImageToUploadBytes -Path $Path
    return @{
        inlineData = @{
            mimeType = "image/jpeg"
            data = [Convert]::ToBase64String($bytes)
        }
    }
}

function Get-HashBytes {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $sha.Dispose()
    }
}

function Select-FromPool {
    param(
        [byte[]]$Bytes,
        [int]$Offset,
        [object[]]$Pool
    )

    if ($Pool.Count -eq 0) {
        throw "Pool cannot be empty."
    }

    return $Pool[$Bytes[$Offset % $Bytes.Length] % $Pool.Count]
}

function Convert-ToSlug {
    param(
        [string]$Text,
        [int]$MaxLength = 32
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "request"
    }

    $normalized = $Text.ToLowerInvariant()
    $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", "-")
    $normalized = [regex]::Replace($normalized, "-{2,}", "-").Trim("-")

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $normalized = -join ($bytes | Select-Object -First 8 | ForEach-Object { $_.ToString("x2") })
    }

    if ($normalized.Length -gt $MaxLength) {
        $normalized = $normalized.Substring(0, $MaxLength).Trim("-")
    }

    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return "request"
    }

    return $normalized
}

function Get-SeedLabel {
    param(
        [string]$ResolvedSeed,
        [object]$DefaultsConfig
    )

    if (-not [string]::IsNullOrWhiteSpace($ResolvedSeed)) {
        return Convert-ToSlug -Text $ResolvedSeed -MaxLength 16
    }

    return Convert-ToSlug -Text ([string](Get-ConfigValue -Config $DefaultsConfig -Name "defaultSeedLabel" -Fallback "auto")) -MaxLength 16
}

function Test-IsVagueRequest {
    param(
        [string]$ScriptRoot,
        [string]$RequestText
    )

    $text = ""
    if ($null -ne $RequestText) {
        $text = $RequestText.Trim()
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $true
    }

    $rulesPath = Join-Path (Split-Path -Parent $ScriptRoot) "config\vague-request-rules.json"
    $rules = Read-JsonConfig -Path $rulesPath

    foreach ($pattern in @($rules.genericPatterns)) {
        if ($text -eq [string]$pattern) {
            return $true
        }
    }

    $hasScene = $false
    foreach ($keyword in @($rules.sceneKeywords)) {
        if ($text.Contains([string]$keyword)) { $hasScene = $true; break }
    }

    $hasMood = $false
    foreach ($keyword in @($rules.moodKeywords)) {
        if ($text.Contains([string]$keyword)) { $hasMood = $true; break }
    }

    $hasTime = $false
    foreach ($keyword in @($rules.timeKeywords)) {
        if ($text.Contains([string]$keyword)) { $hasTime = $true; break }
    }

    $hasAction = $false
    foreach ($keyword in @($rules.actionKeywords)) {
        if ($text.Contains([string]$keyword)) { $hasAction = $true; break }
    }

    $score = 0
    if ($hasScene) { $score++ }
    if ($hasMood) { $score++ }
    if ($hasTime) { $score++ }
    if ($hasAction) { $score++ }

    return ($score -lt 2)
}

function Get-PromptChoices {
    param(
        [string]$ScriptRoot,
        [string]$RequestText,
        [object]$DefaultsConfig
    )

    $styleName = [string](Get-ConfigValue -Config (Get-ConfigValue -Config $DefaultsConfig -Name "seriesStyle") -Name "styleNameZh" -Fallback "personal atmospheric anime style")
    $presetPath = Join-Path (Split-Path -Parent $ScriptRoot) "config\prompt-choice-presets.json"
    $presets = Read-JsonConfig -Path $presetPath
    $choices = @($presets | ForEach-Object {
        [pscustomobject]@{
            Choice = [int]$_.choice
            Title = [string]$_.title
            Prompt = ([string]$_.promptTemplate).Replace("{styleName}", $styleName)
        }
    })

    $ranked = @()
    foreach ($choice in $choices) {
        $score = 0
        if ($RequestText.Contains("室内") -or $RequestText.Contains("窗边") -or $RequestText.Contains("阅读")) {
            if ($choice.Choice -eq 1) { $score += 3 }
        }
        if ($RequestText.Contains("海边") -or $RequestText.Contains("黄昏") -or $RequestText.Contains("微风")) {
            if ($choice.Choice -eq 2) { $score += 3 }
        }
        if ($RequestText.Contains("城市") -or $RequestText.Contains("夜晚") -or $RequestText.Contains("电影感")) {
            if ($choice.Choice -eq 3) { $score += 3 }
        }

        $ranked += [pscustomobject]@{
            Choice = $choice.Choice
            Title = $choice.Title
            Prompt = $choice.Prompt
            RankScore = $score
        }
    }

    $sorted = @($ranked | Sort-Object RankScore -Descending)
    $output = @()
    foreach ($item in $sorted) {
        $output += [pscustomobject]@{
            Choice = $item.Choice
            Title = $item.Title
            Prompt = $item.Prompt
        }
    }

    return $output
}

function Get-ModelPath {
    param([string]$ModelName)

    if ($ModelName -match "/") {
        return $ModelName
    }

    return "models/$ModelName"
}

function Use-CleanBaseName {
    param(
        [string]$RunId,
        [string]$RequestSlug,
        [string]$SeedLabel,
        [int]$VariantIndex
    )

    return "image-$RunId-$RequestSlug-s$SeedLabel-v{0:d2}" -f $VariantIndex
}

function Get-IdentityProfile {
    param([object]$DefaultsConfig)

    $profile = Get-ConfigValue -Config $DefaultsConfig -Name "identityProfile"
    if ($null -eq $profile) {
        throw "defaults.json must define identityProfile."
    }

    return [ordered]@{
        face = [string](Get-ConfigValue -Config $profile -Name "face" -Fallback "")
        eyes = [string](Get-ConfigValue -Config $profile -Name "eyes" -Fallback "")
        hair = [string](Get-ConfigValue -Config $profile -Name "hair" -Fallback "")
        body = [string](Get-ConfigValue -Config $profile -Name "body" -Fallback "")
        aura = [string](Get-ConfigValue -Config $profile -Name "aura" -Fallback "")
    }
}

function Get-PromptModuleTemplate {
    param(
        [string]$ScriptRoot,
        [string]$ModuleName
    )

    $modulePath = Join-Path (Split-Path -Parent $ScriptRoot) "prompt-modules\$ModuleName.txt"
    if (-not (Test-Path -LiteralPath $modulePath)) {
        throw "Prompt module not found: $modulePath"
    }

    return Read-TextFile -Path $modulePath
}

function Expand-Template {
    param(
        [string]$Template,
        [hashtable]$Tokens
    )

    $expanded = $Template
    foreach ($key in $Tokens.Keys) {
        $expanded = $expanded.Replace("{$key}", [string]$Tokens[$key])
    }

    return $expanded.Trim()
}

function Build-Prompt {
    param(
        [string]$ScriptRoot,
        [string]$RequestText,
        [string]$ResolvedDate,
        [string]$RunId,
        [int]$VariantIndex,
        [string]$ResolvedSeed,
        [object]$DefaultsConfig
    )

    $seedText = "$ResolvedDate|$RequestText|$VariantIndex|$ResolvedSeed"
    $bytes = Get-HashBytes -Text $seedText

    $scenes = @(
        "a quiet rooftop edge with a concrete railing, restrained rooftop structures, and a distant skyline silhouette",
        "a rooftop platform with simple architectural foreground elements, open sky, and distant city outlines",
        "a calm waterside roof deck with a low guardrail, minimal urban forms, and readable midground structure",
        "a harbor-side platform with restrained industrial silhouettes, open water, and calm evening structure",
        "a quiet upper-level platform with distant lights, broad sky, and restrained architectural framing",
        "an overlook walkway with minimal barriers, layered distance, and a broad evening sky",
        "a hillside observatory path with low walls, distant city glow, and a broad layered sky",
        "a quiet room beside a large window with soft daylight and restrained furniture",
        "a calm reading corner with natural light, clean interior structure, and gentle spatial depth",
        "a quiet cafe corner with a window seat, soft daylight, and minimal background detail",
        "a quiet library aisle or reading table with warm daylight and controlled perspective depth",
        "a simple bedroom corner with soft morning light, clean bedding, and airy stillness",
        "a tree-lined residential street with quiet daylight and low-density environmental detail",
        "a calm seaside walkway with open horizon, gentle wind, and sparse visual structure",
        "a quiet garden path with soft natural light, foliage depth, and restrained composition",
        "a train-side or bus-window travel moment with simple interior framing and distant scenery"
    )

    $actions = @(
        "standing with a quiet self-possessed stillness, one shoulder slightly turned",
        "walking slowly with an effortless and free-spirited posture",
        "turning slightly as if she has just paused during a quiet walk",
        "leaning lightly against a simple support with relaxed confidence",
        "resting in a composed seated pose in a natural everyday posture",
        "standing in a subtle half-turn with an unhurried, observant mood",
        "reading quietly with calm concentration",
        "sitting by the window with a relaxed inward focus"
    )

    $moods = @(
        "quiet, restrained, and reflective",
        "cool, relaxed, and slightly aloof",
        "elegant, understated, and gently melancholic",
        "serene, spacious, and quietly luminous",
        "detached, moody, and cinematic",
        "still, observant, and lightly adventurous"
    )

    $primaryPalettes = @(
        "deep blue-gray",
        "dark navy and slate",
        "indigo-blue",
        "blue-black",
        "steel blue and charcoal",
        "smoky blue-gray"
    )

    $accentPalettes = @(
        "soft dusty rose highlights",
        "faint peach-orange sunset haze",
        "low-saturation ember-red glow",
        "restrained amber haze and a soft lifted horizon",
        "pearl-gray sky and a diluted rose afterglow",
        "dim crimson accents"
    )

    $positions = @(
        "placed on the left third of the frame with balanced surrounding space",
        "placed on the right third of the frame with balanced surrounding space",
        "placed near the center with restrained surrounding negative space"
    )

    $timeStates = @(
        "late dusk",
        "blue hour",
        "the last light before night",
        "early night with lingering afterglow",
        "an overcast luminous evening",
        "a calm post-rain twilight"
    )

    $weatherStates = @(
        "clear air with a steady light breeze",
        "a still overcast atmosphere with softly diffused light",
        "dry cold evening air with unusually clear distance",
        "a calm post-rain atmosphere with subtle reflective surfaces"
    )

    $cameraAngles = @(
        "eye-level framing",
        "a gentle elevated viewpoint",
        "a subtle low-angle perspective",
        "a lightly compressed cinematic perspective"
    )

    $cameraTemplates = @(
        "a medium-long shot with strong readability of the full figure",
        "a medium-long shot with a clear silhouette against the horizon",
        "a medium shot with slightly expanded environmental context"
    )

    $materialAnchors = @(
        "quiet water reflections and crisp jacket folds",
        "subtle platform textures and polished dark footwear",
        "matte concrete parapet surfaces and clean boot leather",
        "clean rail details and structured dark tailoring",
        "slightly reflective surfaces and soft fabric texture",
        "stone-like barrier textures and crisp jacket folds",
        "soft knit texture, paper edges, and natural daylight on fabric folds",
        "wood grain, linen-like surfaces, and clean indoor daylight",
        "glass reflections, book-paper texture, and gentle ambient interior light"
    )

    $hairStyles = @(
        "long silver-pink hair moving in the wind",
        "long ash-rose hair with a light windswept motion",
        "medium-short pale pink-gray hair catching the evening breeze",
        "long pale pink-gray hair flowing softly in the dusk breeze",
        "medium-short ash-rose hair with soft layered movement"
    )

    $outfits = @(
        "a dark fitted jacket over a black dress",
        "a black street-chic outfit with a loose dark outer layer",
        "a sleek dark top and tailored shorts with a lightweight jacket",
        "a refined all-black outfit with subtle feminine edge"
    )

    $scene = Select-FromPool -Bytes $bytes -Offset 0 -Pool $scenes
    $action = Select-FromPool -Bytes $bytes -Offset 3 -Pool $actions
    $mood = Select-FromPool -Bytes $bytes -Offset 6 -Pool $moods
    $primaryPalette = Select-FromPool -Bytes $bytes -Offset 9 -Pool $primaryPalettes
    $accentPalette = Select-FromPool -Bytes $bytes -Offset 10 -Pool $accentPalettes
    $palette = "$primaryPalette with $accentPalette"
    $position = Select-FromPool -Bytes $bytes -Offset 12 -Pool $positions
    $timeState = Select-FromPool -Bytes $bytes -Offset 15 -Pool $timeStates
    $weather = Select-FromPool -Bytes $bytes -Offset 16 -Pool $weatherStates
    $cameraAngle = Select-FromPool -Bytes $bytes -Offset 18 -Pool $cameraAngles
    $cameraTemplate = Select-FromPool -Bytes $bytes -Offset 19 -Pool $cameraTemplates
    $materialAnchor = Select-FromPool -Bytes $bytes -Offset 20 -Pool $materialAnchors
    $hair = Select-FromPool -Bytes $bytes -Offset 21 -Pool $hairStyles
    $outfit = Select-FromPool -Bytes $bytes -Offset 24 -Pool $outfits

    $seriesStyle = Get-ConfigValue -Config $DefaultsConfig -Name "seriesStyle"
    $identityProfile = Get-IdentityProfile -DefaultsConfig $DefaultsConfig
    $styleNameZh = Get-ConfigValue -Config $seriesStyle -Name "styleNameZh" -Fallback "Japanese atmospheric personal illustration style"
    $subjectVibe = Get-ConfigValue -Config $seriesStyle -Name "subjectVibe" -Fallback "exactly one young woman with subtle sensuality and effortless confidence, stylish and free-spirited but not revealing, no excessive skin exposure, no vulgar styling, she is the only human subject in the entire image"
    $identityRule = Get-ConfigValue -Config $seriesStyle -Name "identityRule" -Fallback "preserve the heroine from the reference image as the same person first: keep the same face impression, eye shape tendency, facial proportions, jawline softness, nose-mouth relationship, hairstyle family, and overall aura before adding scene variation or fashion variation"
    $hairPreference = Get-ConfigValue -Config $seriesStyle -Name "hairPreference" -Fallback "keep hairstyle, hair length tendency, and overall hair silhouette close to the reference image first"
    $outfitPreference = Get-ConfigValue -Config $seriesStyle -Name "outfitPreference" -Fallback "keep outfit styling understated and contemporary, but never let fashion variation override the heroine identity from the reference image"
    $backgroundRule = Get-ConfigValue -Config $seriesStyle -Name "backgroundRule" -Fallback "simple but structurally rich, low-density, readable, restrained, elegant, not flashy, never empty or flat"
    $moodRule = Get-ConfigValue -Config $seriesStyle -Name "moodRule" -Fallback "poetic, atmospheric, restrained, cinematic, and personally expressive rather than commercial or poster-like"
    $renderRule = Get-ConfigValue -Config $seriesStyle -Name "renderRule" -Fallback "high-end anime illustration quality with exceptionally clean focal rendering"
    $lightingRule = Get-ConfigValue -Config $seriesStyle -Name "lightingRule" -Fallback "controlled cinematic lighting with brighter, cleaner midtones and atmospheric air perspective without muddy shadows"
    $compositionRule = Get-ConfigValue -Config $seriesStyle -Name "compositionRule" -Fallback "balanced anime illustration composition with restrained negative space and a slightly smaller heroine scale"
    $textRule = Get-ConfigValue -Config $seriesStyle -Name "textRule" -Fallback "absolutely no text, no letters, no words, no numbers, no dates, no timestamps, no subtitles, no signage, no logo, no watermark marks, no corner text, and no typographic elements anywhere in the image"

    $requestGuidance = $RequestText.Trim()
    $strongModules = @(
        "identity-profile"
        "user-request"
        "single-subject"
        "subject-scale"
        "render-quality"
        "anti-text"
    )
    $weakModules = @(
        "scene-fallback"
        "mood-lighting"
    )
    $promptModulesUsed = @(
        $strongModules +
        $weakModules +
        "prompt-assembly"
    )
    $templateTokens = @{
        identity_rule = $identityRule
        identity_face = $identityProfile.face
        identity_eyes = $identityProfile.eyes
        identity_hair = $identityProfile.hair
        identity_body = $identityProfile.body
        identity_aura = $identityProfile.aura
        request_text = $requestGuidance
        style_name_zh = $styleNameZh
        composition_rule = $compositionRule
        subject_vibe = $subjectVibe
        hair_preference = $hairPreference
        outfit_preference = $outfitPreference
        action = $action
        hair = $hair
        outfit = $outfit
        camera_template = $cameraTemplate
        camera_angle = $cameraAngle
        position = $position
        scene = $scene
        background_rule = $backgroundRule
        mood = $mood
        mood_rule = $moodRule
        time_state = $timeState
        weather = $weather
        palette = $palette
        lighting_rule = $lightingRule
        material_anchor = $materialAnchor
        render_rule = $renderRule
        text_rule = $textRule
        run_id = $RunId
        variant = $VariantIndex
        modules_used = ($promptModulesUsed -join ", ")
        strong_modules = ($strongModules -join ", ")
        weak_modules = ($weakModules -join ", ")
    }

    return @{
        Prompt = (
            @(
            "Create a 16:9 anime illustration in a unified personal style, based on the user reference character image."
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "identity-profile") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "user-request") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "single-subject") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "subject-scale") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "render-quality") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "anti-text") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "scene-fallback") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "mood-lighting") -Tokens $templateTokens)
            ""
            (Expand-Template -Template (Get-PromptModuleTemplate -ScriptRoot $ScriptRoot -ModuleName "prompt-assembly") -Tokens $templateTokens)
        ) -join "`n"
        )
        PromptModulesUsed = $promptModulesUsed
        PromptModuleGroups = @{
            strong = $strongModules
            weak = $weakModules
        }
        IdentityProfile = $identityProfile
    }
}

function Invoke-GeminiImage {
    param(
        [string]$ApiKey,
        [string]$ModelName,
        [string]$Prompt,
        [string]$OutputImagePath,
        [object]$ReferenceImagePart
    )

    $modelPath = Get-ModelPath -ModelName $ModelName
    $parts = @()
    if ($null -ne $ReferenceImagePart) {
        $parts += $ReferenceImagePart
    }
    $parts += @{ text = $Prompt }

    $uri = "https://generativelanguage.googleapis.com/v1beta/$modelPath`:generateContent?key=$ApiKey"
    $body = @{
        contents = @(
            @{
                parts = $parts
            }
        )
        generationConfig = @{
            responseModalities = @("TEXT", "IMAGE")
            imageConfig = @{
                aspectRatio = "16:9"
            }
        }
    } | ConvertTo-Json -Depth 8

    $tempBodyPath = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempBodyPath, $body, [System.Text.Encoding]::UTF8)

        $responseJson = $null
        $attempts = 3
        for ($attempt = 1; $attempt -le $attempts; $attempt++) {
            try {
                $responseJson = & curl.exe --silent --show-error --fail-with-body `
                    --ssl-no-revoke `
                    -X POST `
                    -H "Content-Type: application/json" `
                    --data-binary "@$tempBodyPath" `
                    "$uri"
                if ([string]::IsNullOrWhiteSpace($responseJson)) {
                    throw "Empty response from Gemini API."
                }
                break
            }
            catch {
                if ($attempt -eq $attempts) {
                    throw
                }
                Start-Sleep -Seconds (2 * $attempt)
            }
        }

        if ([string]::IsNullOrWhiteSpace($responseJson)) {
            throw "Gemini API request failed before a JSON response was returned."
        }
        $response = $responseJson | ConvertFrom-Json
    }
    finally {
        if (Test-Path -LiteralPath $tempBodyPath) {
            Remove-Item -LiteralPath $tempBodyPath -Force
        }
    }

    $candidates = @()
    if ($null -ne $response.candidates) {
        $candidates = @($response.candidates)
    }

    foreach ($candidate in $candidates) {
        $parts = @()
        if ($null -ne $candidate.content -and $null -ne $candidate.content.parts) {
            $parts = @($candidate.content.parts)
        }

        foreach ($part in $parts) {
            if ($null -ne $part.inlineData -and $part.inlineData.mimeType -like "image/*") {
                $bytes = [Convert]::FromBase64String($part.inlineData.data)
                [System.IO.File]::WriteAllBytes($OutputImagePath, $bytes)
                return @{
                    mimeType = $part.inlineData.mimeType
                    text = $null
                }
            }
        }
    }

    $textParts = @()
    foreach ($candidate in $candidates) {
        if ($null -ne $candidate.content -and $null -ne $candidate.content.parts) {
            foreach ($part in @($candidate.content.parts)) {
                if ($null -ne $part.text) {
                    $textParts += $part.text
                }
            }
        }
    }

    $joinedText = ($textParts -join "`n").Trim()
    throw "Gemini did not return an image. Response text: $joinedText"
}

$scriptRoot = Get-ScriptRoot
$configPath = Join-Path (Split-Path -Parent $scriptRoot) "config\defaults.json"
$defaults = Read-JsonConfig -Path $configPath

$resolvedOutputRoot = if (-not [string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot } else { [string](Get-ConfigValue -Config $defaults -Name "outputRoot" -Fallback "E:\WorkCodex\zhen-fmt") }
$resolvedModel = if (-not [string]::IsNullOrWhiteSpace($Model)) { $Model } else { [string](Get-ConfigValue -Config $defaults -Name "defaultModel" -Fallback "gemini-3-pro-image-preview") }
$resolvedReferenceImage = if (-not [string]::IsNullOrWhiteSpace($ReferenceImage)) { $ReferenceImage } else { [string](Get-ConfigValue -Config $defaults -Name "defaultReferenceImage" -Fallback "") }
$resolvedSeed = if (-not [string]::IsNullOrWhiteSpace($Seed)) { $Seed } else { "" }
$resolvedVariants = if ($Variants -gt 0) { $Variants } else { [int](Get-ConfigValue -Config $defaults -Name "defaultVariants" -Fallback 1) }
$outputWidth = [int](Get-ConfigValue -Config $defaults -Name "outputWidth" -Fallback 2048)
$outputHeight = [int](Get-ConfigValue -Config $defaults -Name "outputHeight" -Fallback 878)
$outputFormat = [string](Get-ConfigValue -Config $defaults -Name "outputFormat" -Fallback "jpg")
$jpegQuality = [int](Get-ConfigValue -Config $defaults -Name "jpegQuality" -Fallback 90)
$shouldSaveDebugArtifacts = if ($PSBoundParameters.ContainsKey("SaveDebugArtifacts")) { [bool]$SaveDebugArtifacts } else { [bool](Get-ConfigValue -Config $defaults -Name "saveDebugArtifacts" -Fallback $false) }
$resolvedDate = (Get-Date).ToString("yyyy-MM-dd")
$resolvedHour = (Get-Date).ToString("HH")
$runId = (Get-Date).ToString("yyyyMMdd-HHmmss")
$requestSlug = Convert-ToSlug -Text $Request -MaxLength 24
$seedLabel = Get-SeedLabel -ResolvedSeed $resolvedSeed -DefaultsConfig $defaults
$apiKey = Get-ApiKey
$dayDir = Join-Path $resolvedOutputRoot "outputs\$resolvedDate\$resolvedHour"
$results = @()
$referenceImagePart = Read-ReferenceImagePart -Path $resolvedReferenceImage
$identityProfile = Get-IdentityProfile -DefaultsConfig $defaults
$maxVariants = [int](Get-ConfigValue -Config $defaults -Name "maxVariants" -Fallback 3)

if ((Test-IsVagueRequest -ScriptRoot $scriptRoot -RequestText $Request) -and $ConfirmPromptChoice -lt 1 -and -not $PromptOnly) {
    $choices = Get-PromptChoices -ScriptRoot $scriptRoot -RequestText $Request -DefaultsConfig $defaults
    [pscustomobject]@{
        NeedsConfirmation = $true
        Request = $Request
        PromptChoices = $choices
        ImageFile = $null
    } | ConvertTo-Json -Depth 6
    exit 0
}

if ($ConfirmPromptChoice -gt 0) {
    $choices = Get-PromptChoices -ScriptRoot $scriptRoot -RequestText $Request -DefaultsConfig $defaults
    $selected = $choices | Where-Object { $_.Choice -eq $ConfirmPromptChoice } | Select-Object -First 1
    if ($null -eq $selected) {
        throw "ConfirmPromptChoice must be 1, 2, or 3."
    }
    $Request = [string]$selected.Prompt
    $requestSlug = Convert-ToSlug -Text $Request -MaxLength 24
}

if ($resolvedVariants -lt 1) {
    throw "-Variants must be at least 1."
}

if ($resolvedVariants -gt $maxVariants) {
    throw "-Variants supports at most $maxVariants to keep the workflow focused."
}

for ($i = 1; $i -le $resolvedVariants; $i++) {
    if ((-not $PromptOnly) -or $shouldSaveDebugArtifacts) {
        if (-not (Test-Path -LiteralPath $dayDir)) {
            New-Item -ItemType Directory -Force -Path $dayDir | Out-Null
        }
    }

    $promptBuild = Build-Prompt -ScriptRoot $scriptRoot -RequestText $Request -ResolvedDate $resolvedDate -RunId $runId -VariantIndex $i -ResolvedSeed $resolvedSeed -DefaultsConfig $defaults
    $prompt = [string]$promptBuild.Prompt
    $promptModulesUsed = @($promptBuild.PromptModulesUsed)
    $promptModuleGroups = $promptBuild.PromptModuleGroups
    $baseName = Use-CleanBaseName -RunId $runId -RequestSlug $requestSlug -SeedLabel $seedLabel -VariantIndex $i
    $promptPath = Join-Path $dayDir "$baseName-prompt.txt"
    $metaPath = Join-Path $dayDir "$baseName-metadata.json"
    $imagePath = Join-Path $dayDir "$baseName.png"
    $finalImagePath = [System.IO.Path]::ChangeExtension($imagePath, (Get-OutputExtension -Format $outputFormat))

    $meta = [ordered]@{
        request = $Request
        date = $resolvedDate
        runId = $runId
        requestSlug = $requestSlug
        variant = $i
        seed = $resolvedSeed
        seedLabel = $seedLabel
        model = $resolvedModel
        referenceImage = $resolvedReferenceImage
        identityProfile = $identityProfile
        promptModulesUsed = $promptModulesUsed
        promptModuleGroups = $promptModuleGroups
        outputImage = $(if ($PromptOnly) { $null } else { $finalImagePath })
        promptFile = $promptPath
        metadataFile = $metaPath
        baseName = $baseName
        promptOnly = [bool]$PromptOnly
        generatedAt = (Get-Date).ToString("s")
    }

    if (-not $PromptOnly) {
        if ([string]::IsNullOrWhiteSpace($apiKey)) {
            throw "Missing GEMINI_API_KEY or GOOGLE_API_KEY. Run with -PromptOnly or set an API key."
        }

        $invokeResult = Invoke-GeminiImage -ApiKey $apiKey -ModelName $resolvedModel -Prompt $prompt -OutputImagePath $imagePath -ReferenceImagePart $referenceImagePart
        $finalImagePath = Invoke-ImageFinalize -Path $imagePath -TargetWidth $outputWidth -TargetHeight $outputHeight -OutputFormat $outputFormat -JpegQuality $jpegQuality
        $meta["mimeType"] = $invokeResult.mimeType
        $meta["outputImage"] = $finalImagePath
    }

    if ($shouldSaveDebugArtifacts) {
        Set-Content -LiteralPath $promptPath -Value $prompt -Encoding UTF8
        $meta | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metaPath -Encoding UTF8
    }

    $results += [pscustomobject]@{
        Date = $resolvedDate
        Variant = $i
        RunId = $runId
        BaseName = $baseName
        RequestSlug = $requestSlug
        Seed = $resolvedSeed
        SeedLabel = $seedLabel
        Prompt = $(if ($shouldSaveDebugArtifacts -or $PromptOnly) { $prompt } else { $null })
        PromptModulesUsed = $(if ($shouldSaveDebugArtifacts -or $PromptOnly) { $promptModulesUsed } else { $null })
        PromptModuleGroups = $(if ($shouldSaveDebugArtifacts -or $PromptOnly) { $promptModuleGroups } else { $null })
        PromptFile = $(if ($shouldSaveDebugArtifacts) { $promptPath } else { $null })
        MetadataFile = $(if ($shouldSaveDebugArtifacts) { $metaPath } else { $null })
        ImageFile = $(if ($PromptOnly) { $null } else { $finalImagePath })
        ReferenceImage = $resolvedReferenceImage
        IdentityProfile = $(if ($shouldSaveDebugArtifacts -or $PromptOnly) { $identityProfile } else { $null })
        Model = $resolvedModel
    }
}

if ($PathOnly) {
    ($results | ForEach-Object { $_.ImageFile }) | ConvertTo-Json -Depth 3
}
else {
    $results | ConvertTo-Json -Depth 6
}
