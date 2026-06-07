---
name: zhen-fmt
description: Use when the user wants a single-subject anime illustration generated from a fixed personal reference character image, especially for Chinese natural-language requests that should preserve the same heroine identity while changing scene, mood, outfit, or camera feeling.
---

# zhen-fmt

## Overview

Generate anime-style images based on a fixed personal reference image.

This skill is not mainly about article covers anymore.
Its core purpose is:

- keep the same heroine identity from the reference image
- preserve a stable personal visual language
- generate new scenes, outfits, poses, moods, and atmospheres from natural-language requests

The house style name for this skill is `个人日系氛围插画风`.
The default character reference image is [人物参考图.jpg](E:\图片视频\电脑壁纸\人物参考图.jpg).

## Goal

Produce a `16:9` anime illustration or a Gemini-ready prompt that keeps the same heroine identity and personal style while allowing the user to describe new scenes freely.

## When to Use

Use this skill when the user asks for:

- a new image based on the same heroine reference
- a personal-style anime illustration
- a mood image or scene image using the same character
- a vague personal-style image where Codex should first propose a few candidate directions in Chinese
- a prompt based on the existing heroine reference
- a reproducible variation with a fixed seed
- several candidate images from one request

## What This Skill Does Not Do

Do not use this skill for:

- photo-realistic portrait generation
- multi-character scenes
- posters that require embedded typography
- heavy layout design tasks
- broad style exploration without a fixed heroine reference
- non-Gemini image providers unless explicitly requested

## Core Rules

Keep these rules fixed unless the user overrides them:

- house style: `个人日系氛围插画风`
- default character reference: [人物参考图.jpg](E:\图片视频\电脑壁纸\人物参考图.jpg)
- `16:9` image generation
- anime illustration, not photography, not 3D
- exactly one heroine only
- preserve the heroine identity from the reference image
- scene can change, outfit can change, mood can change, but the heroine should still feel like the same person
- no accidental text, no date, no timestamp, no watermark

## Execution

1. Parse the user request.
2. If the request is vague, first return 3 Chinese candidate directions and wait for the user's choice.
3. Use the local script at `scripts/generate-image.ps1`.
4. Treat the reference image as the identity anchor.
5. Build the prompt from explicit modules: identity profile, user request, subject/composition, scene fallback, mood/lighting, render quality, and anti-text constraints.
6. Save outputs under `E:\WorkCodex\zhen-fmt\outputs\yyyy-MM-dd\HH`.

## Required Inputs

- user request text
- optional reference image override
- Gemini API key from `GEMINI_API_KEY` or `GOOGLE_API_KEY`

Optional overrides:

- `ZHEN_FMT_GEMINI_MODEL`
- `ZHEN_FMT_OUTPUT_ROOT`
- `-ReferenceImage`
- `-Seed`
- `-Variants`
- `-PromptOnly`
- `-SaveDebugArtifacts`

## Output Specification

Default output root:

- `E:\WorkCodex\zhen-fmt`

Per run, save:

- rendered image file
- only the rendered image file by default
- `prompt.txt` and `metadata.json` only when `-SaveDebugArtifacts` is enabled
- render 3 variants by default after the user confirms a vague request direction

Recommended invocation pattern:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一个带有夜晚城市氛围的个人风格插画"
```

Prompt-only mode:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一个安静夜景中的个人风格插画" -PromptOnly
```

Reproducible variant mode:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一个黄昏城市露台场景" -Seed "scene-2026-04-25" -Variants 3
```

Reference image override:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一个雨后夜景插画" -ReferenceImage "E:\你的路径\新参考图.jpg"
```

Candidate-choice flow for vague requests:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一张个人风格图片"
```

After choosing one direction:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\generate-image.ps1" -Request "生成一张个人风格图片" -ConfirmPromptChoice 2
```

## Acceptance Criteria

This skill is complete for a request only if:

1. the generated prompt or image preserves the same heroine identity from the reference image
2. the result feels like the same personal style rather than a random anime image
3. the image contains exactly one heroine
4. the result does not contain accidental text, date, timestamp, or watermark
5. when debug artifacts are requested, prompt metadata exposes the run id, request slug, identity profile, and prompt modules used
6. if rendering is requested, a Gemini image file is saved successfully

## Known Pitfalls

- If the API key is missing, the skill can still generate a prompt but cannot render.
- If the request is too vague, the result may be visually generic.
- If Gemini fails to follow text constraints, accidental text or numerals can still appear.
- This skill is strongest when the request clearly describes scene, mood, outfit, or camera feeling.
