# GZHRB 半自动人工关口与正式双 Skill 硬门禁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `AI杨侦探` 工作流改造成带 4 个人工关口、强制 provenance/approval 双证据、最终交付到 `publish-units/<article-id>/` 的半自动严格流程。

**Architecture:** 保留现有 `topics/`、`workitems/`、`drafts/`、`illustrations/` 作为中间产物层，新增 `approvals/`、`provenance/`、`articles/`、`publish-units/`。先升级 workitem 与校验逻辑，让“文件存在”不再等于“阶段完成”，再把最终发布包装写入文章级 `publish-unit` 目录，最后补统一 approval/provenance 入口和文档。

**Tech Stack:** PowerShell, CMD wrappers, Bun/TypeScript packaging script, JSON workitems, Markdown article pipeline, existing PowerShell test suite

---

### Task 1: 扩展工作区初始化与目录模型

**Files:**
- Modify: `scripts/prepare-gzhrb-writing-workspace.ps1`
- Modify: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `日常操作说明.md`

- [ ] **Step 1: 先读现有测试与初始化脚本，确认当前 workitem 和路径模型**

Run: `Get-Content -Raw scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`
Expected: 能看到当前只校验 `drafts/workitems/illustrations` 与旧路径约定

- [ ] **Step 2: 先写失败测试，要求初始化时创建新目录和新状态**

在 `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1` 增加断言：
- `reports/gzhrb/approvals/<article-id>/`
- `reports/gzhrb/provenance/<article-id>/`
- `reports/gzhrb/articles/<article-id>/`
- `reports/gzhrb/publish-units/<article-id>/`
- workitem 默认 `stage = awaiting_topic_approval`
- `paths.optimized_article` 指向 `reports/gzhrb/articles/<article-id>/article.md`
- `paths.publish_unit_dir` 指向 `reports/gzhrb/publish-units/<article-id>/`

- [ ] **Step 3: 运行测试，确认新断言先失败**

Run: `& '.\scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1'`
Expected: FAIL，错误指向缺少新目录或旧状态仍是 `awaiting_khazix_writer`

- [ ] **Step 4: 最小改造初始化脚本**

在 `scripts/prepare-gzhrb-writing-workspace.ps1` 中：
- 创建 `approvals/<article-id>/`
- 创建 `provenance/<article-id>/`
- 创建 `articles/<article-id>/`
- 创建 `publish-units/<article-id>/`
- 把正式文章工作路径改成 `articles/<article-id>/article.md`
- 在 `paths` 中新增：
  - `article_dir`
  - `approval_dir`
  - `provenance_dir`
  - `publish_unit_dir`
- workitem 初始状态改成 `awaiting_topic_approval`
- `next_steps` 改成先人工确认选题，再执行 `khazix`

- [ ] **Step 5: 运行测试确认通过**

Run: `& '.\scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1'`
Expected: PASS

- [ ] **Step 6: 更新项目文档中的目录与路径说明**

更新：
- `AGENTS.md`
- `README.md`
- `日常操作说明.md`

要求：
- 说明 `articles/` 是工作副本
- `publish-units/` 是最终交付
- 不再把正式文章定义为 `reports/gzhrb/gzhrb-*.md`

- [ ] **Step 7: 提交**

```bash
git add AGENTS.md README.md 日常操作说明.md scripts/prepare-gzhrb-writing-workspace.ps1 scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1
git commit -m "feat: initialize gzhrb hard-gate workspace layout"
```

### Task 2: 引入状态机与 approval/provenance 基础模型

**Files:**
- Modify: `scripts/validate-gzhrb-writing-state.ps1`
- Modify: `scripts/inspect-gzhrb-writing-state.ps1`
- Modify: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- Modify: `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`

- [ ] **Step 1: 写失败测试，覆盖新状态机**

