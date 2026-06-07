# GZHRB Publish Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a stable one-click pipeline that generates a digest, writes a GZHRB article, creates an illustration plan, optionally generates article images, archives illustration assets, and writes the final copy-ready Markdown article by inserting images according to `placement.json`.

**Architecture:** Reuse the existing digest and GZHRB article generators. Add a new illustration-planning layer that writes article-scoped metadata into `reports/gzhrb/illustrations/<article-id>/`, then add a finalization layer that reads `placement.json` and rewrites the article safely. Keep each phase as a small PowerShell entrypoint with tests, and fail fast instead of guessing insertion positions.

**Tech Stack:** PowerShell 5+, existing Bun/TypeScript scripts, Markdown files, JSON metadata, existing image-generator command-line invocation pattern, Windows `.cmd` launchers.

---

## File Map

### Existing files to modify

- Modify: `E:\WorkCodex\ai-daily-digest\scripts\ai-daily-digest-launcher.ps1`
  - Extend launcher switches so the main flow can call the new plan/finalize stages later.
- Modify: `E:\WorkCodex\ai-daily-digest\README.md`
  - Document the new publish pipeline entrypoint and supporting scripts.

### Existing files to reference

- Reference: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb.ps1`
- Reference: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb.ts`
- Reference: `E:\WorkCodex\ai-daily-digest\scripts\organize-gzhrb-illustrations.ps1`
- Reference: `E:\WorkCodex\ai-daily-digest\docs\superpowers\specs\2026-04-15-gzhrb-publish-pipeline-design.md`

### New files to create

- Create: `E:\WorkCodex\ai-daily-digest\scripts\plan-gzhrb-illustrations.ps1`
  - Build `outline.md`, `placement.json`, `batch.json`, and `prompts/` for one article.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\plan-gzhrb-illustrations.cmd`
  - Windows launcher for the planning script.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb-illustrations.ps1`
  - Read article-scoped `batch.json` and invoke image generation.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb-illustrations.cmd`
  - Windows launcher for the image-generation wrapper.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\finalize-gzhrb-article.ps1`
  - Read `placement.json`, verify image/title existence, insert images into Markdown, and overwrite the article.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\finalize-gzhrb-article.cmd`
  - Windows launcher for the finalizer.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\run-digest-gzhrb-publish-pipeline.cmd`
  - One-click pipeline entrypoint for digest -> article -> illustration plan -> image generation -> organize -> finalize.
- Create: `E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1`
- Create: `E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1`
- Create: `E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1`

## Shared Constraints

- Keep article ID equal to the article basename without extension, e.g. `gzhrb-20260415-1639`.
- Store all illustration assets under `reports/gzhrb/illustrations/<article-id>/`.
- Default max illustration count: 5.
- Only support heading-based placement in v1.
- Never guess if a target heading is missing.
- Never insert duplicate image blocks if the article has already been finalized.
- Default behavior is to overwrite the same `gzhrb-*.md` file, not create `-final.md`.

## Task 1: Add Placement Model And Finalizer Core

**Files:**
- Create: `E:\WorkCodex\ai-daily-digest\scripts\finalize-gzhrb-article.ps1`
- Create: `E:\WorkCodex\ai-daily-digest\scripts\finalize-gzhrb-article.cmd`
- Test: `E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1`

- [ ] **Step 1: Write the failing test for article ID extraction**

```powershell
$articleId = Get-ArticleIdFromPath 'E:\WorkCodex\ai-daily-digest\reports\gzhrb\gzhrb-20260415-1639.md'
Assert-Equal $articleId 'gzhrb-20260415-1639' 'Should derive article id from article file name'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
```

Expected: FAIL because `finalize-gzhrb-article.ps1` or `Get-ArticleIdFromPath` does not exist yet.

- [ ] **Step 3: Write the minimal finalizer skeleton**

Implement in `scripts/finalize-gzhrb-article.ps1`:

```powershell
function Get-ArticleIdFromPath {
    param([Parameter(Mandatory)][string]$ArticlePath)
    return [System.IO.Path]::GetFileNameWithoutExtension($ArticlePath)
}
```

Also create a thin `.cmd` wrapper that mirrors the style used by `generate-gzhrb.cmd`.

- [ ] **Step 4: Run test to verify article ID extraction passes**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
```

Expected: PASS for the article ID test only.

- [ ] **Step 5: Write the failing test for `placement.json` parsing**

Use a temporary directory and fixture:

```powershell
$placements = Read-PlacementFile $placementPath
Assert-Equal $placements.Count 2 'Should read two placement records'
Assert-Equal $placements[0].after_heading '## 先把这件事说简单一点' 'Should preserve target heading'
```

- [ ] **Step 6: Run test to verify placement parsing fails**

Run the same test file and expect FAIL because `Read-PlacementFile` does not exist yet.

- [ ] **Step 7: Implement `Read-PlacementFile` and minimal schema validation**

Validate that each record contains:

- `slot`
- `after_heading`
- `image`
- `alt`

Reject missing or blank values with a clear error.

- [ ] **Step 8: Run test to verify placement parsing passes**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
```

