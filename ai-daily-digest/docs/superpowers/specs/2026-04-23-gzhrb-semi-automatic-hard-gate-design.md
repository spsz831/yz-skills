# GZHRB 半自动人工关口与正式双 Skill 硬门禁设计

## 背景

当前 `AI杨侦探` 工作流已经具备以下能力：

- 生成 `48 小时日报`
- 提取公众号候选题
- 为选题创建 workitem、固定初稿路径、固定优化稿路径和固定插图目录
- 用文件证据阻断未完成写作的后半段
- 完成插图规划、插图生成、归档、正文回填和发布包装

但当前实现仍然存在两个关键缺口：

1. “正式双 skill 执行”仍然可以被“当前 agent 按两个 skill 规范直接写两个文件”绕过
2. 最终稿件没有自己的文章级交付目录，正式文章仍会散落在 `reports\gzhrb\` 根目录

本设计的目标不是继续补文档说明，而是把这两件事做成真正不可绕过的流程硬约束。

---

## 目标

把 `AI杨侦探` 写作链路改造成一条严格的半自动工作流：

1. 日报和候选题阶段自动执行
2. 选题后必须人工确认
3. `khazix-writer` 正式执行后必须人工确认
4. `wechat-article-writer` 正式执行后必须人工确认
5. `baoyu-article-illustrator` 规划和生图后必须人工确认
6. 只有上述关口都放行，才允许自动执行归档、图片回填、发布包装
7. 最终交付必须落到文章级 `publish-units/<article-id>/` 目录

同时，“正式双 skill 执行”必须升级为技术上的硬门禁：

- 不能只靠文件存在就判定阶段完成
- 必须同时具备：
  - 对应产物文件
  - 对应 `provenance` 执行证据
  - 对应 `approval` 人工确认

缺任意一个，都不能推进到下一阶段。

---

## 非目标

本设计不解决以下问题：

- 不试图自动替用户做选题判断
- 不试图自动替用户做终审判断
- 不试图让仓库内脚本替代外部正式 skill 的内容生成职责
- 不试图在本轮直接把整个历史目录结构全部迁移成全文章级工作区

本轮优先目标是：

- 先让流程可审计、可卡关、不可绕过
- 再让最终交付目录清晰稳定

---

## 顶层流程

新的正式流程定义如下：

1. 生成 `48 小时日报`
2. 提取候选题材
3. 人工确认选题
4. `khazix-writer` 正式执行，产出初稿
5. 人工确认初稿
6. `wechat-article-writer` 正式执行，产出优化稿和标题备选
7. 人工确认优化稿
8. `baoyu-article-illustrator` 正式执行插图规划和插图生成
9. 人工确认插图
10. 归档素材、图片回填、发布包装
11. 生成最终可发布单元
12. 人工终审

流程中的四个强制人工关口：

- `topic_selected`
- `khazix_approved`
- `wechat_approved`
- `illustrations_approved`

说明：

- “人工终审”仍然保留，但它属于最终交付后的使用动作，不作为脚本层继续推进下一阶段的门禁
- 第 10 步以后只在第 9 步插图确认完成后才允许自动执行

---

## 目录设计

保留已有日报和健康日志目录：

- `reports\output\`：日报固定输出位置
- `reports\health\`：健康日志固定输出位置

`reports\gzhrb\` 新的职责划分如下：

```text
reports/
  output/
  health/
  gzhrb/
    topics/
    workitems/
    approvals/
    provenance/
    drafts/
    articles/
    illustrations/
    publish-units/
```

### `topics/`

用途：

- 保存候选题提取结果
- 对应日报时间戳

典型文件：

- `gzhrb-topics-20260423-2031.json`
- `gzhrb-topics-20260423-2031.md`

### `workitems/`

用途：

- 文章级主工作单
- 记录阶段、路径、状态、执行历史、下一步

典型文件：

- `<article-id>.json`
- `<article-id>.md`

### `approvals/`

用途：

- 记录人工关口是否已明确批准
- 一篇文章一个子目录

典型结构：

```text
reports/gzhrb/approvals/<article-id>/
  topic-selected.json
  khazix-approved.json
  wechat-approved.json
  illustrations-approved.json
```

### `provenance/`

用途：

- 记录正式 skill 执行证据
- 一篇文章一个子目录

典型结构：

```text
reports/gzhrb/provenance/<article-id>/
  khazix-execution.json
  wechat-execution.json
  illustration-execution.json
```

### `drafts/`

用途：

- 只保存 `khazix-writer` 初稿

典型文件：

- `<article-id>-khazix.md`

### `articles/`

用途：

- 保存 `wechat-article-writer` 优化后的工作稿
- 这是插图、回填、包装的主工作文件

典型结构：

```text
reports/gzhrb/articles/<article-id>/
  article.md
```

### `illustrations/`

用途：

- 保存文章级插图规划与图片资产

典型结构：

```text
reports/gzhrb/illustrations/<article-id>/
  placement.json
  batch.json
  outline.md
  prompts/
  *.png
