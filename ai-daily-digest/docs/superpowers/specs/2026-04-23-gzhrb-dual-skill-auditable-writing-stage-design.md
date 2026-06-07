# GZHRB Dual-Skill Auditable Writing Stage Design

## Background

当前 `AI杨侦探` 工作流已经把正式写作拆成两个概念阶段：

1. `khazix-writer` 生成初稿
2. `wechat-article-writer` 生成正式优化稿

但仓库现状仍然存在一个关键缺口：

- 工作单只初始化了 `awaiting_khazix_writer`
- 后半程入口只检查文章路径是否存在
- 缺少对“初稿是否真实完成”“优化稿是否真实落盘”的统一判断
- 文档虽然强调正式双 skill 写作边界，但脚本没有做强阻断

结果是：

- 可以把“按 skill 规范手工写”的内容和“正式双 skill 留痕执行”的内容混在一起
- 可以在没有真实优化稿的情况下继续进入后半程
- 工作单不能清楚表达当前卡在哪个正式阶段

本设计的目标不是重做整条发布流水线，而是在现有结构上把正式写作阶段做成一个最小闭环：

- 可审计
- 可阻断
- 可续跑

## Goal

为 `GZHRB` 正式写作阶段引入最小可审计闭环，使仓库能够明确区分：

1. 初稿等待阶段
2. 优化稿等待阶段
3. 后半程可继续阶段

并在缺少真实优化稿时，阻止后半程脚本继续执行。

## Non-Goals

本次不做以下事情：

- 不引入新的外部 agent 调用框架
- 不把 `khazix-writer` / `wechat-article-writer` 改造成黑盒服务
- 不改造插图后半程主体逻辑
- 不增加数据库或复杂状态存储
- 不要求对历史文章批量迁移

## User-Facing Problem

从用户视角，目前最大的困惑有两类：

1. “按相关 skill 的规范写” 和 “正式双 skill 留痕执行” 容易混淆
2. 流程已经跑到哪一步，仓库层面没有可靠证据

这直接影响：

- 流程可信度
- 复盘效率
- 自动化阻断能力

## Design Principles

### 1. Use the existing workitem as the audit anchor

不新建额外状态中心，继续使用：

- `reports/gzhrb/workitems/<article-id>.json`
- `reports/gzhrb/workitems/<article-id>.md`

作为正式写作阶段的唯一审计锚点。

### 2. Separate state from evidence, but require both

阶段状态不能单独成立，必须和文件证据同时成立。

也就是说：

- 只有 `state` 正确，不够
- 只有文件存在，也不够
- 必须 `state + 文件真实性` 一起通过

### 3. Keep the closure minimal

本次只实现最小三阶段闭环：

- `awaiting_khazix_writer`
- `awaiting_wechat_writer`
- `ready_for_postwriting`

不扩展更多中间状态，避免复杂度膨胀。

### 4. Centralize validation

不要把阶段判断散落在多个脚本里。

应新增一个轻量统一校验模块，由：

- 正式写作后半程入口
- 未来可能的状态推进脚本

共同复用。

## Proposed State Model

### Workitem fields

现有 workitem JSON 保留以下核心结构：

- `workflow`
- `article_id`
- `topic`
- `paths`
- `next_steps`

新增或调整：

```json
{
  "stage": "awaiting_khazix_writer",
  "writing_state": {
    "khazix": {
      "status": "pending"
    },
    "wechat": {
      "status": "pending"
    }
  }
}
```

### Stage semantics

#### `awaiting_khazix_writer`

含义：

- 工作单已创建
- 初稿占位文件已准备
- 还没有真实 `khazix` 初稿

允许：

- 写入正式初稿
- 继续补素材

不允许：

- 进入后半程

#### `awaiting_wechat_writer`

含义：

- `khazix` 初稿已经真实完成
- 正式优化稿尚未真实落盘

允许：

- 用 `wechat-article-writer` 继续生成优化稿

不允许：

- 进入后半程

#### `ready_for_postwriting`

含义：

