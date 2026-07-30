# YZ Skills

我自己常用的一些 AI Skills，按可直接安装、可独立维护的结构整理在这里。

这个仓库只收 `skill` 相关内容，不收完整应用项目、不收运行产物、不收本机调试缓存。

## Skills

### `szxs-gzh`

四知先生公众号日更工作流。

适用场景：

- 生成四知先生公众号每日黄历文章初稿
- 人工修正生肖顺序、电影位、宜忌、排版后输出 `final_markdown`
- 基于最终稿生成双人播客逐字稿

目录：

- [szxs-gzh](./szxs-gzh/)
- [szxs-gzh-docs](./szxs-gzh-docs/)

### `zhen-fmt`

固定角色、固定气质的一致性插画生成 skill。

适用场景：

- 基于固定人物参考图生成新场景插画
- 生成个人日系氛围插画风提示词
- 调用 Gemini 跑图并保存本地输出

目录：

- [zhen-fmt](./zhen-fmt/)

### `ai-daily-digest`

AI 日报 / 公众号稿 / 插图规划 / 定稿发布链路 skill。

适用场景：

- 跑日报
- 把日报转成公众号稿
- 规划并生成插图
- 整理插图归档
- 输出可发布的最终文章

目录：

- [ai-daily-digest](./ai-daily-digest/)
- [ai-daily-digest-docs](./ai-daily-digest-docs/)

### `product-research`

产品调研与文档写作方法论。围绕"多源交叉、结构化笔记、证据可追溯"三个原则，把 AI 产品调研做成可复用的工程化流程。

适用场景：

- 调研 AI 产品，生成 11 章标准报告（产品定位 / 核心功能 / 定价 / 竞品对比 / 技术架构 / 安全 / 生态 / 评价等）
- 写产品评测文章、开源项目 README、Skill/MCP 文档
- 做竞品横评、行业赛道分析、轻量产品速览
- 深度调研时使用结构化笔记、4 维来源评分、冲突检测、引用校验自动化脚本

核心机制：

- 7 类标准输出模板（调研报告 / 评测 / 开源文档 / Skill-MCP / 竞品对比 / 行业分析 / 产品简报）
- 8 类来源采集（官方 / 评测 / 竞品 / 行业 / 技术架构 / 用户社区 / 媒体深度 / 学术标准），默认 ≥ 20 条
- 4 维来源评分（权威性 × 时效性 × 相关性 × 独立性）
- 5 道质量门禁（路由 / 过程 / 引用 / 输出 / 效率） × 20 分，80 分达标
- 3 个自动化脚本：`quality_gate.py` / `verify_citations.py` / `conflict_detector.py`
- eval 套件：3 个 fixture + rubric + baseline 跑分

目录：

- [product-research](./product-research/)

## 当前仓库结构

```text
yz-skills/
├─ README.md
├─ LICENSE
├─ .gitignore
├─ szxs-gzh/
├─ szxs-gzh-docs/
├─ zhen-fmt/
├─ ai-daily-digest/
├─ ai-daily-digest-docs/
└─ product-research/
```

## 目录约定

### skill 目录

一个 skill 一个目录，通常包含：

- `SKILL.md`
- `references/`
- `config/`
- `prompt-modules/`
- `scripts/`
- `tests/`
- `examples/`
- `templates/`

不是每个 skill 都必须包含以上全部目录，以实际需要为准。

### `*-docs` 目录

如果某个 skill 还有项目级说明、日常操作说明、AGENTS 规则文件，就单独放在 `*-docs/` 目录中，避免和 skill 本体混在一起。

## 安装方式

在支持 Skill 的 Agent 里直接说：

```text
帮我安装这个 skill：
https://github.com/<your-name>/yz-skills/tree/main/<skill-name>
```

例如：

```text
帮我安装这个 skill：
https://github.com/<your-name>/yz-skills/tree/main/szxs-gzh
```

## 仓库原则

- 一个 skill 一个目录
- 每个 skill 目录只放和它自己有关的内容
- 只有在本地真实用过、可复用的 skill 才收进来
- 不收 `.env`、运行产物、调试截图、缓存目录
- 不把完整应用项目混进 skill 仓库
