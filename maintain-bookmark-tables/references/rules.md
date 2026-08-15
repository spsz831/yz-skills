# 书签汇总表规范

本文件收录"书签汇总表"的完整整理规范。SKILL.md 触发后按需加载本文件。

## 1. 表格结构（9 列固定）

| 列 | 表头 | 说明 |
|---|---|---|
| 1 | 序号 | 排序后重新编号 1..N |
| 2 | 名称 | 站点/项目完整名称，唯一标识 |
| 3 | URL | 书签地址 |
| 4 | 类别 | 业务分类，全表统一词汇 |
| 5 | 网站类型 | `平台·业务` 格式 |
| 6 | 功能定位 | 一句话说明用途（30~60 字） |
| 7 | 是否重复 | `是`/`否` |
| 8 | 备注 | 作者/平台 + 同源引用 + 跨表引用 |
| 9 | 添加日期 | YYYY-MM-DD |

## 2. 网站类型细分到业务

格式固定为 `平台·业务`，平台在上、业务在下。参考值：

```
官网·AI导航 / 官网·工具 / 官网·平台 / 官网·免费邮箱 / 官网·Agent平台
GitHub·开源模型 / GitHub·工具仓库 / GitHub·MCP仓库 / GitHub·Skill仓库
教程·B站视频 / 教程·文档
社区·论坛 / X·推文 / 微信·公众号 / 飞书·云文档 / 微软·Outlook
本地·工具 / 公益·API / 官网·镜像站 / 官网·控制台
```

**禁止使用的笼统值**（验收会报"残留笼统类型"）：

```
Outlook邮箱 / 免费邮箱 / 教育邮箱 / 临时邮箱 / 在线工具 / 学习教程
国内平台 / 国外平台 / GitHub / B站
```

## 3. 备注名称引用（同源标注）

- 同源引用**必须基于名称**：`与同表『完整名称』同源`
- **禁止** `与序号N 同源`——表格排序后序号会失效，引用会错位
- 名称必须与目标行的名称列**精确一致**；截断的名称要补全
- 多行互指：`与同表『A』『B』『C』同源`
- 同名行消歧：用 URL 后缀或功能后缀区分，如 `（官网）`/`（镜像）`/`（首页）`
- 跨表引用：`同源已收录于XX书签汇总.xlsx`（XX 必须是真实存在的表文件）
- **改/截断长名前先 grep 引用它的行**：`owner/repo: 描述` 这类长名要截断时，先全表搜 `与同表『原完整名称』`，把引用和被引用行一起处理。只改引用行而保留长名、或只改被引用行而漏改引用，都会反向制造悬空引用（实战翻车点）
- **GitHub 仓库名约定**：名称与引用统一用 `owner/repo`，去掉 `: 描述` 后缀，如 `putyy/res-downloader`，不写 `putyy/res-downloader: 视频号、小程序...下载`

## 4. 验证七指标（全 0 才算通过）

| 指标 | 判定 |
|---|---|
| 空值 | 类别/网站类型/功能定位/备注 任一为空 |
| 笼统 | 网站类型 ∈ 第 2 节禁用清单 |
| 旧引用 | 备注含 `序号`、`与同表「`（旧角括号）、或『』缺失时含`同源+「` |
| 断档 | 同类行被其他类别插入切断 |
| 悬空 | `与同表『X』` 的 X 在同表名称列**且整个文件**都不存在 |
| 跨sheet | `与同表『X』` 的 X 不在本 sheet、但在**同文件其他 sheet** 存在（多 sheet 文件跨子表引用不能写「同表」） |
| 残行 | 名称列为空但其余列有内容（半截残留，如只有 URL 无名称——Coding 表 replit/bito 垃圾行、飞书表第46行即此类） |

用 `scripts/verify_table.py` 验证（悬空/跨sheet 非 0 时脚本会列出具体行；残行会报数量）。索引表（书签整理最终清单，4 列结构）脚本自动跳过，不走 7 指标。悬空修复：
- 同名行 → 给名称列补区分后缀（URL/功能），让引用精确命中
- 别名引用 → 把备注引用统一成名称列实际值，或反过来说名称列补成引用值
- 跨sheet → 去掉「同表」，改成 `与『X』同源（见AI书签汇总.xlsx某sheet）`

**残行处置**：先确认该 URL 是否已作为完整行收录——是则删（复制残留），否则补齐 9 列。

