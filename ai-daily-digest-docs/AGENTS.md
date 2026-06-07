# AGENTS.md

本文件定义 `E:\WorkCodex\ai-daily-digest` 的项目级工作约束。它只描述本项目已验证的事实、目录、流程、脚本入口和完成标准，不重复用户级全局偏好，也不替代工作台级方法论。

## 项目定位

- 本项目的主身份是 `AI杨侦探工作流` 的本地执行仓库。
- 底层兼容身份仍然是 `ai-daily-digest`，也就是从信息源生成 AI 日报的脚本引擎。
- 当前仓库支持两类工作：
  - 生成 `24h / 48h / 72h / 7d` 的 AI 日报
  - 围绕已选题材继续完成公众号稿、插图规划、插图生成、素材归档、图片回填和发布包装
- 正式长文写作阶段依赖仓库外 skill，仓库内不再保留旧转稿器入口。

## 语言与环境

- 默认使用中文输出，包括说明、结论、提交说明和必要注释。
- 当前主要运行环境是 Windows + PowerShell。
- 优先保持 `.cmd` 和 PowerShell 工作流可直接使用。
- 涉及中文 Markdown、JSON 和路径处理时，默认按 UTF-8 安全读写处理。

## 目录事实

- 仓库根目录：`E:\WorkCodex\ai-daily-digest`
- 主要脚本目录：`scripts\`
- 设计与计划文档目录：`docs\`
- 日报输出目录：`reports\output\`
- 健康日志目录：`reports\health\`
- 公众号稿目录：`reports\gzhrb\`
- 候选题目录：`reports\gzhrb\topics\`
- 初稿目录：`reports\gzhrb\drafts\`
- 工作单目录：`reports\gzhrb\workitems\`
- 人工确认目录：`reports\gzhrb\approvals\`
- 执行留痕目录：`reports\gzhrb\provenance\`
- 优化稿工作目录：`reports\gzhrb\articles\`
- 插图目录：`reports\gzhrb\illustrations\`
- 最终发布单元目录：`reports\gzhrb\publish-units\`
- 项目本地 Codex 目录：`.codex\`

## 工作流边界

- 日报生成是仓库的基础能力，也是默认起点。
- AI杨侦探正式内容链路应按下面顺序理解：
  1. 生成 `48 小时日报`
  2. 提取候选题材
  3. 人工确认当天题材
  4. `khazix-writer` 生成长文初稿
  5. `wechat-article-writer` 做发文态优化，并默认产出标题备选
  6. `baoyu-article-illustrator` 做插图规划
  7. `baoyu-article-illustrator` 做插图生成
  8. 把插图归档到文章级目录
  9. 把图片路径回填到 Markdown
  10. 补齐引导语、标签和发布包装
  11. 人工终审
- `wechat-article-writer` 默认按 `AI杨侦探` 账号发文态执行：
  - 开头先明确点出“这条具体新闻是什么”，优先交代来源、核心事件和关键数字
  - 结尾默认追加固定尾注，除非用户当次明确要求不加：
    `---`、空行、`<br/>`、空行、`如果你觉得这篇内容有价值，欢迎点个赞、点个在看，也欢迎转发给更多朋友。`、空行、`我是 \`AI杨侦探\`，持续记录 AI、技术、产品和产业变化里那些真正值得看、值得想的事。`、空行、`谢谢你读到这里，我们下次见。`
- 人工选题关口必须保留。不要把日报候选题自动当成最终题材。
- 正式写作阶段必须区分“仓库脚本能力”和“外部 skill 能力”，不要混称。

## 外部依赖与硬约束

- 正式双 skill 写作阶段依赖外部 skill：
  - `khazix-writer`
  - `wechat-article-writer`
  - `baoyu-article-illustrator`
- 在当前 Codex 窗口进入正式写作阶段前，先运行 `scripts\check-codex-required-skills.cmd`。
- 如果当前窗口缺少 `khazix-writer` 或 `wechat-article-writer`，不得声称已完成正式双 skill 写作。
- “正式双 skill 执行”不是只看文件是否存在，而是必须同时具备：真实产物文件、对应 `provenance` 执行证据、对应 `approval` 人工确认。
- 如果优化稿文件未真实落盘到 `reports\gzhrb\articles\<article-id>\article.md`，或缺少 `wechat` provenance / approval，不能继续声称插图链路已进入可执行状态。
- 插图链路对外统一归属 `baoyu-article-illustrator`，不要对外拆成其它独立 skill 或工具名。
- `wechat` 审批通过后，插图规划、插图生成、图片回填和发布包装默认连续执行，不再额外设置插图人工确认关口。
- 进入写作后半段前，优先通过 `scripts\gzhrb-writing-state.cmd` 或 `scripts\inspect-gzhrb-writing-state.cmd` 检查当前状态；是否放行以证据校验结果为准，不只看 workitem 里的阶段字符串。

