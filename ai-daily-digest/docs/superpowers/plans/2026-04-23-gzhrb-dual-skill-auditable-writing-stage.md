# GZHRB Dual-Skill Auditable Writing Stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the formal GZHRB writing stage auditable by separating `khazix` draft readiness, `wechat` optimized article readiness, and post-writing readiness with file-backed validation.

**Architecture:** Keep the existing workitem JSON/Markdown as the audit anchor, add a single reusable validation script for writing-stage truth checks, and make the post-writing entrypoint block unless the optimized article is truly ready. Extend current tests rather than introducing a new framework.

**Tech Stack:** PowerShell 5.1 scripts, existing `.cmd` wrappers, UTF-8 file IO helpers, repo Markdown docs, PowerShell test scripts under `scripts/tests`

---

### Task 1: Extend Workitem State Model

**Files:**
- Modify: `scripts/prepare-gzhrb-writing-workspace.ps1`
- Test: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`

- [ ] **Step 1: Write the failing test for writing_state fields**

Add assertions in `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1` for:
- `writing_state.khazix.status == pending`
- `writing_state.wechat.status == pending`
- workitem markdown includes the three formal stages

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1
```

Expected:
- FAIL because `writing_state` fields do not yet exist

- [ ] **Step 3: Write the minimal implementation**

Update `scripts/prepare-gzhrb-writing-workspace.ps1` to:
- add `writing_state.khazix.status = pending`
- add `writing_state.wechat.status = pending`
- add a concise three-stage description to the Markdown workitem

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1
```

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/prepare-gzhrb-writing-workspace.ps1 scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1
git commit -m "feat: extend gzhrb workitem writing state"
```

### Task 2: Add Reusable Writing-State Validator

**Files:**
- Create: `scripts/validate-gzhrb-writing-state.ps1`
- Test: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`

- [ ] **Step 1: Write the failing tests**

Create `scripts/tests/validate-gzhrb-writing-state.tests.ps1` to cover:
- missing workitem
- placeholder khazix draft
- khazix finished but missing optimized article
- valid optimized article present

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\validate-gzhrb-writing-state.tests.ps1
```

Expected:
- FAIL because the validator script does not exist yet

- [ ] **Step 3: Write minimal validator implementation**

Create `scripts/validate-gzhrb-writing-state.ps1` with functions that:
- derive article id from article path
- locate matching workitem JSON
- read khazix draft / optimized article paths from workitem
- detect placeholder khazix content
- return a result object with:
  - `stage`
  - `is_ready_for_postwriting`
  - `reason`
  - `next_step`

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\validate-gzhrb-writing-state.tests.ps1
```

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-gzhrb-writing-state.ps1 scripts/tests/validate-gzhrb-writing-state.tests.ps1
git commit -m "feat: add gzhrb writing state validator"
```

### Task 3: Block Post-Writing Pipeline Until Optimized Article Is Real

**Files:**
- Modify: `scripts/run-gzhrb-postwriting-pipeline.ps1`
- Create: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

- [ ] **Step 1: Write the failing tests**

Create `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1` with scenarios:
- optimized article missing -> pipeline stops before first stage
- khazix placeholder only -> pipeline stops with explicit message
- valid ready state -> validator allows post-writing stage entry

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1
```

Expected:
- FAIL because no validation gate exists yet

- [ ] **Step 3: Write minimal implementation**

Update `scripts/run-gzhrb-postwriting-pipeline.ps1` to:
- source `scripts/validate-gzhrb-writing-state.ps1`
- validate article before `illustration planning`
- throw a clear error when not `ready_for_postwriting`
- include current stage, missing evidence, and next-step guidance

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1
```

Expected:
- PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/run-gzhrb-postwriting-pipeline.ps1 scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1
git commit -m "feat: block postwriting until optimized article is ready"
```

### Task 4: Document the Difference Between Skill-Guided Writing and Formal Dual-Skill Execution

**Files:**
- Modify: `README.md`
- Modify: `日常操作说明.md`

- [ ] **Step 1: Add doc assertions to plan checklist**

Write down the exact doc points to add:
- definition of formal dual-skill execution
- definition of skill-guided manual writing
- post-writing pipeline now validates optimized article evidence

- [ ] **Step 2: Update README**

Add a short section in `README.md` that:
- explains the three writing stages
- explains why post-writing is blocked without a real optimized article
- distinguishes “按 skill 规范写” from “正式双 skill 留痕执行”

- [ ] **Step 3: Update 日常操作说明**

Add operational guidance that:
- tells users what each stage means
- tells users when they are allowed to continue
- tells users why the repo now hard-blocks post-writing without evidence

- [ ] **Step 4: Manually review docs for consistency**

Check:
- path examples still match current repo
- no section claims old behavior
- both docs describe the same boundary

- [ ] **Step 5: Commit**

```bash
git add README.md 日常操作说明.md
git commit -m "docs: clarify formal dual-skill writing stages"
```

### Task 5: Run Verification for the Whole Closure

**Files:**
- Verify only: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`
- Verify only: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- Verify only: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

- [ ] **Step 1: Run prepare workspace tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1
```

Expected:
- PASS

- [ ] **Step 2: Run validator tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\validate-gzhrb-writing-state.tests.ps1
```

Expected:
- PASS

- [ ] **Step 3: Run post-writing pipeline tests**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1
```

Expected:
- PASS

- [ ] **Step 4: Review git diff for unintended behavior changes**

Run:

```bash
git diff -- scripts README.md 日常操作说明.md docs/superpowers/specs docs/superpowers/plans
```

Expected:
- only intended script, test, and doc changes appear

- [ ] **Step 5: Commit verification-safe result**

```bash
git add scripts README.md 日常操作说明.md docs/superpowers/specs docs/superpowers/plans
git commit -m "feat: add auditable dual-skill writing closure"
```
