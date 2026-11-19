# AI Daily Digest

`ai-daily-digest` 是 AI 杨侦探内容工作流的日报引擎与脚本集合，发布在个人 Skills 仓库 [`spsz831/yz-skills`](https://github.com/spsz831/yz-skills) 的 `ai-daily-digest/` 目录。

它负责从配置的信息源生成 AI 日报，并提供候选选题、工作单、插图素材归档和发布包装等机械化脚本。公众号文章写作、事实与口吻审校、封面设计和 SVG 长图排版由独立的内容流水线 Skill 协调。

## 能做什么

- 生成 24 小时、48 小时、72 小时或 7 天的 AI 日报。
- 从日报生成候选选题，并准备写作工作区；最终选题由作者确认。
- 检查文章工作流状态、记录审批，并执行插图规划、生成、归档和发布包装脚本。
- 保存文章 Markdown、公众号 SVG 和发布素材的工作约定与参考文档。

日报和脚本不会替作者自动决定选题、代写并发布文章，也不会自动生成最终公众号 SVG。

## 目录结构

```text
ai-daily-digest/
├── SKILL.md                       # Codex / Agent 的使用路由
├── AGENTS.md                      # 项目流程与验收约束
├── scripts/                       # 日报与内容工作流脚本
├── docs/                          # 内容流水线参考文档
└── reports/                       # 本地运行输出，不纳入 Git
```

运行输出默认写入 `reports/`，由 `.gitignore` 排除。日报、文章稿件、审批记录、图片素材、缓存和本地凭证属于运行数据，不属于本仓库的 Skill 发布内容。

## 环境与配置

当前脚本以 Windows 和 PowerShell 为主要运行环境。日报入口通过 `npx -y bun` 执行 TypeScript 脚本，因此需要可用的 Node.js / npm / npx；部分内容脚本还会调用系统 PowerShell。

运行前，在项目根目录准备 `.env`，按需配置模型服务。可参考 `.env.example` 中的变量：

- `AI_PROVIDER`：选择配置的模型调用方式；使用 `codex-cli` 时依赖本机 Codex CLI 登录。
- `GEMINI_API_KEY` 或 `OPENAI_API_KEY`：使用相应 API 时配置。密钥只写入本地 `.env`，不要提交到 Git。
- `GEMINI_MODEL`、`OPENAI_API_BASE`、`OPENAI_MODEL`：按当前模型服务或本地路由器填写。
- `DIGEST_OUTPUT_DIR`：可选，用于覆盖默认报告目录。

模型服务的地址、模型名和认证方式取决于本机配置；不要直接照抄示例中的占位值作为真实凭证。

## 常用命令

在本地项目工作目录的 PowerShell 中运行：

```powershell
# 启动日报交互入口
\.\scripts\ai-daily-digest-launcher.cmd

# 直接生成一份 24 小时日报
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --waytoagi-limit 0 --output .\reports\output\ai-daily-digest-manual.md --health-log .\reports\health\run-manual.json

# 检查写作工作流状态
\.\scripts\gzhrb-writing-state.cmd
```

生成日报后，确认 `reports/output/` 中有 Markdown 文件，并检查 `reports/health/` 中对应的运行日志。后续脚本应根据当前真实文件和工作流状态选择，不要只凭工作单中的阶段文字判断完成。

## 内容工作流边界

正式内容链路保留两个作者关口：确认选题、确认文章定稿。之后可按需规划和生成插图、归档素材、补齐发布包装，并由作者终审。

- `ai-daily-digest`：日报生成、候选选题、工作区准备及机械化脚本。
- `ai-yang-detective-content-pipeline`：长文撰写与优化、事实和口吻检查、封面与公众号 SVG 的整体协调。
- `baoyu-article-illustrator`：内容流水线按需调用的插图规划与生成能力。

Markdown 正文和完整公众号 SVG 是不同的交付物。当前发布包装脚本不会生成 SVG；公众号后台兼容性还需单独预览验证。

## 主要产物目录

| 内容 | 本地目录 |
|---|---|
| 日报与运行健康日志 | `reports/output/`、`reports/health/` |
| 候选选题 | `reports/gzhrb/topics/` |
| 草稿、工作单与审批 | `reports/gzhrb/drafts/`、`workitems/`、`approvals/` |
| 定稿文章 | `reports/gzhrb/articles/<article-id>/` |
| 插图与归档素材 | `reports/gzhrb/illustrations/<article-id>/` |
| 最终发布单元 | `reports/gzhrb/publish-units/<article-id>/` |

具体脚本入口和完成标准见 [`SKILL.md`](SKILL.md) 与 [`AGENTS.md`](AGENTS.md)；封面、插图、开头和 SVG 参考见 `docs/skills/ai-yang-detective-content-pipeline/references/`。

## 安全与维护

- 不要把 `.env`、API 密钥、个人报告、文章草稿或角色素材提交到 Git。
- 修改流程时同步更新实际脚本、校验逻辑和对应文档，不要只改 Skill 说明。
- 完成阶段时，以真实生成的文件和检查结果为准；失败时记录缺少的前置条件与产物。
