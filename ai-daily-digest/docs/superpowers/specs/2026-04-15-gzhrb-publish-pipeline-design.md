# GZHRB Publish Pipeline Design

日期：2026-04-15  
项目：`E:\WorkCodex\ai-daily-digest`  
主题：一键跑“日报 + 公众号稿 + 插图计划 + 插图生成接入点 + 插图归档整理 + 最终 Markdown 发文稿”

## 1. 目标

为当前 AI 日报项目补一条可持续使用的公众号发文流水线，默认产出一个**可直接复制到公众号后台**的最终 Markdown 文件。

这条流水线的目标不是做 HTML 富文本编辑器，也不是直接操控微信公众平台后台，而是把现有分散步骤收敛成一个稳定的、可重复执行的本地流程。

最终目标链路：

1. 生成日报
2. 生成公众号稿
3. 生成插图计划
4. 生成文章插图
5. 归档插图资产
6. 按计划回填正文
7. 输出最终 `.md` 发文稿

## 2. 本期范围

本期只做最小可用版，控制复杂度，优先稳定。

包含：

- 日报生成复用现有入口
- 公众号稿生成复用现有入口
- 新增“插图计划”层
- 新增“最终正文回填”层
- 新增一键总控入口
- 默认覆盖原 `gzhrb-YYYYMMDD-HHmm.md`

不包含：

- 公众号 HTML / 富文本所见即所得预览
- 直接发布到微信公众平台
- 自动识别文章任意段落并智能插图
- 多封面、多版式、多主题样式选择器
- 超过 5 张正文配图的复杂排版

## 3. 用户故事

### 3.1 日常使用场景

用户每天执行一条命令，希望得到：

- 一份日报 Markdown
- 一篇公众号文章初稿
- 一组和这篇文章绑定的插图计划与图片资产
- 一篇已经插好图、可直接复制到公众号后台的最终 Markdown

### 3.2 用户期望

用户不想：

- 每次手动找图片
- 每次手动调图片路径
- 每次记住图片该插在哪一段
- 每次清理 `illustrations/` 根目录的历史遗留文件

用户希望：

- 每篇文章的插图资产天然归档到自己的日期目录
- 插图位置可预期
- 失败时直接报错，而不是默默插错

## 4. 核心设计选择

### 4.1 选用“插图计划 -> 回填正文”方案

本方案不采用以下两种方式：

- 不采用“正文预埋锚点”作为主方案
- 不采用“仅根据标题或段落临时猜位置”作为主方案

本方案采用：

- 先为每篇文章生成一份结构化插图计划
- 再根据这份计划执行图片生成与正文回填

原因：

- 比正文硬编码锚点更贴近现有生产方式
- 比运行时猜标题更稳定
- 图片位置关系被显式记录，可调试、可重跑、可归档

### 4.2 最终稿默认覆盖原文

本期不默认生成 `-final.md` 副本。

默认行为：

- 公众号稿生成后先得到初稿 `gzhrb-YYYYMMDD-HHmm.md`
- 流水线最终阶段直接把图片插回该文件
- 最终这个文件本身就是发文稿

理由：

- 降低文件数和认知负担
- 符合用户“最终只有一个可发版本”的使用习惯

## 5. 目录与文件设计

### 5.1 文章主文件

```text
reports/gzhrb/gzhrb-YYYYMMDD-HHmm.md
```

### 5.2 插图资产目录

每篇文章一个目录：

```text
reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm/
```

目录内容：

```text
reports/gzhrb/illustrations/
└─ gzhrb-20260415-1639/
   ├─ outline.md
   ├─ batch.json
   ├─ placement.json
   ├─ 01-scene-quantum-os-entry.png
   ├─ 02-framework-quantum-ai-layer.png
   └─ prompts/
      ├─ 01-scene-quantum-os-entry.md
      └─ 02-framework-quantum-ai-layer.md
```

### 5.3 核心新增文件

新增文件的职责如下：

