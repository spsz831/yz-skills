---
name: maintain-bookmark-tables
description: Maintain "XX书签汇总.xlsx" bookmark summary tables (9-column format：序号/名称/URL/类别/网站类型/功能定位/是否重复/备注/添加日期). Use when adding new bookmarks, enriching the four content columns (类别/网站类型/功能定位/备注), sorting by category with CAT_ORDER, verifying tables pass the five validation metrics (空值/笼统类型/旧式引用/断档/悬空 must all be 0), cleaning duplicate rows, or checking cross-table consistency (dangling 同表『X』 references, 收录于XX.xlsx file existence, same-URL across tables). Also supports URL auto-inference (infer_from_url.py), browser bookmark import (import_html.py), library-wide stats (report_summary.py), and URL health checks (check_urls.py).
---

# Maintain Bookmark Tables

维护 `XX书签汇总.xlsx` 系列表格（openpyxl 操作，Windows 下先 `sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')`）。

完整规范见 [references/rules.md](references/rules.md)，以下为工作流速查。

## 工作流

### 1. 新增 / 编辑书签

在对应类别的表格末尾追加一行并补齐 9 列：

- **类别**：用该表已有的统一分类词汇，不造新词
- **网站类型**：`平台·业务` 格式（如 `官网·AI导航`、`GitHub·开源模型`），**禁止**笼统值
- **功能定位**：30~60 字一句话说明用途
- **是否重复**：其他表已收录则标 `是`，备注写 `重复：同源已收录于XX书签汇总.xlsx`
- **备注**：作者/平台 + 同源引用
- **添加日期**：当天 `YYYY-MM-DD`

若同源引用：`与同表『与该行名称列完全一致的名称』同源`。

### 2. 优化现有表（补四列 + 排序）

对每行逐条判断并补全四列：

1. 写出 `ENRICH = {序号: [类别, 网站类型, 功能定位, 备注]}`，逐行填充
2. 重点修复残留旧式引用：
   - `与序号N 同源` → 按同域名/同名语义重配为 `与同表『名称』同源`（**序号已因历史排序失效，不能机械替换，必须核对目标行**）
   - `与同表「」` / 与「X」同源 → 转成 `『』`
3. 用 `scripts/sort_table.py` 排序：
   - 先读全表，按业务语义生成 `CAT_ORDER`（类别顺序列表），把同一主题的类别排在一起
   - 运行 `python scripts/sort_table.py <xlsx> --order "类别A,类别B,..."`
4. 验证（第 4 步）

### 3. 验证

```bash
python scripts/verify_table.py <xlsx> [...]
```

五指标**必须全 0**：空值 / 笼统类型 / 旧式引用 / 类别断档 / 悬空。任一非 0 即返回 exit 1，修复后重跑。悬空非 0 时脚本会列出具体行：

- **同名行悬空** → 给名称列补区分后缀（URL/功能），让引用精确命中
- **别名引用悬空** → 把备注引用统一成名称列实际值（或名称列补成引用值）
- 改/截断长名时先 grep 所有引用它的行，避免反向悬空

### 4. 去重清理

```bash
python scripts/dedup_report.py <xlsx>        # 列出重复项（默认只报告）
python scripts/dedup_report.py <xlsx> --delete  # 确认后删除重复行并重编号
```

删除前会打印清单并要求输入 `y`。默认不删，仅标记。

### 5. 跨表一致性检查

```bash
python scripts/cross_table_check.py [目录]
```

检查：悬空引用（`与同表『X』` 目标名不存在）、跨表引用文件缺失、同 URL 跨表重复。发现后逐处修复。

### 6. 自动辅助（推断 / 导入 / 统计 / 健康检查）

四个只读脚本把机械判断降为"脚本建议 + 人工确认"，完整规范见 [references/rules.md](references/rules.md) §8：

```bash
python scripts/infer_from_url.py <url> [...];        # URL → 网站类型/类别 建议（内置规则+库学习）
python scripts/infer_from_url.py <xlsx> --enrich     # 给表批量出建议清单
python scripts/import_html.py <bookmarks.html> --infer  # 浏览器书签导入为待入库清单
python scripts/report_summary.py --dir . --out report.md  # 全库统计报告
python scripts/check_urls.py <xlsx> [--skip 域名]     # URL 健康检查（需联网）
python scripts/dedup_report.py <xlsx> --suggest      # 归一化后重复候选组
```

要点：

- **推断是建议起点**：域名级粗粒度，行级细粒度仍需人工/LLM 确认
- **导入不写表**：输出清单，确认后走新增流程
- **健康检查会真实发请求**：全库需 `--limit`，防爬站点 `--skip`

## 关键规则（速查）

- **引用禁用序号**，只用名称：`与同表『完整名称』同源`；名称须与目标行精确一致
- **网站类型**必须是 `平台·业务`，禁 `在线工具/官网/GitHub/B站/国内平台/国外平台` 等笼统值
- **类别词汇统一**，不造同义新词
- **不删除重复项**，仅标 `是` + 备注去向；`是` 含两种语义——`重复：`/同 URL 是真重复（可删），`与同表『X』同源` 是子页（保留）；清理须人工确认
- 排序与重编号后**序号不可再作为引用依据**

## Resources

- `scripts/verify_table.py` — 五指标验证（空值/笼统/旧引用/断档/悬空，悬空列出具体行）
- `scripts/sort_table.py` — 类别优先排序 + 重编号
- `scripts/dedup_report.py` — 重复项报告（--suggest 归一化候选）/ 确认删除
- `scripts/cross_table_check.py` — 跨表一致性检查
- `scripts/infer_from_url.py` — URL → 网站类型/类别 推断（内置规则+库学习）
- `scripts/import_html.py` — 浏览器书签 HTML 导入为待入库清单（可带推断）
- `scripts/report_summary.py` — 全库统计报告（规模/概况/重复/失效/低频词汇）
- `scripts/check_urls.py` — URL 健康检查（需联网，HEAD 优先）
- `references/rules.md` — 完整规范（表格结构 / 类型细分 / 名称引用 / 验证指标 / 排序 / 去重 / 跨表 / 自动辅助脚本）