Expected: PASS for article ID and placement parsing tests.

- [ ] **Step 9: Write the failing test for heading lookup**

Fixture article:

```md
# 标题

## 第一节

正文 1

## 第二节

正文 2
```

Test:

```powershell
$index = Find-HeadingLineIndex -Lines $lines -Heading '## 第二节'
Assert-Equal $index 5 'Should find heading line index for second heading'
```

- [ ] **Step 10: Run test to verify heading lookup fails**

Expected: FAIL because `Find-HeadingLineIndex` does not exist yet.

- [ ] **Step 11: Implement heading lookup with exact matching**

Do not normalize away heading levels. Match the full heading string exactly.

- [ ] **Step 12: Run test to verify heading lookup passes**

Expected: PASS for the heading lookup test.

- [ ] **Step 13: Write the failing test for Markdown insertion**

Test behavior:

- Find `after_heading`
- Insert image Markdown after that section block
- Use path format `illustrations/<article-id>/<image>`

Example assertion:

```powershell
Assert-True ($updated.Contains('![测试图](illustrations/gzhrb-20260415-1639/01-test.png)')) 'Should insert image markdown with archived path'
```

- [ ] **Step 14: Run test to verify insertion fails**

Expected: FAIL because the insertion function does not exist yet.

- [ ] **Step 15: Implement section-aware insertion**

Implement a function like:

```powershell
function Insert-IllustrationAfterHeadingSection {
    param(
        [string]$Markdown,
        [string]$ArticleId,
        [object]$Placement
    )
}
```

Rules:

- Insert after the current heading block, before the next heading of same or higher level.
- Preserve original line endings consistently.
- Add one blank line before and after the image block.

- [ ] **Step 16: Run test to verify insertion passes**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
```

Expected: PASS for insertion test.

- [ ] **Step 17: Write the failing test for idempotency**

If the image block already exists under the target section, re-running finalization should not add a second copy.

- [ ] **Step 18: Run test to verify idempotency fails**

Expected: FAIL because duplicate detection is not implemented yet.

- [ ] **Step 19: Implement duplicate detection**

Use the exact archived image path under the target section as the idempotency key.

- [ ] **Step 20: Run the finalizer test suite**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
```

Expected: all tests PASS.

- [ ] **Step 21: Commit**

```bash
git add scripts/finalize-gzhrb-article.ps1 scripts/finalize-gzhrb-article.cmd scripts/tests/finalize-gzhrb-article.tests.ps1
git commit -m "feat: add gzhrb article finalizer"
```

## Task 2: Add Article-Scoped Illustration Planning

**Files:**
- Create: `E:\WorkCodex\ai-daily-digest\scripts\plan-gzhrb-illustrations.ps1`
- Create: `E:\WorkCodex\ai-daily-digest\scripts\plan-gzhrb-illustrations.cmd`
- Test: `E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1`

- [ ] **Step 1: Write the failing test for article directory resolution**

```powershell
$dir = Get-ArticleIllustrationsDir -ArticlePath $articlePath -IllustrationsRoot $illustrationsRoot
Assert-Equal $dir (Join-Path $illustrationsRoot 'gzhrb-20260415-1639') 'Should resolve article-scoped illustration directory'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1'
```

Expected: FAIL because the planning script does not exist yet.

- [ ] **Step 3: Implement the planning script skeleton**

Add helper functions for:

- article ID
- article-scoped illustrations dir
- prompts dir

- [ ] **Step 4: Run test to verify directory resolution passes**

Expected: PASS for the directory-resolution test.

- [ ] **Step 5: Write the failing test for heading extraction**

Test against a fixture article with 2-5 headings. The planner should return only eligible headings for v1, such as `##` and `###`.

- [ ] **Step 6: Run test to verify heading extraction fails**

Expected: FAIL because extraction is not implemented yet.

- [ ] **Step 7: Implement heading extraction**

Add:

```powershell
function Get-EligibleArticleHeadings {
    param([string]$Markdown)
}
```

Rules:

- keep `##` and `###`
- ignore `# 标题备选`
- ignore empty sections

- [ ] **Step 8: Run test to verify heading extraction passes**

Expected: PASS.

- [ ] **Step 9: Write the failing test for placement generation**

Placement generation should:

- choose up to 5 headings
- assign sequential slots
- produce default image names like `01-framework-<slug>.png`
- include `after_heading`

- [ ] **Step 10: Run test to verify placement generation fails**

Expected: FAIL because placement generation does not exist yet.

- [ ] **Step 11: Implement placement generation**

Add:

```powershell
function New-PlacementPlan {
    param(
        [string]$ArticlePath,
        [string]$Markdown
    )
}
```

Use deterministic slugs derived from headings. Keep file naming stable for repeated runs.

- [ ] **Step 12: Run test to verify placement generation passes**

Expected: PASS.

- [ ] **Step 13: Write the failing test for file materialization**

The planner should write:

- `placement.json`
- `outline.md`
- `batch.json`
- `prompts/NN-*.md`

under the article-scoped directory.

- [ ] **Step 14: Run test to verify file materialization fails**

Expected: FAIL because output writing is not implemented yet.

- [ ] **Step 15: Implement file materialization**

Minimum content requirements:

- `placement.json`: strict machine-readable mapping
- `outline.md`: human-readable summary with purpose and position
- `batch.json`: image task list for the generator wrapper
- `prompts/`: one prompt file per planned illustration

Keep prompt content minimal but valid for downstream generation.

- [ ] **Step 16: Run the planning test suite**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1'
```

Expected: all tests PASS.

- [ ] **Step 17: Commit**

```bash
git add scripts/plan-gzhrb-illustrations.ps1 scripts/plan-gzhrb-illustrations.cmd scripts/tests/plan-gzhrb-illustrations.tests.ps1
git commit -m "feat: add gzhrb illustration planning"
```

## Task 3: Add Article-Scoped Image Generation Wrapper

**Files:**
- Create: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb-illustrations.ps1`
- Create: `E:\WorkCodex\ai-daily-digest\scripts\generate-gzhrb-illustrations.cmd`
- Test: `E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1`

- [ ] **Step 1: Write the failing test for article directory batch resolution**

```powershell
$batchPath = Get-ArticleBatchPath -ArticlePath $articlePath -IllustrationsRoot $illustrationsRoot
Assert-Equal $batchPath (Join-Path $illustrationsRoot 'gzhrb-20260415-1639\batch.json') 'Should resolve article batch file path'
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1'
```

Expected: FAIL because the wrapper script does not exist yet.

- [ ] **Step 3: Implement the generator wrapper skeleton**

Helper functions:

- `Get-ArticleBatchPath`
- `Get-IllustrationGeneratorScriptPath`
- `Build-IllustrationGeneratorCommand`

- [ ] **Step 4: Run test to verify batch resolution passes**

Expected: PASS for path resolution.

- [ ] **Step 5: Write the failing test for command construction**

Assert that the wrapper builds a command equivalent to:

```powershell
bun <illustration-generator-script> --batchfile <batch.json> --jobs 2 --json
```

- [ ] **Step 6: Run test to verify command construction fails**

Expected: FAIL because builder logic is not implemented yet.

- [ ] **Step 7: Implement deterministic command construction**

Rules:

- default `--jobs 2`
- default `--json`
- working directory should be the article-scoped illustration dir

- [ ] **Step 8: Run test to verify command construction passes**

Expected: PASS.

- [ ] **Step 9: Write the failing test for missing batch failure**

If `batch.json` is missing, the wrapper must stop with a clear error mentioning the article path and expected batch path.

- [ ] **Step 10: Run test to verify missing batch failure fails**

Expected: FAIL because explicit error handling is not implemented yet.

- [ ] **Step 11: Implement wrapper execution and preflight validation**

Do not mock the real image generator in production code. In tests, validate command building and missing-file behavior without running external generation.

- [ ] **Step 12: Run the generator wrapper test suite**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1'
```

Expected: all tests PASS.

- [ ] **Step 13: Commit**

```bash
git add scripts/generate-gzhrb-illustrations.ps1 scripts/generate-gzhrb-illustrations.cmd scripts/tests/generate-gzhrb-illustrations.tests.ps1
git commit -m "feat: add gzhrb illustration generation wrapper"
```

## Task 4: Integrate Finalizer With Existing Organizer

**Files:**
- Modify: `E:\WorkCodex\ai-daily-digest\scripts\organize-gzhrb-illustrations.ps1`
- Modify: `E:\WorkCodex\ai-daily-digest\scripts\tests\organize-gzhrb-illustrations.tests.ps1`

- [ ] **Step 1: Write the failing test for preserving `placement.json`**

When the organizer moves article assets into the article-scoped directory, `placement.json` must move with them if it exists in the root or remain untouched if already archived.

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\organize-gzhrb-illustrations.tests.ps1'
```

Expected: FAIL because the organizer does not know about `placement.json` yet.

