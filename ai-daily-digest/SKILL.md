---
name: ai-daily-digest
description: Use when the user wants to run the AI daily digest, or run or resume the AI杨侦探 digest-to-WeChat publish workflow in this repository, including topic selection, article drafting, article optimization, illustration generation, asset archiving, and final publish packaging.
---

# ai-daily-digest

## Overview

Run the local `AI杨侦探工作流` in this repository.

The external-facing project identity is:

- `AI杨侦探工作流`

The compatibility-preserved internal core is still:

- generate an AI daily digest from curated feeds

It also supports the downstream publish workflow:

- convert a digest into a WeChat article draft
- plan article illustrations
- generate illustration images
- organize article-scoped illustration assets
- finalize a Markdown article with inserted image references
- run the AI杨侦探 orchestrated digest-to-publish workflow

The correct mental model is:

- `ai-daily-digest` is the underlying digest engine and compatibility layer
- WeChat article / illustration / finalization are supported downstream extensions
- the recommended long-form publishing path is now the AI杨侦探 orchestrated workflow

## Goal

Help the user complete one or more stages of the local AI 日报 / 公众号稿 workflow using the repository's real scripts, real output paths, and explicit verification.

For AI杨侦探 requests, prefer the article-scoped, state-driven workflow:

- `48 小时日报`
- candidate topic extraction
- human topic gate
- `khazix-writer` first draft
- `wechat-article-writer` optimization with default title options
- `baoyu-article-illustrator` planning and generation
- article-scoped asset archiving
- Markdown image insertion
- final packaging with intro lines, topic tags, and packaged publish-ready output

## When to Use

Use this skill when the task involves any of the following in this repository:

- running the AI daily digest
- generating a fresh digest for the last 24h / 48h / 72h / 7d
- checking whether the digest launcher or workflow still matches the original purpose
- reading an existing digest and generating a 公众号 Markdown article
- running the AI杨侦探 digest-to-WeChat orchestrated workflow
- resuming a partial AI杨侦探 article pipeline from digest, article, or illustration state
- planning, generating, organizing, or finalizing article illustrations
- running the full chain from digest to final publish-ready Markdown
- troubleshooting model config, output files, or broken pipeline stages
- validating output locations or latest artifacts
- updating the repo so the workflow is easier to run repeatedly

Typical trigger phrases:

- `跑日报`
- `完整跑一遍今日日报`
- `先生成 24h / Top 15 AI 日报`
- `读取日报生成公众号稿`
- `生成公众号稿`
- `规划插图`
- `生成文章插图`
- `整理插图目录`
- `插到 markdown 文件`
- `一键跑完整流程`
- `完整发布链路`
- `跑今天的 AI杨侦探工作流`
- `从日报里挑题写今天这篇`
- `继续今天这篇，把图也配完并归档`
- `把这篇走到发文包`

## What This Skill Does Not Do

- Do not claim the pipeline succeeded without checking the real outputs.
- Do not bypass the repo scripts unless the user explicitly asks for code changes.
- Do not silently invent missing headings, image placements, or output files.
- Do not present a partial pipeline as if it were a final publish-ready article.
- Do not auto-publish to WeChat or any external platform.
- Do not auto-decide the final daily topic without a human topic gate when the request is the AI杨侦探 workflow.

## Repository Anchor

Default project root:

- `E:\WorkCodex\ai-daily-digest`

Use this repository as the implementation source of truth.

## Existing Local Context

Before proposing changes, prefer the files that already exist here:

- [README.md](E:\WorkCodex\ai-daily-digest\README.md)
- [AGENTS.md](E:\WorkCodex\ai-daily-digest\AGENTS.md)
- [docs/gzhrb-writing-checklist.md](E:\WorkCodex\ai-daily-digest\docs\gzhrb-writing-checklist.md)
- [docs/superpowers/specs/2026-04-15-gzhrb-publish-pipeline-design.md](E:\WorkCodex\ai-daily-digest\docs\superpowers\specs\2026-04-15-gzhrb-publish-pipeline-design.md)
- [docs/superpowers/plans/2026-04-15-gzhrb-publish-pipeline.md](E:\WorkCodex\ai-daily-digest\docs\superpowers\plans\2026-04-15-gzhrb-publish-pipeline.md)
- [docs/superpowers/specs/2026-04-19-ai-yang-detective-content-pipeline-skill-spec-v1.md](E:\WorkCodex\ai-daily-digest\docs\superpowers\specs\2026-04-19-ai-yang-detective-content-pipeline-skill-spec-v1.md)
- [docs/superpowers/specs/2026-04-23-gzhrb-semi-automatic-hard-gate-design.md](E:\WorkCodex\ai-daily-digest\docs\superpowers\specs\2026-04-23-gzhrb-semi-automatic-hard-gate-design.md)

