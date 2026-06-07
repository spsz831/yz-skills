---
name: szxs-gzh
description: Use when producing 四知先生公众号 daily horoscope content or converting a finalized 四知先生黄历 markdown article into a dual-host podcast script. Trigger for requests about generating 每日生肖黄历公众号内容, manually correcting zodiac order/layout/movie fields, saving final markdown, or turning the corrected markdown into 四知和一宜播客逐字稿.
---

# szxs-gzh

## Overview

Run the repeatable 四知先生公众号 workflow: generate the daily horoscope article draft, preserve a manual correction gate, produce a final corrected markdown article, and convert that final markdown into a 双人播客逐字稿.

## Goal

Help the user complete a stable daily content pipeline for 四知先生公众号 with less repetition, fewer missed corrections, and a more consistent 四知 / 一宜 voice.

## When to Use

Use this skill when the task involves any of the following:

- generating a 四知先生公众号 daily horoscope markdown article
- following the user's fixed 黄历 / 生肖 / 电影 content template
- correcting zodiac ranking order, markdown layout, movie title, quote, or image URL
- saving the corrected article as the final markdown version
- converting the final markdown article into a 四知先生 & 一宜 podcast script
- making article or podcast wording sound more like the user's established daily tone

## What This Skill Does Not Do

- Do not auto-publish content.
- Do not skip the manual correction stage.
- Do not generate the podcast script from the first draft.
- Do not silently keep a fixed zodiac order if the user requires ranking by daily fortune.
- Do not write in a stiff, over-mystified, or overly internet-native tone.

## Available Resources

Read these files only as needed:

- `references/prompt-gzh-markdown.md` — article generation prompt
- `references/prompt-podcast.md` — podcast conversion prompt
- `references/final-checklist.md` — required validation checklist
- `references/voice-style.md` — required voice calibration for 四知 / 一宜
- `references/example-final-article.md` — example of final article output
- `references/example-podcast-script.md` — example of final podcast output

## Workflow

### Stage 1: Generate article draft
Use `references/prompt-gzh-markdown.md` to generate the daily 四知先生公众号 markdown draft.

### Stage 2: Manual correction gate
Pause for user correction or apply user feedback. Treat these as explicit required checks:

- zodiac section ordering
- markdown structure and formatting
- movie title replacement
- movie quote replacement
- movie image URL replacement
- tone alignment with 四知先生公众号日常口吻

If the user says the zodiac order is wrong, correct it to match **daily fortune ranking from high to low**.

### Stage 3: Produce final markdown
After corrections, produce and save a final markdown version that is complete, publishable, and aligned with `references/voice-style.md`.

### Stage 4: Generate podcast script
Only after Stage 3 is complete, use `references/prompt-podcast.md` to transform the **final corrected markdown** into the dual-host podcast script.

## Voice Rules

Always align generated output with `references/voice-style.md`.

Minimum tone requirements:

- keep a mild sense of mystery and ritual
- keep traditional-culture depth without sounding pedantic
- make 四知 sound like a half-teacher, half-friend guide
- make 一宜 sound like a natural listener-side partner, not a variety-show sidekick
- prefer calm, grounded, memorable phrasing over exaggerated hype

## Acceptance Criteria

This skill is complete for a given task only if all of the following are true:

1. the 公众号 markdown draft was generated from the article prompt
2. the manual correction stage was preserved
3. the zodiac 正文 is ordered by **daily fortune ranking**
4. the final markdown is structurally correct and saveable
5. movie title, quote, and image URL were updated if required
6. the article voice is aligned with the configured 四知先生公众号 tone
7. the podcast script was generated from the **final corrected markdown**, not the draft
8. the podcast script covers all 12 zodiac signs and preserves the required spoken structure
9. the podcast dialogue sounds natural for 四知 / 一宜 rather than generic host copy
10. the final closing line is exactly **咱们明儿个见。晚安。**

## Output Specification

Default output labels:

- `draft_markdown`
- `final_markdown`
- `podcast_script`

If the user only wants one stage, output only that stage and clearly state which stages remain unfinished.

## Known Pitfalls

- Using the first draft to generate the podcast script
- Forgetting to replace movie title, quote, or image URL
- Leaving zodiac entries in fixed canonical order instead of daily fortune order
- Treating user correction as optional instead of required
- Preserving malformed markdown after content edits
- Writing 四知 too stiff, too mystical, or too much like a generic motivational account
- Writing 一宜 too cute, too noisy, or too scripted