```

### `publish-units/`

用途：

- 保存最终可发布单元
- 这是最终交付目录，不再允许正式文章散落在 `reports\gzhrb\` 根目录

典型结构：

```text
reports/gzhrb/publish-units/<article-id>/
  article.md
  titles.txt
  intro-lines.txt
  topic-tags.txt
  package.json
  review-checklist.md
  illustrations/
```

---

## 状态机设计

workitem 主状态明确拆成“执行”和“人工批准”两个维度之间的阶段跳转：

1. `awaiting_topic_approval`
2. `awaiting_khazix_execution`
3. `awaiting_khazix_approval`
4. `awaiting_wechat_execution`
5. `awaiting_wechat_approval`
6. `awaiting_illustration_execution`
7. `awaiting_illustration_approval`
8. `ready_for_publish_unit`
9. `completed`

推荐迁移规则：

- 候选题已生成但未确认时，进入 `awaiting_topic_approval`
- 选题确认后，进入 `awaiting_khazix_execution`
- `khazix-writer` 执行成功后，进入 `awaiting_khazix_approval`
- 初稿人工确认通过后，进入 `awaiting_wechat_execution`
- `wechat-article-writer` 执行成功后，进入 `awaiting_wechat_approval`
- 优化稿人工确认通过后，进入 `awaiting_illustration_execution`
- 插图规划与生图完成后，进入 `awaiting_illustration_approval`
- 插图人工确认通过后，进入 `ready_for_publish_unit`
- 最终发布单元生成后，进入 `completed`

---

## 正式双 Skill 不可绕过规则

### 核心原则

“阶段完成”不能只由产物文件决定。

每个正式阶段都要同时满足三类证据：

1. 产物文件存在
2. `provenance` 执行证据存在
3. `approval` 人工批准存在

### `khazix-writer` 正式完成条件

必须同时满足：

- `reports\gzhrb\drafts\<article-id>-khazix.md` 存在且非占位稿
- `reports\gzhrb\provenance\<article-id>\khazix-execution.json` 存在
- provenance 中 `skill_name = khazix-writer`
- provenance 中 `output_path` 等于上述 draft 路径
- provenance 中 `status = completed`

满足上述条件后，阶段状态只能推进到：

- `awaiting_khazix_approval`

只有用户批准后，写入：

- `reports\gzhrb\approvals\<article-id>\khazix-approved.json`

才允许推进到：

- `awaiting_wechat_execution`

### `wechat-article-writer` 正式完成条件

必须同时满足：

- `reports\gzhrb\articles\<article-id>\article.md` 存在且非空
- `reports\gzhrb\provenance\<article-id>\wechat-execution.json` 存在
- provenance 中 `skill_name = wechat-article-writer`
- provenance 中 `output_path` 指向 `articles/<article-id>/article.md`
- provenance 中 `status = completed`

满足后，只能进入：

- `awaiting_wechat_approval`

只有用户批准后，写入：

- `reports\gzhrb\approvals\<article-id>\wechat-approved.json`

才允许推进到：

- `awaiting_illustration_execution`

### `baoyu-article-illustrator` 正式完成条件

必须同时满足：

- `reports\gzhrb\illustrations\<article-id>\placement.json`
- `reports\gzhrb\illustrations\<article-id>\batch.json`
- `reports\gzhrb\illustrations\<article-id>\outline.md`
- `reports\gzhrb\illustrations\<article-id>\prompts\`
- 预期图片文件存在
- `reports\gzhrb\provenance\<article-id>\illustration-execution.json` 存在
- provenance 中 `skill_name = baoyu-article-illustrator`
- provenance 中 `status = completed`

满足后，只能进入：

- `awaiting_illustration_approval`

只有用户批准后，写入：

- `reports\gzhrb\approvals\<article-id>\illustrations-approved.json`

才允许推进到：

- `ready_for_publish_unit`

---

## 人工确认文件设计

每个 approval 文件建议采用统一结构：

```json
{
  "article_id": "<article-id>",
  "stage": "khazix_approved",
  "approved": true,
  "approved_by": "<user-or-session>",
  "approved_at": "<iso-timestamp>",
  "note": "<optional>"
}
```

每个 provenance 文件建议采用统一结构：

```json
{
  "article_id": "<article-id>",
  "skill_name": "khazix-writer",
  "session_id": "<session-id-or-equivalent>",
  "input_path": "<input-path>",
  "output_path": "<output-path>",
  "started_at": "<iso-timestamp>",
  "completed_at": "<iso-timestamp>",
  "status": "completed",
  "note": "<optional>"
}
```

说明：

- `session_id` 不是为了证明 skill 真正独立运行的全部真相，但至少提供了可审计的执行引用
- 后续如果有更强的 agent runtime 标识，可以扩展该字段

---

## 最终发布单元定义

“最终可发布单元”不再等价于某个散落在 `reports\gzhrb\` 根目录的 markdown 文件。

新的完成标准是：

必须存在：

```text
reports/gzhrb/publish-units/<article-id>/
  article.md
  titles.txt
  intro-lines.txt
  topic-tags.txt
  package.json
  review-checklist.md
  illustrations/