## 5. 排序规则（类别优先）

1. 用 `CAT_ORDER` 列表固定类别顺序（`scripts/sort_table.py --order`）
2. 类别不在列表中的排最后
3. 同一类别内按网站类型首次出现顺序分组，保持稳定
4. 排序后重新编号 1..N
5. **排序前**先确保备注引用全部改为名称式（不依赖序号）
6. 脚本内置护栏：存在 `与序号N`/`与同表「` 旧引用时直接拒绝排序

## 6. 去重

- "是否重复"列标 `是` 有两种语义，处理方式不同：
  - **真重复**（可删）：备注以 `重复：` 开头，或表内同 URL 的多行
  - **同源子页/关联行**（保留）：备注为 `与同表『X』同源` 的详情页/子页/镜像，如"可可影视详情页"。这类行 URL 不同、功能定位不同，是用户有意保留的
- 默认**不删除**，仅标记；同源子页永远不删
- 清理真重复时用 `scripts/dedup_report.py` 列出，人工确认后加 `--delete`（脚本只删"重复："/同 URL 行，同源子页自动跳过）

## 7. 跨表一致性

用 `scripts/cross_table_check.py` 检查三项：
1. **悬空引用**：`与同表『X』同源` 的 X 是否在同表名称列存在
2. **跨表引用**：`收录于XX.xlsx` 的文件是否真实存在
3. **URL 跨表**：同一 URL 出现在多表时，核对是否应标"是否重复=是"。**已标「是否重复=是」的行归为已处理，不再告警**；只报未标记的组

## 8. 多 sheet 合并文件

- **AI书签汇总.xlsx** 是唯一多 sheet 文件：12 个 AI 子表（AI图片/AI导航/AI工具/AI提示词/AI视频/AI语音/AI资讯/AI音乐/API/SkillMCP/大模型/AIGC学习）合一，每 sheet 一个子类，9 列结构独立，行号独立编号
- 各脚本多 sheet 支持：
  - `verify_table.py`：逐 sheet 验证（输出带 `[sheet名]` 后缀）
  - `sort_table.py --sheet <名>`：指定 sheet 排序（默认只处理 active）
  - `style_table.py`：遍历所有 sheet 统一格式化
  - `infer_from_url.py --dir`：逐 sheet 学习域名→类型/类别/表
  - `export_bookmarks.py`：AI 合并文件按 sheet 展开为 AI 大组下的子文件夹
- 跨表引用统一指向 `AI书签汇总.xlsx`（不再区分具体子表）
- **跨 sheet 引用禁止写「同表」**：子表间的同源引用必须用跨表格式 `与『X』同源（见AI书签汇总.xlsx某sheet）`——`同表『X』` 只允许同 sheet 内使用。verify 会把「X 在本文件其他 sheet 却用了同表」报为 `跨sheet` 指标
- 子表间移动书签用 `scripts/move_entry.py --from AI书签汇总.xlsx --from-sheet 源 --to AI书签汇总.xlsx --to-sheet 目标`（见 §11）

## 9. 表格统一样式（美化）

所有书签汇总表统一美化，用 `scripts/style_table.py` 执行，不手改单格：

```bash
python scripts/style_table.py <xlsx> [<xlsx>...] [--accent EEF4FB]
```

样式规范（全表一致）：

| 区域 | 样式 |
|---|---|
| 表头 | 微软雅黑 11 加粗、白字、深蓝底 `3867A6`、居中、行高 26 |
| 数据行 | 微软雅黑 10.5、细边框、从第一数据行起浅蓝 `EEF4FB`/白 **隔行交替**（斑马纹） |
| 对齐 | 序号/类别/网站类型/是否重复/添加日期 居中；名称/URL/功能定位/备注 左对齐+换行 |
| URL | 蓝字 `2563EB` |
| 边框 | 深灰 `999999` thin 四边（WPS 中清晰可见；浅灰 D9D9D9 在 WPS 几乎看不见） |
| 列宽 | 序号5 / 名称38 / URL50 / 类别14 / 网站类型14 / 功能定位32 / 是否重复10 / 备注30 / 添加日期12 |
| 筛选+冻结 | 顶部第一行自动筛选（`auto_filter.ref` 覆盖数据范围）+ 冻结首行（`freeze_panes='A2'`） |