在 `scripts/tests/validate-gzhrb-writing-state.tests.ps1` 和 `scripts/tests/inspect-gzhrb-writing-state.tests.ps1` 增加场景：
- 只有 `topic-selected.json` 缺失时应停在 `awaiting_topic_approval`
- `khazix` 文件存在但无 provenance 时必须阻断
- `khazix` provenance 存在但无 approval 时必须停在 `awaiting_khazix_approval`
- `wechat` 文件存在但无 provenance 时必须阻断
- `wechat` approval 缺失时不能进入 post-writing
- `illustration` approval 缺失时不能进入 `ready_for_publish_unit`

- [ ] **Step 2: 运行测试确认失败**

Run: `& '.\scripts\tests\validate-gzhrb-writing-state.tests.ps1'`
Expected: FAIL，出现旧状态机与新期望不一致

- [ ] **Step 3: 扩展 validation 脚本的数据模型**

在 `scripts/validate-gzhrb-writing-state.ps1` 中新增辅助函数：
- 解析 `approval_dir`、`provenance_dir`
- 读取 approval 文件是否存在
- 读取 provenance 文件并校验：
  - `skill_name`
  - `output_path`
  - `status`
- 返回结构中新增：
  - `approval_state`
  - `provenance_state`
  - `missing_evidence`

把状态机改成：
- `awaiting_topic_approval`
- `awaiting_khazix_execution`
- `awaiting_khazix_approval`
- `awaiting_wechat_execution`
- `awaiting_wechat_approval`
- `awaiting_illustration_execution`
- `awaiting_illustration_approval`
- `ready_for_publish_unit`
- `completed`

- [ ] **Step 4: 扩展 inspect 输出**

在 `scripts/inspect-gzhrb-writing-state.ps1` 中打印：
- topic approval
- khazix provenance
- khazix approval
- wechat provenance
- wechat approval
- illustration provenance
- illustration approval
- 缺失证据列表

- [ ] **Step 5: 运行测试确认通过**

Run:
- `& '.\scripts\tests\validate-gzhrb-writing-state.tests.ps1'`
- `& '.\scripts\tests\inspect-gzhrb-writing-state.tests.ps1'`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/validate-gzhrb-writing-state.ps1 scripts/inspect-gzhrb-writing-state.ps1 scripts/tests/validate-gzhrb-writing-state.tests.ps1 scripts/tests/inspect-gzhrb-writing-state.tests.ps1
git commit -m "feat: enforce approval and provenance in writing state validation"
```

### Task 3: 新增统一 approval 入口

**Files:**
- Create: `scripts/approve-gzhrb-stage.ps1`
- Create: `scripts/approve-gzhrb-stage.cmd`
- Create: `scripts/tests/approve-gzhrb-stage.tests.ps1`
- Modify: `scripts/gzhrb-writing-state.ps1`
- Modify: `scripts/gzhrb-writing-state.cmd`

- [ ] **Step 1: 写失败测试，定义 approval 写入与状态推进**

在 `scripts/tests/approve-gzhrb-stage.tests.ps1` 中覆盖：
- 批准 `topic_selected` 后，workitem 进入 `awaiting_khazix_execution`
- 批准 `khazix_approved` 后，进入 `awaiting_wechat_execution`
- 批准 `wechat_approved` 后，进入 `awaiting_illustration_execution`
- 批准 `illustrations_approved` 后，进入 `ready_for_publish_unit`
- 不合法阶段或缺少前置证据时必须失败

- [ ] **Step 2: 运行测试确认失败**

Run: `& '.\scripts\tests\approve-gzhrb-stage.tests.ps1'`
Expected: FAIL，因为脚本尚不存在

- [ ] **Step 3: 实现 approval 脚本**

在 `scripts/approve-gzhrb-stage.ps1` 中实现：
- 参数：
  - `-ArticlePath`
  - `-Stage`
  - `-ApprovedBy`
  - `-Note`
- 写入 `approvals/<article-id>/<stage-file>.json`
- 校验前置条件：
  - `khazix_approved` 前必须已有 khazix provenance
  - `wechat_approved` 前必须已有 wechat provenance
  - `illustrations_approved` 前必须已有 illustration provenance
- 更新 workitem `stage`
- 追加 execution_log

- [ ] **Step 4: 把统一入口接进 `gzhrb-writing-state`**

在 `scripts/gzhrb-writing-state.ps1` / `.cmd` 中新增命令：
- `approve-topic`
- `approve-khazix`
- `approve-wechat`
- `approve-illustrations`

- [ ] **Step 5: 运行测试确认通过**

Run:
- `& '.\scripts\tests\approve-gzhrb-stage.tests.ps1'`
- `& '.\scripts\tests\gzhrb-writing-state.cmd.tests.ps1'`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/approve-gzhrb-stage.ps1 scripts/approve-gzhrb-stage.cmd scripts/gzhrb-writing-state.ps1 scripts/gzhrb-writing-state.cmd scripts/tests/approve-gzhrb-stage.tests.ps1 scripts/tests/gzhrb-writing-state.cmd.tests.ps1
git commit -m "feat: add approval gate commands for gzhrb workflow"
```

