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

- 调研 AI 产品，按需输出 N 章结构化报告（产品定位 / 核心功能 / 定价 / 竞品对比 / 技术架构 / 安全 / 生态 / 评价等，按产品复杂度可少可多）
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

### `maintain-bookmark-tables`

书签汇总表维护 skill。维护 `XX书签汇总.xlsx` 系列表格：补四列（类别/网站类型/功能定位/备注）、类别优先排序、五指标验证、去重清理、跨表一致性检查；另提供 URL 推断 / 浏览器书签导入 / 全库统计 / URL 健康检查 四个只读辅助脚本。

适用场景：

- 新增 / 编辑书签行，补齐 9 列规范
- 优化现有表（补四列 + 类别排序 + 重编号）
- 验证表格是否通过五指标（空值 / 笼统类型 / 旧式引用 / 断档 / 悬空，全 0 才算通过）
- 去重清理（真重复可删、同源子页保留）与跨表一致性检查
- URL → 网站类型/类别 自动推断（内置规则 + 从库学习）
- 浏览器导出的 bookmarks.html 导入为待入库清单（可附推断建议）
- 全库统计报告（规模 / 重复 / 疑似失效 / 低频词汇）
- URL 健康检查（HEAD/GET 并发检测死链与失效）

目录：

- [maintain-bookmark-tables](./maintain-bookmark-tables/)

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
├─ product-research/
└─ maintain-bookmark-tables/
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