**幂等**：脚本统一 字体/行高/对齐/边框/填充/URL蓝字/筛选/冻结 全格式，可反复跑不叠加。斑马纹从第一数据行开始按行号奇偶交替，浅蓝 `EEF4FB` 为统一强调色，可 `--accent` 覆盖。

**写回行序的操作后必须重跑 style_table**：排序（sort_table）、移表（move_entry）、删行（dedup --delete）都只搬内容不搬样式，斑马纹按原行号留在原地会错位。这三个操作完成后统一跑 `style_table.py` 恢复。冻结行/auto_filter 不受写回影响。

**美化边界（防止手动破坏一致性）**：
- **行高 22 是统一基线**：个别长文本行（如功能定位超长）由 WPS 自适应换行，不逐行手动拉高——人为调高会破坏全表统一节奏
- **列宽是规范不是建议**：固定 9 列列宽（序号5/名称38/URL50/类别14/网站类型14/功能定位32/是否重复10/备注30/添加日期12），**不要按内容手动加宽/缩窄**——保持全库列宽一致，跨表对比才顺畅。URL 蓝字 `2563EB` 是统一强调，不单独给某行标色
- **筛选/冻结是脚本统一加的（幂等）**：手动拖筛选下拉框、手动拖冻结线、手动调边框色都算破坏格式，重跑 style_table 会重置——遇到排版问题一律改脚本重跑，不手改单格

`style_index.py`（索引表）同样带 筛选+冻结+深灰边框；数据行循环跳过整行全空的行。

**索引表（书签整理最终清单）**：结构为 4 列（表/条数/所属类别/说明），用 `scripts/style_index.py` 美化，同体系但列对齐不同：

| 区域 | 样式 |
|---|---|
| 表头 | 深蓝底 `3867A6` 白字加粗，行高 26 |
| 数据行 | 微软雅黑 10.5、行高 22、斑马纹 `EEF4FB`/白 |
| 列对齐 | 表/所属类别/说明 左对齐+换行；条数 居中 |
| 合计行 | 浅黄底 `FFF2CC` 加粗突出 |

## 10. 自动辅助脚本（推断 / 导入 / 统计 / 健康检查）

以下脚本全部**只读**（dedup 的 `--delete` 除外），把机械判断从"逐行人工"降为"脚本建议 + 人工/LLM 确认"。

### 10.1 URL 推断 `infer_from_url.py`

```bash
python scripts/infer_from_url.py <url> [...]                  # 给 URL 出建议
python scripts/infer_from_url.py <xlsx> --enrich [--changed]  # 给表批量出建议清单
python scripts/infer_from_url.py <url> --table                # 额外给出"应进哪张表"建议
python scripts/infer_from_url.py <url> --online               # 兜底时联网抓 <title> 作证据
```

- 优先级：内置知名平台规则 → 从库学习（`域名→网站类型/类别` 多数派）→ 兜底 `官网·工具`
- 内置规则的类型值**全部取自库中已有词汇**，不造新词；学习随库更新自动跟随
- **定位是"建议起点"**：推断是域名级粗粒度，人工整理是行级细粒度（同是 `github.com`，Skill仓库/工具仓库/MCP仓库不同），最终值由人工/LLM 确认
- `--table` 用库中学到的 `域名→表` 多数派给出"新增书签应进哪张表"建议（如 github.com → GitHub书签汇总.xlsx），只在库中见过该域名时才建议
- `--online` 只对"兜底"来源的 URL 发起请求抓 `<title>`/`og:title` 作证据（不强行下结论，来源标 `兜底·title:xx`）；默认离线快，无网络请求

### 10.2 浏览器书签导入 `import_html.py`

```bash
python scripts/import_html.py <bookmarks.html> [--infer [--dir 库目录]]  # HTML 书签
python scripts/import_html.py <urls.txt> --infer                          # 纯 URL 清单
```

- 解析 Chrome/Edge/Firefox 导出的 Netscape bookmark HTML，按文件夹层级分组输出待入库清单
- 也支持**纯 URL 文本**（每行一个 URL，或用 `名称 || URL` 带上名称）——适合手头只有一批链接时
- `--infer` 时每条附 网站类型/类别 + 建议表（进哪张表）；**不写表**，确认后走正常新增流程
- `--online` 透传给推断引擎；输出的"可参照表"提示供 LLM 判断分到哪张表

### 10.3 全库统计报告 `report_summary.py`

```bash
python scripts/report_summary.py [--dir 书签目录] [--out report.md]
```

