# GZHRB Writing State Explicit Marking Design

## Background

上一轮最小闭环已经解决了两件事：

1. 正式双 skill 写作被拆成 `awaiting_khazix_writer`、`awaiting_wechat_writer`、`ready_for_postwriting`
2. 后半段入口会基于文件证据做硬阻断

但当前实现仍然主要依赖“推断”：

- 是否完成 `khazix` 初稿，是从初稿文件内容推断
- 是否完成 `wechat` 优化稿，是从正式文章文件推断
- 工作单本身没有显式记录“谁在什么时候把哪一步标记完成”

这意味着最小闭环虽然已经可阻断，但还不够适合复盘和审计。

## Goal

在不改变当前主链路使用方式的前提下，为正式双 skill 写作增加显式留痕能力：

1. 支持由脚本显式回写 `khazix` / `wechat` 已完成状态
2. 为工作单追加 `execution_log`
3. 提供独立检查入口，明确显示：
   - 当前显式状态
   - 当前文件证据状态
   - 是否一致
   - 当前卡点和下一步

## Non-Goals

本次不做以下事情：

- 不把工作单状态改成唯一真相源
- 不把正式写作改造成复杂状态机
- 不自动调用外部 skill
- 不增加数据库、服务端或长期守护进程
- 不追溯迁移所有历史 workitem

## Core Decision

本次采用“显式状态回写 + 文件证据兜底”的双层模型。

结论：

- 显式状态用于审计和复盘
- 文件证据用于最终放行
- 两者不一致时，脚本明确报告偏差，但以后者作为放行依据

这是因为当前项目是“agent + skill + 本地文件”混合链路。若把显式状态做成唯一真相源，人工修复和异常恢复成本会明显上升。

## Proposed Workitem Model

在现有 `workitems/<article-id>.json` 中扩展以下结构：

```json
{
  "stage": "awaiting_khazix_writer",
  "writing_state": {
    "khazix": {
      "status": "pending",
      "completed_at": null,
      "updated_at": null,
      "updated_by": null,
      "source_path": null
    },
    "wechat": {
      "status": "pending",
      "completed_at": null,
      "updated_at": null,
      "updated_by": null,
      "source_path": null
    }
  },
  "execution_log": []
}
```

### Field Semantics

#### `status`

只使用最小集合：

- `pending`
- `completed`

不引入 `failed`、`running`、`skipped` 等额外状态，避免复杂度膨胀。

#### `completed_at`

表示该阶段被显式标记为完成的时间。

#### `updated_at`

表示最近一次状态写入时间。通常和 `completed_at` 相同，但保留字段以便未来扩展。

#### `updated_by`

记录本次回写的主体，最小实现允许用：

- `manual-script`
- `codex`

默认值由脚本参数决定。

#### `source_path`

记录用于显式回写的证据路径：

- `khazix` 阶段写初稿路径
- `wechat` 阶段写正式优化稿路径

#### `execution_log`

按时间顺序追加事件，最小事件结构如下：

```json
{
  "timestamp": "2026-04-23T14:30:00+08:00",
  "action": "mark_khazix_complete",
  "stage_after": "awaiting_wechat_writer",
  "updated_by": "manual-script",
  "source_path": "E:\\WorkCodex\\ai-daily-digest\\reports\\gzhrb\\drafts\\...-khazix.md",
  "note": "Validated non-placeholder khazix draft before marking complete."
}
```

## New Script Entrypoints

新增两个显式回写脚本：

- `scripts/mark-gzhrb-khazix-complete.ps1`
- `scripts/mark-gzhrb-wechat-complete.ps1`

### `mark-gzhrb-khazix-complete.ps1`

职责：

1. 根据 `ArticlePath` 推导 workitem
2. 读取 workitem 中的 `khazix_draft` 路径
3. 校验初稿文件真实存在且不是占位稿
4. 将：
   - `writing_state.khazix.status` 置为 `completed`
   - `stage` 推进到 `awaiting_wechat_writer`