- 正式优化稿已经真实存在
- 可以继续执行：
  - 插图规划
  - 插图生成
  - 归档
  - 回填
  - 发布包装

## Evidence Rules

### Khazix draft evidence

`khazix` 初稿被视为“真实完成”，至少满足：

1. 文件存在
2. 文件内容非空
3. 文件内容不再是默认占位模板

最低实现方案：

- 通过占位文件中的固定文案片段识别“未完成状态”

例如占位文案包含：

- `khazix-writer 初稿占位文件`

若仍包含该标记，则视为未完成。

### WeChat article evidence

正式优化稿被视为“真实完成”，至少满足：

1. 文件存在
2. 文件内容非空
3. 文件内容不是草稿占位

不要求此阶段必须已经有：

- 标题备选
- 引导语备选
- 话题标签
- 插图

因为这些属于后半程与包装阶段。

## Validation API

新增统一校验脚本：

- `scripts/validate-gzhrb-writing-state.ps1`

职责：

1. 根据文章路径推导 `article_id`
2. 查找对应 workitem JSON
3. 校验 workitem 的 `stage`
4. 校验 `khazix` 初稿和正式优化稿的文件真实性
5. 返回统一结果对象或在 CLI 模式下用退出码表达结果

### Expected validation outcomes

#### Case 1: No workitem found

报错：

- 无法证明当前文章属于正式双 skill 工作流

#### Case 2: Khazix draft still placeholder

结论：

- 仍处于 `awaiting_khazix_writer`

#### Case 3: Khazix finished, wechat missing

结论：

- 应为 `awaiting_wechat_writer`

#### Case 4: Wechat article exists and valid

结论：

- 可进入 `ready_for_postwriting`

## Script Changes

### `prepare-gzhrb-writing-workspace.ps1`

需要改动：

1. 初始化更明确的 `writing_state`
2. 在 Markdown 工作单中写明三个阶段
3. 保持当前占位文件策略不变

### `run-gzhrb-postwriting-pipeline.ps1`

需要改动：

1. 在执行插图规划前调用统一校验脚本
2. 若不是 `ready_for_postwriting`，直接阻断
3. 错误信息中明确指出：
   - 当前阶段
   - 缺少哪类文件证据
   - 下一步应做什么

### Optional future script

本次不强制新增“状态推进脚本”，但结构上为未来预留：

- `mark-gzhrb-writing-stage.ps1`

未来可用来显式推进：

- `awaiting_khazix_writer -> awaiting_wechat_writer`
- `awaiting_wechat_writer -> ready_for_postwriting`

## Documentation Changes

### README

需要新增或改写的重点：

1. 正式双 skill 写作的定义
2. “按 skill 规范写”和“正式双 skill 留痕执行”的区别
3. 后半程入口会校验正式优化稿，不满足会阻断

### 日常操作说明

需要改写的重点：

1. 正式写作阶段的三个状态
2. 哪一步可以继续，哪一步必须停
3. 为什么不能在没有正式优化稿时进入后半程

## Testing Strategy

### Existing tests to extend

- `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`

应补充：

1. 初始化时 `writing_state` 是否正确
2. Markdown 工作单是否写明阶段语义

### New tests

新增：

- `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

覆盖场景：

1. workitem 缺失时报错
2. khazix 初稿仍为占位时报错
3. khazix 已完成但优化稿缺失时报错
4. 正式优化稿存在时允许进入后半程

## Acceptance Criteria

本次设计被视为完成，必须同时满足：

1. 工作单能清楚表达三个正式写作阶段
2. 没有真实优化稿时，后半程入口会被硬阻断
3. 仓库文档明确区分“按 skill 规范写”和“正式双 skill 留痕执行”
4. 测试覆盖状态初始化和后半程阻断
5. 当前实现不要求引入额外复杂状态存储或外部服务

## Recommended Implementation Order

1. 先补统一校验脚本
2. 再改工作单初始化结构
3. 再改后半程入口阻断
4. 最后补测试和文档

这样可以保证：

- 逻辑边界先明确
- 入口阻断最早可验证
- 文档和测试跟随真实实现更新