## 入口脚本

优先使用现有脚本，不要在项目里重复发明平行入口。

- 只生成日报：`scripts\ai-daily-digest-launcher.cmd`
- 直接跑日报脚本：`scripts\digest.ts`
- 日报 + 候选题 + 写作工作单：`scripts\run-digest-and-gzhrb.cmd`
- 预写作入口：`scripts\run-digest-gzhrb-publish-pipeline.cmd`
- 写作后续入口：`scripts\run-gzhrb-postwriting-pipeline.cmd`
- 插图规划：`scripts\plan-gzhrb-illustrations.cmd`
- 插图生成：`scripts\generate-gzhrb-illustrations.cmd`
- 插图归档：`scripts\organize-gzhrb-illustrations.cmd`
- 文章定稿：`scripts\finalize-gzhrb-article.cmd`
- 发布包装：`scripts\package-gzhrb-article.cmd`

## 路由规则

- 用户只说“跑日报”或“生成日报”时，优先走日报链路，不要默认进入公众号稿链路。
- 用户说“继续今天这篇”“继续走完整条链路”时，先识别当前真实阶段，再决定从哪一步续跑。
- 用户要求正式公众号长文时，优先走“工作单 + 外部双 skill”链路，不要虚构仓库内旧转稿器能力。
- 插图规划和插图生成在工作流层面统一归属 `baoyu-article-illustrator`，不要对外把它描述成其它独立产品链路。

## 输出与验收

只有看到真实产物，才能宣称某一阶段完成。

- 日报阶段：`reports\output\ai-daily-digest-*.md` 已生成或更新
- 健康日志阶段：`reports\health\run-*.json` 已生成或更新
- 工作单阶段：`reports\gzhrb\workitems\*.json` 已生成
- 选题确认阶段：`reports\gzhrb\approvals\<article-id>\topic-selected.json` 已生成
- 初稿阶段：`reports\gzhrb\drafts\*-khazix.md` 已存在且不再是占位稿
- 初稿正式执行阶段：`reports\gzhrb\provenance\<article-id>\khazix-execution.json` 已生成
- 初稿人工确认阶段：`reports\gzhrb\approvals\<article-id>\khazix-approved.json` 已生成
- 正式文章阶段：`reports\gzhrb\articles\<article-id>\article.md` 已生成或更新
- 优化稿正式执行阶段：`reports\gzhrb\provenance\<article-id>\wechat-execution.json` 已生成
- 优化稿人工确认阶段：`reports\gzhrb\approvals\<article-id>\wechat-approved.json` 已生成
- 插图规划阶段：文章级目录下存在 `placement.json`、`batch.json`、`outline.md` 和 `prompts\`
- 插图生成阶段：文章级目录下存在预期图片文件
- 插图正式执行阶段：`reports\gzhrb\provenance\<article-id>\illustration-execution.json` 已生成
- 归档阶段：素材已经落入 `reports\gzhrb\illustrations\<article-id>\`
- 发布单元阶段：`reports\gzhrb\publish-units\<article-id>\` 内已存在 `article.md`、`titles.txt`、`intro-lines.txt`、`topic-tags.txt`、`package.json`、`review-checklist.md` 和 `illustrations\`

## 失败处理

- 不要用“应该是”“大概率”替代真实检查结果。
- 任一阶段失败时，明确指出失败阶段、缺失前置条件、实际缺失文件或不匹配项。
- 常见失败包括：
  - 缺少 API Key 或模型配置不兼容
  - 缺少 `placement.json`
  - 文章标题与规划文件不一致
  - 缺少图片文件
  - 正式写作 skill 未注入当前窗口
  - 工作单已生成，但优化稿尚未落盘

## 改动原则

- 修改流程时，优先改真实脚本、真实文档和真实校验逻辑，不只改口头说明。
- 保持现有目录结构和输出约定稳定，避免无验证地改路径。
- 不在已有坏味道代码上继续叠复杂度；发现旧链路与正式链路混淆时，应直接拆清边界。
- 涉及项目说明时，优先更新 `README.md`、`日常操作说明.md` 或相关 `docs\`，避免让 `AGENTS.md` 承担用户文档职责。

## 完成标准

- 请求已映射到正确阶段和正确入口脚本。
- 涉及正式写作的请求已校验当前窗口 skill 条件。
- 所有完成声明都有真实输出文件支撑。
- 无法完成时，已明确指出卡点、影响范围和下一步。
