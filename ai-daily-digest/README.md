# AI 日报 Skill

这是一份可独立使用的 AI 日报 Skill，包含从原有日报引擎中抽取出来的**信息源、新闻采集、AI 评分与摘要、报告生成和健康日志分析**。它不包含公众号文章写作、选题审批、插图、封面或发布流程。

## 信息源

当前引擎内置 **151 个 RSS 源**：其中 92 个参考 Hacker News Popularity Contest 2025 / Andrej Karpathy 推荐，另有 59 个补充源。默认还会采集 Hugging Face Papers；WaytoAGI 博客为可选源，默认关闭。

完整的 RSS 地址清单独立维护在 [`scripts/source-catalog.ts`](scripts/source-catalog.ts)。源站可用性会变化；每次运行会在健康日志中记录采集结果。

## 目录

```text
ai-daily-digest/
├── SKILL.md                         # Skill 的使用与执行规则
├── README.md                        # 本说明
├── .env.example                     # 模型配置示例，不含密钥
└── scripts/
    ├── digest.ts                    # 信息采集、评分、摘要和日报生成
    ├── source-catalog.ts            # RSS 信息源清单
    ├── lib/ai-client.ts             # Gemini、OpenAI 兼容接口与 Codex CLI 客户端
    ├── analyze-ai-digest-health.ps1 # 汇总近期采集健康日志
    └── analyze-ai-digest-health.cmd # Windows 启动入口
```

## 运行环境

- Windows PowerShell 或 PowerShell 7。
- Node.js / npm（用于 `npx -y bun` 启动 Bun）。
- 可用的模型调用方式：Gemini API、OpenAI 兼容 API，或已登录的 Codex CLI。
- 可访问 RSS 源和所选模型服务的网络连接。

## 配置模型

在此目录复制 `.env.example` 为 `.env`，按所用服务填写配置。至少配置一种认证方式：`GEMINI_API_KEY`、`OPENAI_API_KEY`，或设置 `AI_PROVIDER=codex-cli` 并确保本机 Codex CLI 已登录。

密钥仅保存在本机 `.env` 或进程环境变量中；`.env` 已列入 Git 忽略规则。

## 生成日报

从此目录运行：

```powershell
# 默认生成最近 48 小时的中文 Top 15 日报
npx -y bun scripts/digest.ts

# 生成最近 24 小时日报
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh

# 按上海时区显示报告日期和默认文件名
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --timezone Asia/Shanghai

# 可选：额外抓取 5 篇 WaytoAGI 博客
npx -y bun scripts/digest.ts --hours 24 --top-n 15 --lang zh --waytoagi-limit 5
```

默认产物位于 `reports/output/`，对应的采集健康日志位于 `reports/health/`。也可以通过 `--output` 和 `--health-log` 指定文件路径。生成后可汇总最近 7 次运行的源站健康情况：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/analyze-ai-digest-health.ps1 -Last 7
```

日报按 RSS 标题和简介生成导读，不抓取文章全文；报告会明确标注这一点。引擎会先按规范化链接和同日标题合并重复条目，要求模型为每篇候选内容返回完整评分；评分缺项会重试，仍不完整则停止生成。Hugging Face Papers 页面日期无法识别时会记为采集错误，不会将未标日期的论文当作最新内容。

`--timezone` 使用 IANA 时区名，默认使用运行机器的系统时区。时间窗口仍按最近 N 小时计算；时区只影响报告日期、生成时间和默认文件名。

## 能力边界

这是一个带固定来源清单的采集与内容整理工具，不保证互联网上所有 AI 新闻都被覆盖。RSS 站点可能失效或延迟更新；评分与导读基于 RSS 摘要信息，重要数据和结论仍应结合原文核验。它不会自动定时运行，也不会自动写成长篇文章或发布到任何平台。

Skill 的调用规则见 [`SKILL.md`](SKILL.md)。
