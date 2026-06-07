---
name: ai-yang-detective-content-pipeline
description: Use when the user wants to run the AI杨侦探 content pipeline from 48-hour digest selection through WeChat article drafting, article optimization, illustration generation, asset archiving, Markdown image insertion, and final publish packaging, or wants to resume any stage of that same pipeline.
---

# ai-yang-detective-content-pipeline

## Overview

This is a total-control orchestrator skill for the `AI杨侦探` account workflow.

Its job is not to replace writing or illustration skills. Its job is to decide the stage, call the right downstream skill, preserve article-scoped assets, and deliver a publish-ready content package.

Repository execution note:

- the local repository now stops at a formal writing gate after topic confirmation
- it creates a workitem plus fixed output paths for `khazix-writer` and `wechat-article-writer`
- downstream illustration and packaging scripts should resume only after the optimized article file exists on disk

The workflow itself is:

- run `48 小时日报`
- extract candidate topics
- keep a human approval gate for topic selection
- draft with `khazix-writer`
- optimize with `wechat-article-writer` and produce default title options
- plan and generate illustrations with `baoyu-article-illustrator`
- archive assets into the article directory
- insert image references back into Markdown
- add intro lines, topic tags, and finalize the publish package

## Goal

Turn one topic selected from the `48 小时日报` into a complete `AI杨侦探` WeChat publishing unit:

- optimized Markdown article
- article-scoped illustration assets
- image references inserted into the article
- title options
- intro lines
- topic tags

## When to Use

Use this skill when the request clearly refers to the whole日报到公众号链路, or to resuming a known stage inside that same chain.

Typical triggers:

- `跑今天的内容工作流`
- `从日报里挑题写今天这篇`
- `从日报到公众号稿跑一遍`
- `跑 AI杨侦探工作流`
- `继续今天这篇`
- `把这篇走到发文包`
- `给这篇配图并归档`
- `把这篇整理成可发布版`

Trigger examples:

- `完整跑一遍 48 小时日报，然后挑一个最适合写成长文的题材`
- `从日报里挑一题，直接做成公众号发文包`
- `继续今天这篇，把图也配完并归档`
- `这篇已经写完了，再走完标题、引导语、标签和插图`
- `从这篇日报继续，不要重跑前面的`

Use this skill for both:

- full-chain execution from digest to final package
- state-driven resume from an existing digest, article, or illustration stage

Do not use this skill when the user only wants one isolated subtask:

- only run a digest
- only write an article
- only polish an article
- only generate one image
- only ask for title options, intro lines, or tags

Those should stay with the existing downstream skills.

Non-trigger examples:

- `帮我写一篇公众号文章`
- `帮我润色这段文案`
- `给这篇文章补几个标题`
- `帮我只生成一张头图`
- `只跑今天的 48 小时日报`

## Downstream Skill Routing

This skill is an orchestrator. It should route work instead of re-implementing it.

- `ai-daily-digest`
  - generate the `48 小时日报`
- `khazix-writer`
  - produce the long-form first draft from the selected topic
- `wechat-article-writer`
  - optimize the article into WeChat publish style
- `baoyu-article-illustrator`
  - handle illustration planning, illustration generation, asset archiving, and Markdown image insertion

Critical rule:

- At the workflow level, both illustration planning and illustration generation belong to `baoyu-article-illustrator`
- Do not describe stage 8 externally as any separate image tool name

## Operating Sequence

### Stage 1: Generate digest

- Run the `48 小时日报`
- Treat the digest as the same-day topic pool

### Stage 2: Extract candidate topics

- Identify topics that can support a full WeChat long-form article
- Output short candidate judgments instead of writing immediately

### Human Gate A: Topic selection

- A person decides whether a topic is suitable for the public-account format
- If none are suitable, stop and report that outcome clearly

### Stage 3: Draft long-form article

- Use `khazix-writer`
- Produce a Markdown first draft at the workitem-defined draft path

### Stage 4: Optimize for WeChat publication

- Use `wechat-article-writer`
- Improve opening, flow, readability, and public-account tone
- Treat this stage externally as “公众号发文态优化”, not old internal GZHRB wording
- Save the optimized article to the workitem-defined final article path before continuing

### Stage 5: Plan illustrations

- Use `baoyu-article-illustrator`
- Analyze article structure and visual opportunities
- Produce planning artifacts for the article

### Stage 6: Generate illustrations