### Task 4: 强化 khazix/wechat 完成标记逻辑

**Files:**
- Modify: `scripts/mark-gzhrb-khazix-complete.ps1`
- Modify: `scripts/mark-gzhrb-khazix-complete.cmd`
- Modify: `scripts/mark-gzhrb-wechat-complete.ps1`
- Modify: `scripts/mark-gzhrb-wechat-complete.cmd`
- Modify: `scripts/tests/mark-gzhrb-writing-state.tests.ps1`

- [ ] **Step 1: 写失败测试，要求标记完成必须检查 provenance**

在 `scripts/tests/mark-gzhrb-writing-state.tests.ps1` 中增加场景：
- draft 存在但无 `khazix-execution.json` 时，`mark-khazix` 必须失败
- article 存在但无 `wechat-execution.json` 时，`mark-wechat` 必须失败
- 成功标记后状态分别推进到：
  - `awaiting_khazix_approval`
  - `awaiting_wechat_approval`

- [ ] **Step 2: 运行测试确认失败**

Run: `& '.\scripts\tests\mark-gzhrb-writing-state.tests.ps1'`
Expected: FAIL

- [ ] **Step 3: 改造完成标记脚本**

要求：
- 校验对应 provenance 文件存在
- 校验其中 `skill_name`、`output_path`、`status`
- 不再直接推进到执行后的下一执行阶段
- 只推进到对应 approval 等待阶段

- [ ] **Step 4: 运行测试确认通过**

Run: `& '.\scripts\tests\mark-gzhrb-writing-state.tests.ps1'`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/mark-gzhrb-khazix-complete.ps1 scripts/mark-gzhrb-khazix-complete.cmd scripts/mark-gzhrb-wechat-complete.ps1 scripts/mark-gzhrb-wechat-complete.cmd scripts/tests/mark-gzhrb-writing-state.tests.ps1
git commit -m "feat: require provenance for khazix and wechat completion marks"
```

### Task 5: 引入 provenance 写入入口与最小可审计结构

**Files:**
- Create: `scripts/write-gzhrb-provenance.ps1`
- Create: `scripts/write-gzhrb-provenance.cmd`
- Create: `scripts/tests/write-gzhrb-provenance.tests.ps1`
- Modify: `README.md`
- Modify: `日常操作说明.md`

- [ ] **Step 1: 写失败测试，定义 provenance 文件格式**

在 `scripts/tests/write-gzhrb-provenance.tests.ps1` 中断言输出 JSON 包含：
- `article_id`
- `skill_name`
- `session_id`
- `input_path`
- `output_path`
- `started_at`
- `completed_at`
- `status`

- [ ] **Step 2: 运行测试确认失败**

Run: `& '.\scripts\tests\write-gzhrb-provenance.tests.ps1'`
Expected: FAIL

- [ ] **Step 3: 实现 provenance 脚本**

在 `scripts/write-gzhrb-provenance.ps1` 中实现：
- 参数：
  - `-ArticlePath`
  - `-SkillName`
  - `-InputPath`
  - `-OutputPath`
  - `-SessionId`
  - `-Status`
  - `-Note`
- 根据 skill 名自动写到：
  - `khazix-execution.json`
  - `wechat-execution.json`
  - `illustration-execution.json`

- [ ] **Step 4: 在文档中明确“正式执行后必须先写 provenance，再标记 complete”**

更新：
- `README.md`
- `日常操作说明.md`

- [ ] **Step 5: 运行测试确认通过**

Run: `& '.\scripts\tests\write-gzhrb-provenance.tests.ps1'`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/write-gzhrb-provenance.ps1 scripts/write-gzhrb-provenance.cmd scripts/tests/write-gzhrb-provenance.tests.ps1 README.md 日常操作说明.md
git commit -m "feat: add provenance writer for formal skill execution"
```

