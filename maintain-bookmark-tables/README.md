# maintain-bookmark-tables

用代码治理你的书签表：**固定结构 + 质量闸门 + 自动化脚本**。让几百上千条书签从"收藏即消失"变成可维护、可验证、可同步的数据资产。

## 它解决什么问题

浏览器书签默认是躺在那里的死列表：没有结构、重复无法发现、死链无人清理、换设备同步靠手工。这个 skill 把它变成一套**可持续治理的数据表**：

- **固定 9 列结构**：序号/名称/URL/类别/网站类型/功能定位/是否重复/备注/添加日期
- **质量闸门**：`verify_table.py` 跑 7 项检查（空值/笼统类型/旧式引用/类别断档/悬空/跨sheet/残行），全 0 才算通过——相当于给你的书签数据上了 CI
- **脚本驱动**：排序、去重、移表、跨表检查、URL 推断、书签导入、全库统计、死链检测、统一美化——全部自动化

## 安装

### 前置

- Python 3.8+
- `pip install openpyxl`（唯一依赖）

### 方式一：作为 Claude Code skill 安装

```
复制整个仓库到 ~/.claude/skills/maintain-bookmark-tables/
```

### 方式二：直接命令行使用

脚本都在 `scripts/` 下，用 `python scripts/xxx.py` 即可，不依赖 Claude Code。

## 快速开始

```bash
# 1. 准备你的书签表（Excel），表头为 9 列标准格式：
#    序号 名称 URL 类别 网站类型 功能定位 是否重复 备注 添加日期

# 2. 统一美化（筛选+冻结+深灰边框+斑马纹）
python scripts/style_table.py 你的表.xlsx

# 3. 验证 7 项指标全 0
python scripts/verify_table.py 你的表.xlsx

# 4. 日常增删改一条命令（全库查重+自动重编号+写前备份）
python scripts/entry.py add "名称" "https://url" --table 你的表.xlsx --infer

# 5. 从浏览器书签 HTML 导入
python scripts/import_html.py bookmarks.html --infer

# 6. 全库统计 / 死链检测
python scripts/report_summary.py --dir . --out report.md
python scripts/check_urls.py --dir . --limit 100

# 7. 导出浏览器书签 HTML（多机同步）
python scripts/export_bookmarks.py --dir . --out bookmarks.html

# 8. 自动化闭环（可选，需 AI_API_KEY 或浏览器文件）
python scripts/capture.py https://example.com --online      # 零摩擦捕获 → 建议清单
python scripts/ai_enrich.py 你的表.xlsx                     # AI 补全预览（--apply 写回）
python scripts/build_portal.py --dir . --out portal.html    # 检索门户（单文件可搜索 HTML）
python scripts/reconcile.py bookmarks.html --dir .          # 浏览器↔表 双向同步 diff
python scripts/ai_audit.py --dir . --out audit.md           # AI 审计报告
```

## 自定义你的表结构

所有硬编码默认值集中在 **`scripts/config.py`**（开箱即用作者的书签表结构）。别人适配自己的表，改这一个文件即可，无需动任何脚本。

```python
# 例：你的表没有"网站类型"列，多了"标签"列
COLUMN_HEADERS = ['序号', '名称', 'URL', '类别', '标签', '功能定位', '是否重复', '备注', '添加日期']

# 例：你的书签文件不叫"XX书签汇总.xlsx"
TABLE_GLOB = '*收藏.xlsx'

# 例：你的"笼统值"清单不同
BAD_TYPES = ('在线工具', '官网', '其他')
```

可配置项：

| 配置 | 说明 |
|---|---|
| `COLUMN_HEADERS` | 表头与列顺序（改这里，列语义映射自动跟随） |
| `TABLE_GLOB` | 书签表文件匹配规则（glob） |
| `INDEX_MARKERS` | 索引表文件名关键字（verify 自动跳过） |
| `BAD_TYPES` | 网站类型"笼统值"清单 |
| `REF_RE` / `CROSS_RE` | 备注里"同源引用"/"跨表引用"语法 |
| `DUP_MARK` / `DUP_PREFIX` | "是否重复"标记值 / 真重复前缀 |
| `DEAD_CATEGORY` | "失效链接"类别名 |
| `STYLE` | 字体/颜色/列宽/行高/对齐（美化用） |
| `BUILTIN_RULES` | URL 推断的内置平台规则 |
| `FALLBACK_TYPE` | 推断兜底网站类型 |
| `HTTP_TIMEOUT` / `HTTP_WORKERS` / `HTTP_UA` | 死链检测网络参数 |
| `AI_ENRICH` | LLM 端点/模型/超时/重试（ai_enrich / ai_audit 用，**无 key**，key 走环境变量 `AI_API_KEY`） |

## 脚本一览

| 脚本 | 功能 |
|---|---|
| `entry.py` | 日常增删改统一入口（add/update/delete，自动查重+重编号+备份） |
| `capture.py` | 零摩擦捕获（URL → 建议清单 → 一键入库） |
| `ai_enrich.py` | AI 自动补全（LLM 直连补四列，key 走环境变量） |
| `verify_table.py` | 7 项指标验证（质量闸门） |
| `sort_table.py` | 类别优先排序 + 重编号 |
| `style_table.py` / `style_index.py` | 统一美化（书签表 / 索引表） |
| `dedup_report.py` | 重复项报告 + 确认删除 |
| `move_entry.py` | 书签移表（URL 定位 + 双表重编号） |
| `cross_table_check.py` | 跨表一致性检查 |
| `infer_from_url.py` | URL → 网站类型/类别 自动推断 |
| `import_html.py` | 浏览器书签 HTML → 待入库清单 |
| `report_summary.py` | 全库统计报告 |
| `check_urls.py` | URL 死链检测 |
| `health_check_auto.py` | 自动健康检查（最小侵入写回备注 + 日志，可定时） |
| `build_portal.py` | 检索门户（全库 → 单文件可搜索 HTML） |
| `reconcile.py` | 浏览器书签 ↔ 表 双向同步 |
| `ai_audit.py` | 智能审计（分层采样 + LLM 健康报告） |
| `export_bookmarks.py` | 表格 → 浏览器书签 HTML（多机同步） |

## 适用场景

- **书签囤积者**：几百上千条书签手动整理根本维护不动，这个把它变成半自动
- **知识管理爱好者**：把"收藏"变成可搜索、可验证、可统计的数据资产
- **多设备同步**：表格是权威数据源，`export_bookmarks.py` 导出浏览器书签 HTML 覆盖多机
- **任何结构化收藏**：换掉 9 列结构就能套用到影视/资料/工具等其他清单

## 设计原则

- **零第三方依赖**：只依赖 openpyxl，配置是纯 Python 模块（config.py），不引 yaml
- **脚本驱动重写**：排序/移表/删行只搬内容不搬样式，跑完必须重跑 style_table 恢复美化
- **可逆优先**：去重默认只报告不删除；移表支持 `--dry-run`
- **闸门拦在最早**：任何手动处理翻车的点，都会固化成 verify 的指标