- Continue with `baoyu-article-illustrator`
- Keep the external workflow wording unified under the same skill

### Stage 7: Archive and insert

- Archive images and planning artifacts into the article-scoped folder
- Insert relative image references back into the Markdown article

### Stage 8: Build publish package

- Add title options
- Add intro lines within 20 Chinese characters when requested
- Add topic tag keywords

### Human Gate B: Final review

- Review article quality
- Review illustration quality
- Review packaging quality

### Human Gate C: Publish approval

- If approved, the workflow is complete
- If not approved, roll back to the right stage and continue iterating

## Default Illustration Style

Default style is `AI杨侦探插图风格 v1`.

Required visual direction:

- light editorial explainer style
- diagram plus light 3D scene hybrid
- premium and textured, but low AI feel
- avoid dark blue, dark purple, neon, cyber-tech visual language

Default image settings:

- aspect ratio: `16:9`
- quality: `2K`

Default palette anchors:

- `#F6F1E8`
- `#27403A`
- `#D8BFC5`
- `#A56A43`

Current local defaults already land in:


## Archiving Rules

Illustration assets must be article-scoped. They must not be left in a shared loose folder.

Required archive root:

- `reports/gzhrb/illustrations/<article-id>/`

Expected contents include:

- `outline.md`
- `batch.json`
- `prompts/`
- generated image files

Markdown image references must use relative paths that point into the same article-scoped illustration directory.

Example:

```md
![配图说明](illustrations/<article-id>/01-scene.png)
```

Do not allow:

- images scattered directly under `reports/gzhrb/illustrations/`
- cross-article image references
- generated images without archiving
- archived images without Markdown insertion

## Completion Standard

Do not mark this workflow complete unless the final publish unit actually exists.

Required completion conditions:

1. a `48 小时日报` exists for the run
2. one topic has been selected as suitable for a WeChat long-form article
3. a long-form Markdown draft exists
4. a WeChat-optimized article version exists
5. illustration planning and illustration generation are complete
6. illustration assets are archived into the article-scoped folder
7. image references are inserted into the Markdown article
8. title options, intro lines, and topic tags have been added
9. the final publish package is ready for human review

## Final Deliverables

The final deliverable must include all of the following:

- one optimized Markdown article
- one article-scoped illustration directory
- title options
- intro line options
- topic tag keywords

Deliverable sample:

```text
reports/
  gzhrb/
    gzhrb-20260419-1519-khazix.md
    illustrations/
      gzhrb-20260419-1519-khazix/
        outline.md
        batch.json
        prompts/
        01-framework-model-vs-method-library.png
        02-comparison-same-model-different-environment.png
```

## Failure Handling

Stop and report the actual stage when blocked.

Common blocking cases:

- no suitable topic found in the digest
- the selected topic is not suitable for WeChat long-form treatment
- draft exists but still needs WeChat-style restructuring
- illustration planning artifacts are missing
- illustrations were generated but not archived into the article directory
- image references were not inserted back into the Markdown
- only article text exists, but packaging items are still missing

Do not present a partial article as a final publish package.

Failure rollback examples:

- No suitable topic after digest review
  - stop at the topic-selection gate
  - do not force article drafting
- Draft is informative but not publish-ready
  - return to `wechat-article-writer`
  - do not rerun digest or topic selection
- Images were generated in the wrong visual direction
  - return to `baoyu-article-illustrator`
  - keep the article text and redo illustration planning/generation
- Images exist but are not inside `reports/gzhrb/illustrations/<article-id>/`
  - do not mark complete
  - archive first, then re-check Markdown paths
- Only title packaging is missing
  - return only to the publish-package stage
  - do not rerun article drafting or image generation

## Rollback Rules

If the final review fails, roll back only to the necessary stage:

- article-quality issue -> return to `wechat-article-writer`
- illustration issue -> return to `baoyu-article-illustrator`
- packaging-only issue -> return to the publish-package stage

## Acceptance Criteria

This skill is being used correctly only if:

1. it is treated as a workflow orchestrator, not a replacement for downstream skills
2. topic selection remains a human approval gate
3. both illustration planning and illustration generation are externally described under `baoyu-article-illustrator`
4. the default illustration style is `AI杨侦探插图风格 v1`, not the older engineering-media direction
5. illustration assets are archived into `reports/gzhrb/illustrations/<article-id>/`
6. Markdown image references point to the article-scoped asset directory
7. the final output includes article, images, titles, intro lines, and tags
