---
name: ai-daily-digest
description: Run, inspect, or troubleshoot the AI daily digest in the ai-daily-digest repository; prepare digest-based topic candidates and writing workspaces. Use the AI杨侦探 content pipeline skill for long-form article writing, WeChat SVG, cover design, and final editorial delivery.
---

# ai-daily-digest

Run the repository's digest engine and its mechanical workflow scripts. Treat the digest as the core capability; article publishing is a downstream workflow coordinated by `ai-yang-detective-content-pipeline`.

## Route the request

| User request | Use this skill for | Handoff / boundary |
|---|---|---|
| Run a 24h / 48h / 72h / 7d digest | Generate and verify the digest | Stop after reporting the real output files |
| Find an article topic from the digest | Generate candidates and prepare the writing work item | The user selects the topic; never choose automatically |
| Write or improve a WeChat article | Inspect or prepare repository state and files | Editorial writing belongs to `ai-yang-detective-content-pipeline` |
| Make illustrations, animated SVG, or a cover | Run only the relevant repository asset scripts when requested | Visual design belongs to `baoyu-article-illustrator`, `wechat-svg.md`, and `yang-cover` as routed by the content pipeline |
| Resume or troubleshoot a workflow | Inspect actual artifacts and state, then use the matching script | Do not infer completion from a work-item stage label alone |

Do not repeat approvals the user has already given. For article tasks, read `E:\WorkCodex\ai-daily-digest\AGENTS.md` and defer editorial decisions and final content packaging to the content pipeline skill.

## Main entry points

Run commands from `E:\WorkCodex\ai-daily-digest` in PowerShell. Prefer these wrappers over ad hoc commands:

- **Digest only:** `scripts\ai-daily-digest-launcher.cmd`
- **Digest, topic candidates, and writing workspace:** `scripts\run-digest-and-gzhrb.cmd`
- **Digest pipeline up to the writing gate:** `scripts\run-digest-gzhrb-publish-pipeline.cmd`
- **Inspect writing state:** `scripts\gzhrb-writing-state.cmd` or `scripts\inspect-gzhrb-writing-state.cmd`
- **Record an approval:** `scripts\approve-gzhrb-stage.cmd`
- **Continue after writing:** `scripts\run-gzhrb-postwriting-pipeline.cmd "<article.md path>"`
- **Individual illustration operations:** `scripts\plan-gzhrb-illustrations.cmd`, `scripts\generate-gzhrb-illustrations.cmd`, `scripts\organize-gzhrb-illustrations.cmd`
- **Finalize Markdown or create a publish package:** `scripts\finalize-gzhrb-article.cmd`, `scripts\package-gzhrb-article.cmd`

For a direct digest run with explicit parameters:

```powershell
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --waytoagi-limit 0 --output .\reports\output\ai-daily-digest-manual.md --health-log .\reports\health\run-manual.json
```

## Workflow rules

1. **Digest only:** run the digest launcher, then confirm a digest Markdown file and health log were actually created.
2. **Digest to topic:** generate candidates, preserve the human topic-selection gate, and prepare the work item. A supplied topic counts as selected; do not rerun the digest unless needed.
3. **Writing:** use `ai-yang-detective-content-pipeline` for the article, its fact and voice review, the final blog Markdown, WeChat SVG, and cover. This skill may inspect work-item state and run repository scripts, but it does not define a second editorial process.
4. **Resume:** inspect the latest real files and state before choosing the next script. Follow the validator for legacy work items; the current `2-lite` flow requires real article and approval evidence while provenance is optional.
5. **Partial request:** run only the requested stage. Do not silently continue to publication or publish externally.

The workflow's principal human gates are topic selection and article approval. Do not add separate approval steps for every writing pass, illustration, or cover. SVG production and WeChat/device verification are separate from the repository's packaging scripts.

## Output locations

- Digest Markdown: `reports\output\`
- Health logs: `reports\health\`
- Topic candidates: `reports\gzhrb\topics\`
- Drafts and work items: `reports\gzhrb\drafts\`, `reports\gzhrb\workitems\`
- Approvals and optional provenance: `reports\gzhrb\approvals\`, `reports\gzhrb\provenance\`
- Article workspace: `reports\gzhrb\articles\<article-id>\article.md`
- Illustration workspace and assets: `reports\gzhrb\illustrations\<article-id>\`
- Final publish unit: `reports\gzhrb\publish-units\<article-id>\`

The full content pipeline's main deliverables are `article.md` and the complete WeChat SVG source; title options, intro lines, tags, cover files, illustrations, and review metadata are supporting assets as required by the task.

## Verify before reporting

- Digest: report the actual Markdown path and health log path.
- Topic/workspace: verify candidate and work-item files; confirm the topic approval exists before formal writing.
- Writing: verify `reports\gzhrb\articles\<article-id>\article.md` and the applicable writing approval.
- Illustrations: verify the plan files and expected images in the article-scoped directory.
- Publish package: verify its Markdown, SVG source, required assets, and metadata. The existing packaging script does not create or validate WeChat SVG.
- WeChat rendering: distinguish local preview, backend save/reopen, and mobile WeChat preview. Claim only the checks actually completed.

If a stage fails, report the failed stage, missing artifact or prerequisite, and the actual next step. Never claim a skill, script, image, or approval was used or completed without evidence.