- `outline.md`
  - 给人看
  - 说明每张图的目的、位置、文件名

- `batch.json`
  - 给出图脚本用
  - 记录图片生成任务

- `placement.json`
  - 给最终排版脚本用
  - 只负责“正文位置 -> 图片文件”的映射

## 6. placement.json 设计

这是本方案的核心。

建议结构：

```json
[
  {
    "slot": 1,
    "after_heading": "## 先把这件事说简单一点",
    "image": "01-scene-quantum-os-entry.png",
    "alt": "AI 成为量子计算机操作系统的视觉化主命题"
  },
  {
    "slot": 2,
    "after_heading": "## 我更在意的，不是量子这两个字，而是英伟达又在复制自己的老剧本",
    "image": "02-framework-quantum-ai-layer.png",
    "alt": "AI 作为量子计算中间层连接模拟优化纠错与算法设计"
  }
]
```

字段说明：

- `slot`
  - 配图顺序，便于人读

- `after_heading`
  - 明确插在某个标题后面
  - 本期只支持二级标题或三级标题

- `image`
  - 归档目录中的图片文件名

- `alt`
  - 最终 Markdown 图片描述

后续可扩展但本期不做的字段：

- `caption`
- `before_heading`
- `after_paragraph_contains`
- `required`

## 7. 模块拆分

### 7.1 现有模块复用

复用现有：

- `scripts/digest.ts`
- `scripts/generate-gzhrb.ps1`
- `scripts/generate-gzhrb.ts`
- `scripts/organize-gzhrb-illustrations.ps1`

### 7.2 新增模块

建议新增 3 个模块：

#### A. `plan-gzhrb-illustrations`

职责：

- 输入公众号文章
- 生成该文对应的 `outline.md`
- 生成 `placement.json`
- 生成 `prompts/`
- 生成 `batch.json`

输入：

- `gzhrb-YYYYMMDD-HHmm.md`

输出：

- `reports/gzhrb/illustrations/gzhrb-YYYYMMDD-HHmm/` 下全部插图计划文件

#### B. `generate-gzhrb-illustrations`

职责：

- 读取该文章目录下的 `batch.json`
- 调用当前图像生成工具
- 输出图片到同目录

说明：

- 这里需要接入现有图像生成执行链路
- 本仓库不一定完全重写出图逻辑，可先做“命令组装与调用层”

#### C. `finalize-gzhrb-article`

职责：

- 读取文章正文
- 读取 `placement.json`
- 检查所有目标标题是否存在
- 检查所有目标图片是否存在
- 按规则把图片 Markdown 插入正文
- 覆盖输出原 `gzhrb-*.md`

## 8. 一键总控入口

建议新增：

```text
scripts/run-digest-gzhrb-publish-pipeline.cmd
```

它内部按顺序调用：

1. `ai-daily-digest-launcher.ps1 -GenerateGzhrb`
2. `plan-gzhrb-illustrations.ps1`
3. `generate-gzhrb-illustrations.ps1`
4. `organize-gzhrb-illustrations.ps1`
5. `finalize-gzhrb-article.ps1`

### 8.1 执行顺序说明

注意：

- “归档整理”必须发生在最终正文回填前，确保图片路径已稳定
- 最终排版只读取归档后的路径，不读取根目录临时路径

## 9. 最终 Markdown 回填规则

### 9.1 本期插入规则

本期只支持一种规则：

- 把图片插到指定标题所在段落块之后

具体行为：

1. 找到 `after_heading`
2. 找到该标题所在行
3. 找到这个标题段落块结束处
4. 在此处插入：

```md
![alt](illustrations/gzhrb-YYYYMMDD-HHmm/01-xxx.png)
```

### 9.2 稳定性约束

脚本必须遵守：

- 找不到目标标题时，直接报错
- 找不到目标图片时，直接报错
- 不允许自动猜最近标题
- 不允许部分成功后继续静默覆盖全文

## 10. 失败策略

严格失败，避免错误发文稿。

### 10.1 各步骤失败时的行为