### Task 6: 改造后写作入口与发布包装输出目录

**Files:**
- Modify: `scripts/run-gzhrb-postwriting-pipeline.ps1`
- Modify: `scripts/run-gzhrb-postwriting-pipeline.cmd`
- Modify: `scripts/finalize-gzhrb-article.ps1`
- Modify: `scripts/package-gzhrb-article.ps1`
- Modify: `scripts/package-gzhrb-article.ts`
- Modify: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`
- Modify: `scripts/tests/finalize-gzhrb-article.tests.ps1`

- [ ] **Step 1: 写失败测试，定义 post-writing 放行前提**

在 `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1` 新增断言：
- 缺 `wechat-approved.json` 时必须阻断
- 缺 `wechat-execution.json` 时必须阻断
- 只有 `ready_for_publish_unit` 才能继续后半段

- [ ] **Step 2: 写失败测试，定义最终发布单元目录输出**

在 `scripts/tests/finalize-gzhrb-article.tests.ps1` 或新增相关断言：
- 最终发布相关文件写入 `publish-units/<article-id>/`
- `article.md` 为最终图文版
- 包装产物不再只留在工作稿顶部而无独立文件

- [ ] **Step 3: 运行测试确认失败**

Run:
- `& '.\scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1'`
- `& '.\scripts\tests\finalize-gzhrb-article.tests.ps1'`
Expected: FAIL

- [ ] **Step 4: 改造后写作入口**

在 `scripts/run-gzhrb-postwriting-pipeline.ps1` / `.cmd` 中：
- 放行前要求：
  - wechat 文件存在
  - wechat provenance 存在
  - wechat approval 存在
- 修复现有 `.cmd` / `.ps1` 参数转发和脚本作用域坏味道

- [ ] **Step 5: 改造 finalize 与 package 输出**

目标：
- `articles/<article-id>/article.md` 仍作为工作副本
- `package-gzhrb-article.*` 最终把交付结果写到 `publish-units/<article-id>/`
- 输出：
  - `article.md`
  - `titles.txt`
  - `intro-lines.txt`
  - `topic-tags.txt`
  - `package.json`
  - `review-checklist.md`
- 图片引用在 publish-unit 内稳定成立

- [ ] **Step 6: 运行测试确认通过**

Run:
- `& '.\scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1'`
- `& '.\scripts\tests\finalize-gzhrb-article.tests.ps1'`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add scripts/run-gzhrb-postwriting-pipeline.ps1 scripts/run-gzhrb-postwriting-pipeline.cmd scripts/finalize-gzhrb-article.ps1 scripts/package-gzhrb-article.ps1 scripts/package-gzhrb-article.ts scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1 scripts/tests/finalize-gzhrb-article.tests.ps1
git commit -m "feat: gate post-writing by approval and emit publish units"
```

### Task 7: 扩展插图完成判定与 publish-unit 完成判定

**Files:**
- Modify: `scripts/validate-gzhrb-writing-state.ps1`
- Modify: `scripts/inspect-gzhrb-writing-state.ps1`
- Modify: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- Modify: `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`

- [ ] **Step 1: 写失败测试，覆盖 illustration 与 completed 最终状态**

新增断言：
- `illustration-execution.json` 存在但无 `illustrations-approved.json` 时，状态是 `awaiting_illustration_approval`
- `publish-units/<article-id>/` 缺核心文件时不能进 `completed`
- publish-unit 完整后，状态为 `completed`