- 输出：总规模 / 每表条数·重复数·添加日期范围 / 跨表同 URL / 疑似失效（类别=`失效链接`或备注含"失效"）/ 低频类别·类型（供合并审视）/ 类别分布 Top 20
- 低频清单可能较长，已截断为 Top 25 + 总数提示

### 10.4 URL 健康检查 `check_urls.py`

```bash
python scripts/check_urls.py <xlsx> [<xlsx>...]          # 检查指定表
python scripts/check_urls.py --dir 书签目录 --limit 100   # 全库抽样
python scripts/check_urls.py <xlsx> --skip example.com   # 跳过域名防误报
```

- HEAD 优先，405/403/501 回落 GET；判定 2xx/3xx 健康、404/410 死链、5xx 服务器错误、ERR 连接失败
- localhost / 私有网段 / 非 http(s) 自动跳过
- **会真实发起网络请求**；部分站点限流反爬，`--skip` 排除；全库需 `--limit` 防一次 1700+ 请求
- 结果为清理清单，ERR/5xx 需人工核实（可能是临时故障），404/410 可考虑移除

### 10.5 智能去重（dedup_report.py 升级）

- `--suggest`：报告"URL 归一化后相同但未标重复"的候选组，供人工标 `是`
- `--delete` 判定用归一化 URL（去协议/www/尾斜杠/query/fragment），`www.x.com/a` 与 `x.com/a?x=1` 判为同一
- 仍只删"重复："/归一化同 URL 的真重复，同源子页自动跳过

## 11. 书签移表（move_entry.py）

把一条书签从 A 表移到 B 表（含同文件跨 sheet），按 URL 定位、按名称锚点插入，双表自动重编号：

```bash
python scripts/move_entry.py --from src.xlsx --url <url> --to dst.xlsx \
    [--from-sheet 源sheet] [--to-sheet 目标sheet] [--cat 新类别] \
    [--before "名称"] [--after "名称"] [--dry-run]
```

- **定位用 URL**：精确匹配（忽略末尾斜杠），不用序号
- **插入位置**：`--before/--after` 按目标表名称锚点；默认插到同类别最后一行后，目标表无该类则追加表尾
- **同文件跨 sheet**：`--from` 与 `--to` 传同一文件，加 `--from-sheet`/`--to-sheet`
- `--dry-run` 只打印不写文件；写回后样式简化，跑 `style_table.py` 恢复美化
- 移动后如备注引用受影响，跑 `verify_table.py` 检查悬空/跨sheet

## 12. 自动化闭环（捕获 / 补全 / 健康 / 门户 / 同步 / 审计）

以下脚本把书签价值链两端补齐：**发现端零摩擦入库**、**消费端可搜索**、**生命周期自动治理**。它们复用既有脚本的写表逻辑（`entry.add_cmd` / `InferEngine` / `check_urls.check_one` / `export_bookmarks` / `import_html`），不重复实现。

### 12.1 零摩擦捕获 `capture.py`

```bash
python scripts/capture.py https://example.com               # 只出清单（推荐先看）
python scripts/capture.py https://example.com --online      # 联网抓 <title> 作名称
python scripts/capture.py https://a.com --add --yes         # 一键写表（自动查重+备份+重编号）
```

- `URL → 抓title(可选) → 推断类型/类别 → 建议表 → 全库查重 → 确认后写表`
- 复用 `entry.add_cmd()`，与日常新增完全一致的查重/备份/重编号；全库查重命中会列出，`--force` 才可重复入库
- title 抓取失败用域名占位并标 `[无title]`，不阻塞捕获
- 多 sheet 文件默认写**第一个 sheet**（与 `entry.py add` 一致）；建议显式 `--sheet` 或 `--cat` 让插入位置落到正确子表

### 12.2 AI 自动补全 `ai_enrich.py`

```bash
python scripts/ai_enrich.py <xlsx>                 # 预览（默认只打印建议）
python scripts/ai_enrich.py <xlsx> --apply         # 写回（改前自动备份）
python scripts/ai_enrich.py --dir . --limit 50     # 全库前 50 条（需 AI_API_KEY）
python scripts/ai_enrich.py <xlsx> --only-empty    # 只处理未填类别/类型的行
```