- 日报生成失败：全流程终止
- 公众号稿生成失败：全流程终止
- 插图计划生成失败：全流程终止
- 图片生成部分失败：全流程终止，不回填正文
- 归档失败：全流程终止
- `placement.json` 校验失败：全流程终止
- 最终 Markdown 回填失败：保留原稿，不写半成品

### 10.2 错误信息要求

错误输出必须清楚指出：

- 哪篇文章
- 哪一步失败
- 哪张图或哪个标题失败
- 下一步建议人工检查什么

## 11. 幂等性要求

重复执行必须安全。

### 11.1 已有图片

如果图片已存在：

- 不重复生成
- 或通过显式参数决定是否覆盖

本期建议默认：

- 已存在则跳过生成

### 11.2 已完成回填

如果文章中已经存在对应图片路径：

- 最终排版脚本不能重复插入第二次
- 需要先检测目标路径是否已在目标位置存在

### 11.3 已归档目录

如果文章目录已存在：

- 新资产补充写入
- 不清空目录
- 不删除已有图片，除非显式要求覆盖

## 12. 命名与路径策略

### 12.1 文章 ID

统一使用文章文件名去扩展名后的值：

```text
gzhrb-20260415-1639
```

### 12.2 图片文件名

保留现有：

- `01-scene-quantum-os-entry.png`
- `02-framework-quantum-ai-layer.png`

原因：

- 机器可读
- 与 prompt 文件自然对应
- 目录已承担日期归档职责，文件名本身不需要再塞时间

## 13. CLI 与用户入口建议

建议保留以下入口：

- `scripts\generate-gzhrb.cmd`
- `scripts\organize-gzhrb-illustrations.cmd`
- `scripts\run-digest-and-gzhrb.cmd`

建议新增：

- `scripts\plan-gzhrb-illustrations.cmd`
- `scripts\generate-gzhrb-illustrations.cmd`
- `scripts\finalize-gzhrb-article.cmd`
- `scripts\run-digest-gzhrb-publish-pipeline.cmd`

## 14. 测试策略

### 14.1 单元测试

至少覆盖：

- 从文章路径提取文章 ID
- `placement.json` 解析
- 标题匹配逻辑
- 正文插图插入逻辑
- 已存在图片路径时不重复插入

### 14.2 临时目录集成测试

至少覆盖：

- 一篇模拟文章
- 一套模拟 `placement.json`
- 2 到 3 张模拟图片
- 跑完整个“归档 + 回填”过程
- 验证最终 Markdown 内容正确

### 14.3 真实文件安全测试

对真实文章测试时：

- 先对已整理文章运行
- 验证不重复改动
- 再对新文章运行

## 15. 分阶段实施建议

### 第 1 阶段

先落最小闭环：

- `placement.json`
- `finalize-gzhrb-article`
- 一套测试

先解决“最终稿自动生成”问题。

### 第 2 阶段

再补“插图计划脚本化”：

- 从文章自动生成 `outline.md`
- 自动生成 `placement.json`
- 自动生成 `prompts/`

### 第 3 阶段

最后补“图片生成接入层”：

- 对接现有图像 skill / 命令
- 纳入总控入口

## 16. 推荐实施顺序

推荐按下面顺序开发：

1. `finalize-gzhrb-article.ps1`
2. `placement.json` 约定与生成
3. `plan-gzhrb-illustrations.ps1`
4. `generate-gzhrb-illustrations.ps1`
5. `run-digest-gzhrb-publish-pipeline.cmd`
6. README 和操作说明补充

## 17. 本设计的取舍结论

本设计优先：

- 稳定
- 可归档
- 可重跑
- 报错明确

本设计刻意不优先：

- 最少文件数
- 最智能的自动猜图位
- 一步做到富文本完美排版

对于当前项目阶段，这是正确取舍。因为用户要的是一条每天可跑、出错时能定位、最终能稳定拿去发文的生产线，而不是一套脆弱的“看起来自动化很多”的黑盒流程。