5. 追加一条 `execution_log`

### `mark-gzhrb-wechat-complete.ps1`

职责：

1. 根据 `ArticlePath` 推导 workitem
2. 校验 workitem 中的正式优化稿路径真实存在且非空
3. 将：
   - `writing_state.wechat.status` 置为 `completed`
   - `stage` 推进到 `ready_for_postwriting`
4. 追加一条 `execution_log`

## Validation Changes

现有 `validate-gzhrb-writing-state.ps1` 继续负责统一判断，但返回内容需要增强。

### New Output Shape

除了已有字段外，新增：

- `declared_stage`
- `evidence_stage`
- `state_matches_evidence`
- `writing_state`
- `execution_log_tail`

其中：

- `declared_stage` 来自 workitem `stage`
- `evidence_stage` 来自文件证据计算
- `state_matches_evidence` 表示两者是否一致

### Truth Rule

放行规则仍然是：

- 只有 `evidence_stage == ready_for_postwriting` 才允许进入后半段

不是：

- 只要 `declared_stage == ready_for_postwriting` 就放行

也就是说，状态可以错，日志可以缺，但不能因为这些元数据错误放过一个没有正式优化稿的文章。

## Inspection Script

新增：

- `scripts/inspect-gzhrb-writing-state.ps1`

用途是给人看，不负责修改状态。

输出至少包含：

- article id
- workitem path
- declared stage
- evidence stage
- state matches evidence
- khazix explicit status
- wechat explicit status
- last execution log entries
- readiness
- next step

CLI 默认输出可读文本，必要时支持 JSON。

## Error Handling

### Case 1: 显式状态已完成，但文件证据缺失

例如：

- `khazix.status = completed`
- 但 `khazix_draft` 仍然是占位稿

处理：

- 校验返回 `state_matches_evidence = false`
- 不放行
- 检查脚本明确指出偏差

### Case 2: 文件证据已完成，但显式状态还没写

例如：

- 正式优化稿已经落盘
- 但 `wechat.status` 仍是 `pending`

处理：

- 校验可以认定 `evidence_stage = ready_for_postwriting`
- 后半段仍可放行
- 检查脚本提示“建议补写显式状态”

### Case 3: 重复标记完成

处理原则：

- 允许重复执行标记脚本
- 但仍应追加日志，清楚表明再次标记发生过
- 不回退阶段

## Documentation Changes

需要把以下边界写清楚：

1. 工作单状态是留痕层，不是唯一放行依据
2. 显式回写脚本的作用是补齐审计记录
3. `inspect` 脚本用于判断当前卡点

## Testing Strategy

### Extend Existing Tests

`scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`

新增断言：

- `execution_log` 初始化为空数组
- `writing_state.*` 的扩展字段初始为 `null`

### New Tests

新增：

- `scripts/tests/mark-gzhrb-writing-state.tests.ps1`
- `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`

覆盖场景：

1. `mark khazix complete` 会正确更新 workitem 并追加日志
2. `mark wechat complete` 会正确更新 workitem 并追加日志
3. 无真实文件证据时，显式回写脚本拒绝写入
4. `inspect` 能输出显式状态、证据状态和偏差信息

### Update Validator Tests

现有 `validate-gzhrb-writing-state.tests.ps1` 需要补：

1. 返回 `declared_stage`
2. 返回 `evidence_stage`
3. 当状态与证据不一致时，`state_matches_evidence = false`

## Acceptance Criteria

本次增强完成时，必须同时满足：

1. 工作单支持显式记录 `khazix` / `wechat` 已完成状态
2. 每次显式状态写入都会追加 `execution_log`
3. 提供独立检查入口，能看出“声明状态”和“证据状态”的差异
4. 后半段放行逻辑仍然以文件证据为准
5. 测试覆盖显式回写、日志追加、状态偏差检查和后半段放行规则