- **LLM 直连**：标准库 `urllib` POST Anthropic Messages API，**key 从环境变量 `AI_API_KEY` 读**（不写进 config.py，防公开仓库泄漏）；端点/模型见 `config.AI_ENRICH`
- **LLM 为主判**：输出覆盖类别/类型/定位/备注四列；`InferEngine` 推断结果作为 prompt 上下文参考
- **失败兜底**：LLM 失败的行保留原值、不下写；跑完请 review（建议不绝对正确）
- 返回 JSON：`{type, cat, desc, note, is_dup, dup_reason}`；`--only-empty` 配合定时任务可做增量补全
- **`--apply` 写回后**建议跑 `style_table.py` 恢复样式，再 `verify_table.py` 验证

### 12.3 自动健康检查 `health_check_auto.py`

```bash
python scripts/health_check_auto.py <xlsx> [--write] [--log health.log]
python scripts/health_check_auto.py --dir . --limit 200 --write --log health.log
```

- **最小侵入写回**：仅死链(404/410)/客户端错误(4xx)/连接失败(ERR) 的行，在备注**追加** ` | 检查:YYYY-MM-DD 状态:X`；健康行备注不动
- **幂等**：`strip_check_tail` 先剥旧尾巴再重测；状态转好的行剥除尾巴还原原备注
- **类别/网站类型不改**（避免与 `DEAD_CATEGORY` 语义混淆）；检查记录写独立日志（`--log`）
- 复用 `check_urls.check_one`；真实发请求，全库需 `--limit`，防爬站点 `--skip`
- **Windows 定时**（任务计划程序，每日 9 点，手动执行一次）：
  ```bash
  schtasks /create /tn "书签健康检查" /tr "\"D:\\Python\\python.exe\" \"...\\scripts\\health_check_auto.py\" --dir 书签库 --limit 300 --write --log health.log" /sc daily /st 09:00 /f
  ```

### 12.4 检索门户 `build_portal.py`

```bash
python scripts/build_portal.py --dir . --out portal.html
```

- 全库 → **单文件可搜索 HTML**（零依赖，双击 `file://` 即用）：搜索框按名称/URL/类别/类型/定位/备注实时过滤 + 类别标签点击切换
- 按类别分区块，每区按表分组展示；顶部统计（共 N 条 | M 类别 | K 表）
- 只读不写表；数据嵌入 HTML，重新生成即可刷新。适合放桌面/网盘随时查

### 12.5 双向同步 `reconcile.py`

```bash
python scripts/reconcile.py bookmarks.html --dir .            # 只出 diff
python scripts/reconcile.py bookmarks.html --dir . --sync     # 浏览器→表（补 only_in_html）
python scripts/reconcile.py --export --out bookmarks_sync.html  # 表→浏览器
```

- `only_in_html`（浏览器有、表没有）→ 补进表；`only_table`（表有、浏览器没有）→ 仅报告
- 补入决策链：文件夹路径 → 库中表名模糊匹配（`AI/` 进 AI书签汇总.xlsx）→ 兜底 `DEFAULT_TABLE`
- 复用 `entry.add_cmd`（自动查重/备份/重编号）+ `import_html.BookmarkParser`；`--export` 复用 `export_bookmarks`

### 12.6 智能审计 `ai_audit.py`

```bash
python scripts/ai_audit.py --dir . --out audit.md          # 默认报告
python scripts/ai_audit.py --dir . --samples 3             # 每表抽 3 条
python scripts/ai_audit.py --dir . --focus 类别名           # 专项追问
```

- **分层采样控制 LLM 调用量**：全库 1800+ 条 → 1~3 次调用。库级统计纯 Python（0 次）→ 每表抽 1-2 条代表性行（低频类别优先）→ 单次 prompt 汇总；`--focus` 按需追加
- 复用 `ai_enrich.call_llm_one`（同一 HTTP 通道，同 `AI_API_KEY`）
- 输出「书签健康报告」：内容过时/冗余信号、质量缺口、可合并类别、行动清单
- LLM 失败兜底：仍输出纯 Python 统计报告

### 12.7 LLM 配置约定（ai_enrich / ai_audit 共用）

- **API key 只从环境变量 `AI_API_KEY` 读**，绝不落进 config.py / 公开仓库
- 端点/模型/超时/重试见 `config.AI_ENRICH`（默认 Anthropic Messages API，`claude-sonnet-5`）
- 所有写表脚本（capture/ai_enrich --apply/health_check --write/reconcile --sync）写前自动备份 `<表>.bak.xlsx`