When debugging behavior, inspect the corresponding implementation under `scripts\`.

## Primary Entrypoints

Use these scripts first instead of ad hoc manual commands:

- `scripts\ai-daily-digest-launcher.cmd`
- `scripts\ai-daily-digest-launcher.ps1`
- `scripts\digest.ts`
- `scripts\run-digest-and-gzhrb.cmd`
- `scripts\prepare-gzhrb-writing-workspace.cmd`
- `scripts\prepare-gzhrb-writing-workspace.ps1`
- `scripts\check-codex-required-skills.cmd`
- `scripts\gzhrb-writing-state.cmd`
- `scripts\inspect-gzhrb-writing-state.cmd`
- `scripts\approve-gzhrb-stage.cmd`
- `scripts\write-gzhrb-provenance.cmd`
- `scripts\plan-gzhrb-illustrations.cmd`
- `scripts\plan-gzhrb-illustrations.ps1`
- `scripts\generate-gzhrb-illustrations.cmd`
- `scripts\generate-gzhrb-illustrations.ps1`
- `scripts\organize-gzhrb-illustrations.cmd`
- `scripts\organize-gzhrb-illustrations.ps1`
- `scripts\finalize-gzhrb-article.cmd`
- `scripts\finalize-gzhrb-article.ps1`
- `scripts\package-gzhrb-article.cmd`
- `scripts\package-gzhrb-article.ps1`
- `scripts\run-digest-gzhrb-publish-pipeline.cmd`
- `scripts\run-gzhrb-postwriting-pipeline.cmd`

## Default Workflow Map

### Recommended Publishing Workflow: AI杨侦探

Use this path when the user clearly wants the full digest-to-publication workflow, or wants to resume a known stage in that chain.

State model:

- Stage 1: generate `48 小时日报`
- Stage 2: extract candidate topics
- Human Gate A: confirm the topic is suitable for a WeChat long-form article
- Stage 3: `khazix-writer` generates first draft
- Human Gate B: approve khazix draft
- Stage 4: `wechat-article-writer` optimizes article for WeChat
- Human Gate C: approve optimized article
- Stage 5: `baoyu-article-illustrator` plans and generates illustrations
- Stage 6: archive assets and insert image paths
- Stage 7: add titles, intro lines, and topic tags
- Human Gate D: final review

Repository state machine:

- `awaiting_topic_approval`
- `awaiting_khazix_execution`
- `awaiting_khazix_approval`
- `awaiting_wechat_execution`
- `awaiting_wechat_approval`
- `awaiting_illustration_execution`
- `ready_for_publish_unit`
- `completed`

Routing rules:

- digest generation -> `ai-daily-digest`
- first draft -> `khazix-writer`
- article optimization -> `wechat-article-writer`
- illustration planning and generation -> `baoyu-article-illustrator`

Critical workflow constraint:

- At the workflow level, both illustration planning and illustration generation are described under `baoyu-article-illustrator`
- Do not externally split this stage into any other separate skill or tool name

### Stage 1: Generate digest

Use when the user only wants the AI 日报.

Preferred entrypoints:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\ai-daily-digest-launcher.cmd
```

Or direct scripted execution:

```powershell
cd E:\WorkCodex\ai-daily-digest
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --waytoagi-limit 0 --output .\reports\output\ai-daily-digest-manual.md --health-log .\reports\health\run-manual.json
```

### Stage 2: Prepare formal writing workspace

Use when a digest already exists, a topic is confirmed, and the workflow needs fixed paths for the dual-skill writing stage.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\prepare-gzhrb-writing-workspace.cmd
```

### Stage 3: Run digest + topic gate + writing workspace

Use when the user wants the common daily flow.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\run-digest-and-gzhrb.cmd
```

### Stage 4: Formal writing stage

Use when the topic is confirmed and formal writing must go through the external dual-skill chain.

Required external routing:

- first draft -> `khazix-writer`
- optimized article -> `wechat-article-writer`

Hard rule:

- before treating the current Codex window as the formal dual-skill writing environment, run `scripts\check-codex-required-skills.cmd`
- if either `khazix-writer` or `wechat-article-writer` is missing from the current session's `Available skills`, stop and report that the current window is not a valid formal writing environment
- do not rename manual fallback writing as `khazix-writer` output or `wechat-article-writer` output
- do not claim the repository has completed formal article drafting unless the required output file, provenance file, and approval file all exist

Formal writing evidence model:

- `khazix-writer` output file: `reports\gzhrb\drafts\<article-id>-khazix.md`
- `khazix` provenance: `reports\gzhrb\provenance\<article-id>\khazix-execution.json`
- `khazix` approval: `reports\gzhrb\approvals\<article-id>\khazix-approved.json`
- `wechat-article-writer` output file: `reports\gzhrb\articles\<article-id>\article.md`
- `wechat` provenance: `reports\gzhrb\provenance\<article-id>\wechat-execution.json`
- `wechat` approval: `reports\gzhrb\approvals\<article-id>\wechat-approved.json`

Do not bypass these gates:

- after topic confirmation, use `scripts\gzhrb-writing-state.cmd approve-topic --article "<article-path>"`
- after formal khazix execution, write provenance, then mark/approve khazix
- after formal wechat execution, write provenance, then mark/approve wechat
- do not continue into post-writing if `wechat` evidence is incomplete

### Stage 5: Plan illustrations

Use when a 公众号文章 already exists and structured illustration plan artifacts are needed.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\plan-gzhrb-illustrations.cmd
```

### Stage 6: Generate article illustrations

Use when the article-scoped `batch.json` exists.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\generate-gzhrb-illustrations.cmd
```

### Stage 7: Organize illustration assets

Use when images, prompts, plan files, and metadata must be normalized inside the article-scoped illustration folder.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\organize-gzhrb-illustrations.cmd
```

### Stage 8: Finalize article

Use when `placement.json` and required images exist and the user wants the final Markdown article with inserted image references.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\finalize-gzhrb-article.cmd
```

### Stage 9: Pre-writing pipeline bootstrap

Use when the user wants the digest side of the full chain and the repository should stop cleanly at the formal writing gate.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\run-digest-gzhrb-publish-pipeline.cmd
```

### Stage 10: Post-writing pipeline

Use when the optimized article already exists and the user wants to continue the rest of the publish chain.

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\run-gzhrb-postwriting-pipeline.cmd "E:\WorkCodex\ai-daily-digest\reports\gzhrb\articles\<article-id>\article.md"
```

### Stage 11: Publish packaging

Use when an article already exists and the user wants the final publish-ready Markdown structure with:

- `# 标题备选`
- `# 引导语备选`
- `# 话题标签`
- `# 正文`

The final deliverable is not a single scattered markdown file. It is the article-scoped publish unit:

- `reports\gzhrb\publish-units\<article-id>\`

Preferred entrypoint:

```powershell
cd E:\WorkCodex\ai-daily-digest
scripts\package-gzhrb-article.cmd
```

## Output Locations

Default outputs live here:

- digest markdown: `reports\output`
- health logs: `reports\health`
- topic candidates: `reports\gzhrb\topics`
- khazix drafts: `reports\gzhrb\drafts`
- workitems: `reports\gzhrb\workitems`
- approvals: `reports\gzhrb\approvals`
- provenance: `reports\gzhrb\provenance`
- optimized article workspace: `reports\gzhrb\articles`
- illustration assets: `reports\gzhrb\illustrations`
- publish units: `reports\gzhrb\publish-units`

Article-scoped illustration assets should resolve to:

- `reports\gzhrb\illustrations\<article-id>\`

Common output examples:

- `reports/output/ai-daily-digest-YYYYMMDD-HHmm.md`
- `reports/health/run-YYYYMMDD-HHmm.json`
- `reports/gzhrb/drafts/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]-khazix.md`
- `reports/gzhrb/articles/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/article.md`
- `reports/gzhrb/approvals/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/`
- `reports/gzhrb/provenance/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/`
- `reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/placement.json`
- `reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/batch.json`
- `reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/outline.md`
- `reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/*.png`
- `reports/gzhrb/publish-units/gzhrb-YYYYMMDD-HHmm[-<topic-slug>]/article.md`

For AI杨侦探 final delivery, the minimum publish unit is:

- one `reports\gzhrb\publish-units\<article-id>\article.md`
- one matching `reports\gzhrb\publish-units\<article-id>\illustrations\` directory
- `titles.txt`
- `intro-lines.txt`
- `topic-tags.txt`
- `package.json`
- `review-checklist.md`

## Operating Rules

1. Prefer the repo's launcher or wrapper scripts over one-off commands.
2. If the user asks to continue from a partial stage, identify the latest real artifact first.
3. If the task is troubleshooting, inspect the relevant script and recent output files before proposing fixes.
4. If the task is to modify the workflow, change the repo files, not just the explanation.
5. If image generation is requested, verify the required provider keys and upstream artifacts exist.
6. For article finalization, fail clearly if headings, images, or `placement.json` do not match.
7. Preserve the repo's main identity as a digest tool first, not only a publishing pipeline.
8. In the AI杨侦探 workflow, keep topic selection as a human gate.
9. In the AI杨侦探 workflow, do not mark formal dual-skill completion unless file evidence, provenance, and approval all exist.
10. In the AI杨侦探 workflow, do not mark completion if images are not archived into the article-scoped directory.
11. In the AI杨侦探 workflow, do not mark completion if title options, intro lines, topic tags, or publish-unit files are still missing.

## Minimum Checks Before Claiming Success

Check the artifacts that match the requested stage:

- digest stage: a new or updated digest markdown file exists
- topic gate stage: the topic approval file exists
- khazix stage: draft file, khazix provenance, and khazix approval all exist
- wechat stage: `articles\<article-id>\article.md`, wechat provenance, and wechat approval all exist
- planning stage: `placement.json`, `batch.json`, and `outline.md` exist
- image generation stage: the expected image files exist
- organize stage: assets remain in the article-scoped illustration directory
- finalize stage: the article workspace file contains the expected image markdown and does not duplicate inserts on rerun
- AI杨侦探 final package: publish-unit article, article-scoped illustration directory, titles, intro lines, tags, and package manifest all exist

## Failure Handling

Surface failures explicitly instead of guessing.

Important failure cases:

- no API key available for the current stage
- the configured provider base URL or wire protocol does not match the provider
- digest generation failed because feed fetch, scoring, or summary steps failed
- no recent articles were found in the requested time range
- article generation failed because model/API config is missing or incompatible
- `placement.json` is missing
- a target heading is missing from the article
- a target heading appears more than once and cannot be matched safely
- expected image files are missing
- the final article was overwritten after images had already been inserted
- the digest exists but no suitable topic was approved for long-form writing
- formal draft file exists but provenance is missing
- formal optimized article exists but approval is missing
- publish-unit is incomplete even though article workfile exists
- the article is drafted but publish packaging is still missing

If any stage in the full pipeline fails, stop and report the failing stage rather than pretending the whole chain finished.

## Quality Boundaries

When editing or extending this repository:

- preserve digest generation as the primary function
- treat article and illustration logic as downstream extensions
- keep Windows + PowerShell workflow usability intact
- use UTF-8-safe file IO for Chinese Markdown and metadata
- avoid destructive cleanup or path rewriting without verification

## Acceptance Criteria

This skill is being used correctly only if:

1. the requested flow is mapped to the right repo entrypoint
2. digest-only requests still use digest as the primary path
3. downstream article and illustration stages are only run when requested or clearly implied
4. output files are reported with their real saved paths
5. failures are reported at the exact stage where they occurred
6. the repository is still treated as an AI digest tool first, even though the supported scope is now broader
7. AI杨侦探 workflow requests are mapped to the orchestrated stage model instead of being reduced to a single script call
8. final article claims are backed by real article-scoped assets and packaging artifacts
9. formal dual-skill claims are backed by output files plus approval/provenance evidence

## Known Pitfalls

- treating the repo like a generic writing tool instead of a script-driven pipeline
- forgetting that the repo now includes a downstream article workflow
- treating file existence alone as proof of formal dual-skill execution
- claiming illustration generation succeeded without checking the article-scoped output directory
- finalizing an article after the headings changed from the earlier plan
- assuming every OpenAI-compatible provider supports `chat/completions`
- trusting documentation over current on-disk scripts without verification