- [ ] **Step 3: Implement `placement.json` preservation**

If the root-level plan belongs to the current article, move:

- `outline.md`
- `batch.json`
- `placement.json`
- prompt files
- images

to the article-scoped directory.

- [ ] **Step 4: Run organizer tests**

Expected: PASS with the new placement behavior.

- [ ] **Step 5: Commit**

```bash
git add scripts/organize-gzhrb-illustrations.ps1 scripts/tests/organize-gzhrb-illustrations.tests.ps1
git commit -m "feat: preserve placement metadata during illustration organize"
```

## Task 5: Add Publish Pipeline Entry Point

**Files:**
- Create: `E:\WorkCodex\ai-daily-digest\scripts\run-digest-gzhrb-publish-pipeline.cmd`
- Modify: `E:\WorkCodex\ai-daily-digest\scripts\ai-daily-digest-launcher.ps1`

- [ ] **Step 1: Write the failing test or checklist for launcher flags**

Because the launcher is interactive, use a script-level checklist instead of a heavy automated test. Verify the planned flags exist:

- `-GenerateGzhrb`
- new plan/generate/finalize orchestration path where appropriate

- [ ] **Step 2: Implement pipeline command wrapper**

Create a `.cmd` file that calls the launcher or supporting scripts in this order:

1. digest
2. GZHRB article
3. illustration plan
4. illustration generation
5. illustration organize
6. article finalize

- [ ] **Step 3: Add conservative failure handling**

Each phase must stop the pipeline if the previous one failed. Do not continue to finalization if image generation or organization failed.

- [ ] **Step 4: Dry-run the sequence manually on an existing article**

Run commands individually in a test article context to confirm ordering and paths are correct.

- [ ] **Step 5: Commit**

```bash
git add scripts/run-digest-gzhrb-publish-pipeline.cmd scripts/ai-daily-digest-launcher.ps1
git commit -m "feat: add gzhrb publish pipeline entrypoint"
```

## Task 6: Update Documentation

**Files:**
- Modify: `E:\WorkCodex\ai-daily-digest\README.md`

- [ ] **Step 1: Add the new publish pipeline usage**

Document:

- one-click publish pipeline
- supporting plan/generate/finalize commands
- final article overwrite behavior

- [ ] **Step 2: Add troubleshooting notes**

Document failure cases:

- missing `placement.json`
- missing headings
- missing images
- already finalized article

- [ ] **Step 3: Re-read the README for consistency**

Make sure the list of supported run modes reflects reality. Remove or update any stale “3 kinds of usage” language.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document gzhrb publish pipeline"
```

## Task 7: End-To-End Verification

**Files:**
- Verify: `E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1`
- Verify: `E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1`
- Verify: `E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1`
- Verify: `E:\WorkCodex\ai-daily-digest\scripts\tests\organize-gzhrb-illustrations.tests.ps1`

- [ ] **Step 1: Run all PowerShell tests**

```powershell
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\finalize-gzhrb-article.tests.ps1'
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\plan-gzhrb-illustrations.tests.ps1'
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\generate-gzhrb-illustrations.tests.ps1'
& 'E:\WorkCodex\ai-daily-digest\scripts\tests\organize-gzhrb-illustrations.tests.ps1'
```

Expected: all PASS.

- [ ] **Step 2: Run a manual article finalization dry run**

Use an existing article under `reports/gzhrb/` with a fixture `placement.json` and fixture images.

Expected:

- images are archived in the article directory
- article contains exactly one image block per placement record
- re-running the finalizer does not duplicate images

- [ ] **Step 3: Run the full publish pipeline manually**

Command:

```bat
scripts\run-digest-gzhrb-publish-pipeline.cmd
```

Expected:

- digest file created
- GZHRB article created
- article-scoped illustration plan created
- image generation invoked against article `batch.json`
- illustration assets organized
- final article contains inserted image Markdown

- [ ] **Step 4: Capture final verification notes**

Record:

- exact commands run
- produced article path
- produced illustration directory path
- any known limitations

- [ ] **Step 5: Commit final verification or cleanup changes**

```bash
git add .
git commit -m "chore: verify gzhrb publish pipeline"
```

## Notes For Implementation

- Prefer focused helper functions over one large script body.
- Keep the Markdown manipulation logic in the finalizer isolated and testable.
- Keep image generation as a thin wrapper around the existing illustration generator toolchain instead of copying its logic.
- The current repo contains unrelated uncommitted changes. During implementation, avoid sweeping `git add .`; stage only the files listed in each task.
- If article heading text changes after planning, finalization should fail with a clear error and require the plan to be regenerated. Do not auto-heal by fuzzy matching in v1.