```

其中：

- `article.md`
  - 已完成图片回填
  - 引用路径在 publish-unit 内部稳定可用
- `titles.txt`
  - 标题备选
- `intro-lines.txt`
  - 引导语备选
- `topic-tags.txt`
  - 话题标签
- `package.json`
  - 当前发布单元元信息
- `review-checklist.md`
  - 最终人工终审卡
- `illustrations/`
  - 最终随稿图资产

只有该目录完整存在，才允许对外声称：

- 已生成最终可发布单元

---

## 脚本改造方向

### 1. `prepare-gzhrb-writing-workspace.ps1`

新增职责：

- 创建 `approvals/<article-id>/`
- 创建 `provenance/<article-id>/`
- 创建 `articles/<article-id>/`
- 创建 `publish-units/<article-id>/`
- workitem 默认状态改为 `awaiting_topic_approval`

### 2. `validate-gzhrb-writing-state.ps1`

现状：

- 只校验文件证据

目标：

- 同时校验：
  - 文件证据
  - provenance
  - approval

并能明确指出：

- 缺文件
- 缺 provenance
- 缺 approval
- 哪个阶段未放行

### 3. `inspect-gzhrb-writing-state.ps1`

新增输出：

- topic approval 状态
- khazix provenance 状态
- khazix approval 状态
- wechat provenance 状态
- wechat approval 状态
- illustration provenance 状态
- illustration approval 状态

### 4. `mark-gzhrb-khazix-complete.ps1`

改造目标：

- 不再只校验初稿存在
- 必须校验 `khazix-execution.json`
- 成功后把状态推进到 `awaiting_khazix_approval`

### 5. `mark-gzhrb-wechat-complete.ps1`

改造目标：

- 不再只校验优化稿存在
- 必须校验 `wechat-execution.json`
- 成功后把状态推进到 `awaiting_wechat_approval`

### 6. 新增 approval 入口

建议新增：

- `approve-gzhrb-stage.ps1`
- `approve-gzhrb-stage.cmd`

职责：

- 根据阶段写入 approval 文件
- 推进 workitem 到下一合法状态

### 7. `run-gzhrb-postwriting-pipeline.ps1`

放行前必须要求：

- `wechat` 文件存在
- `wechat provenance` 存在
- `wechat approval` 存在

不满足任意一项都阻断。

### 8. 发布包装脚本

目标：

- 最终结果输出到 `publish-units/<article-id>/`
- 而不是继续写散落文件到 `reports\gzhrb\` 根目录

---

## 兼容迁移策略

为了减少破坏面，本轮采用“增量迁移”：

1. 保留已有 `topics/`、`workitems/`、`drafts/`、`illustrations/`
2. 新增 `approvals/`、`provenance/`、`articles/`、`publish-units/`
3. 后续正式文章默认写入 `articles/<article-id>/article.md`
4. 最终交付默认写入 `publish-units/<article-id>/`
5. 已有散落在 `reports\gzhrb\` 根目录的历史文章不强制一次性迁移

这样可以保证：

- 新流程先变严
- 老数据不被一次性打乱

---

## 验收标准

本设计被正确实现，至少要满足以下标准：

1. 选题后若无 `topic-selected.json`，不得进入 `khazix` 阶段
2. 初稿文件存在但无 `khazix provenance` 时，不得声称正式 `khazix-writer` 已执行
3. 初稿已完成但无 `khazix approval` 时，不得进入 `wechat` 阶段
4. 优化稿文件存在但无 `wechat provenance` 时，不得声称正式 `wechat-article-writer` 已执行
5. 优化稿已完成但无 `wechat approval` 时，不得进入插图阶段
6. 插图产物存在但无 `illustration approval` 时，不得进入发布单元生成阶段
7. `publish-units/<article-id>/` 不完整时，不得声称最终可发布单元已生成
8. `inspect` 命令必须能明确告诉用户当前缺哪一类证据
9. 旧的“只靠文件存在就放行”的行为必须被移除

---

## 风险与注意事项

### 1. provenance 不是神谕

本轮 provenance 的目标是“让正式执行有明确证据和结构化留痕”，不是从运行时底层绝对证明 skill 内部发生了什么。

但在当前项目层面，它已经明显强于“只要文件在就算执行过”。

### 2. `.cmd` 与 `.ps1` 双入口一致性

已有脚本在参数转发和脚本作用域变量上存在历史坏味道，后续改造时必须同步修正。

### 3. 目录迁移不能破坏现有日报链路

`reports\output\` 和 `reports\health\` 已固定，不应挪动。

### 4. 最终单元与中间工作稿要严格分离

`articles/` 是工作副本。

`publish-units/` 才是交付单元。

不要再把这两层混用。

---

## 一句话结论

这次改造的核心，不是再补一层说明，而是把 `AI杨侦探` 工作流升级成：

一条必须经过人工关口、必须留下正式 skill 执行证据、必须在文章级目录交付最终成果的半自动严格流程。