- [ ] **Step 2: 运行测试确认失败**

Run:
- `& '.\scripts\tests\validate-gzhrb-writing-state.tests.ps1'`
- `& '.\scripts\tests\inspect-gzhrb-writing-state.tests.ps1'`
Expected: FAIL

- [ ] **Step 3: 补全最终状态判断**

在 validation 中加入：
- `ready_for_publish_unit`
- `completed`

其中 `completed` 必须校验 `publish-unit` 目录完整性。

- [ ] **Step 4: 运行测试确认通过**

Run:
- `& '.\scripts\tests\validate-gzhrb-writing-state.tests.ps1'`
- `& '.\scripts\tests\inspect-gzhrb-writing-state.tests.ps1'`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/validate-gzhrb-writing-state.ps1 scripts/inspect-gzhrb-writing-state.ps1 scripts/tests/validate-gzhrb-writing-state.tests.ps1 scripts/tests/inspect-gzhrb-writing-state.tests.ps1
git commit -m "feat: add illustration approval and publish-unit completion states"
```

### Task 8: 补全文档与日常操作卡

**Files:**
- Modify: `README.md`
- Modify: `日常操作说明.md`
- Modify: `docs/gzhrb-writing-checklist.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: 更新正式流程说明**

明确写出：
- 4 个人工关口
- 3 类证据：产物 / provenance / approval
- `articles/` 与 `publish-units/` 区别

- [ ] **Step 2: 更新日常执行卡**

在 `docs/gzhrb-writing-checklist.md` 中加入新的最短操作顺序：
1. 生成候选题
2. 批准选题
3. 写 provenance
4. mark complete
5. 批准阶段
6. 下一阶段

- [ ] **Step 3: 运行最小文档相关验证**

Run: `rg -n "publish-units|approvals|provenance|awaiting_topic_approval|awaiting_khazix_approval|awaiting_wechat_approval|awaiting_illustration_approval" README.md AGENTS.md 日常操作说明.md docs/gzhrb-writing-checklist.md`
Expected: 新术语与新目录均已覆盖

- [ ] **Step 4: 提交**

```bash
git add README.md 日常操作说明.md docs/gzhrb-writing-checklist.md AGENTS.md
git commit -m "docs: document semi-automatic hard-gate gzhrb workflow"
```

### Task 9: 端到端回归验证

**Files:**
- Modify: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`
- Modify: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- Modify: `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`
- Modify: `scripts/tests/mark-gzhrb-writing-state.tests.ps1`
- Modify: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

- [ ] **Step 1: 运行核心测试集**

Run:
```powershell
& '.\scripts\tests\prepare-gzhrb-writing-workspace.tests.ps1'
& '.\scripts\tests\validate-gzhrb-writing-state.tests.ps1'
& '.\scripts\tests\inspect-gzhrb-writing-state.tests.ps1'
& '.\scripts\tests\mark-gzhrb-writing-state.tests.ps1'
& '.\scripts\tests\run-gzhrb-postwriting-pipeline.tests.ps1'
& '.\scripts\tests\finalize-gzhrb-article.tests.ps1'
```
Expected: 全部 PASS

- [ ] **Step 2: 跑一次手工最小回归**

手工验证顺序：
1. 创建新 workitem
2. 检查 `awaiting_topic_approval`
3. 手工写入 `topic-selected.json`
4. 写入一份假 khazix provenance + 初稿
5. mark khazix complete
6. approval khazix
7. 写入一份假 wechat provenance + 工作稿
8. mark wechat complete
9. approval wechat
10. 验证 post-writing 放行

Expected: 状态推进符合 spec

- [ ] **Step 3: 记录验证结果**

把实际跑过的命令和结论记到提交说明或相关文档里，避免再次出现“口头说跑通但其实绕过”的情况。

- [ ] **Step 4: 提交**

```bash
git add scripts/tests
git commit -m "test: cover hard-gate gzhrb workflow end to end"
```

