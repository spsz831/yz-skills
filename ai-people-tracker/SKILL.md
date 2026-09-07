---
name: ai-people-tracker
version: 0.1.1
description: AI 人物追踪表新增人物流程。用户在 D:\yangzhen\workskill\ 目录下的 AI 人物追踪表中添加新人物时，本 skill 固化「改数据 → 跑生成 → 双验证 → 替换文件」的完整流水线与字段写作规范，避免反复踩坑。
trigger:
  - 给追踪表加人
  - AI人物表添加
  - 追踪表加 XX
  - 追加人物
  - 更新 AI 人物追踪表
  - 帮我在追踪表里加
  - ai-people-tracker
---

# ai-people-tracker — AI 人物追踪表 · 添加人物流水线

## 1. 触发与范围

当用户要求「给 AI 人物追踪表添加人物/扩充名单」时启用。

**不做的事**：
- 不在本 skill 里复制 MAIN_ROWS 数据（数据属项目文件）
- 不自动推断未经核实的信息（存疑一律标「待核实/存疑」）
- 不改动言论库数据（QUOTE_ROWS 是独立素材库）

## 2. 前置事实（写死，不可改动）

| 项目 | 路径 / 值 |
|------|-----------|
| 项目目录 | `D:\yangzhen\workskill\` |
| 生成脚本 | `build_ai_people_xlsx.py` |
| 独立验证脚本 | `verify_ai_people_xlsx.py [xlsx路径]` |
| 输出目标 | `AI人物追踪表.xlsx`（2 sheet：人物主表 + 言论库） |
| Python | `/c/Users/zhen/.local/bin/python3.12.exe` |
| 环境编码 | `export PYTHONIOENCODING=utf-8`（Windows GBK 默认，不 export 会 UnicodeEncodeError） |
| minimax-xlsx 模板根 | `C:/Users/zhen/.claude/plugins/cache/minimax-skills/minimax-skills/1.0.0/skills/minimax-xlsx/templates/minimal_xlsx` |
| 打包脚本 | 同上目录下的 `scripts/xlsx_pack.py` |
| 公式校验脚本 | 同上目录下的 `scripts/formula_check.py` |

## 3. 字段写作规范（MAIN_ROWS 每行 14 列）

```
[序号, 姓名, 外号/昵称, 英文名, 机构与职位, 圈层, 国别,
       观点立场, 立场变化, 代表事件, 发声渠道,
       关注优先级, "", 备注]
```

### 3.1 圈层（严格 8 选 1）
`AI领军` / `技术大神` / `学者` / `芯片硬件` / `投资圈` / `机器人` / `巨头掌门` / `AI应用`

### 3.2 国别（仅两个值）
`国内` / `海外`

### 3.3 关注优先级
`高` / `中` / `低`（下拉校验限制，超出会报错）

### 3.4 序号规则
连续递增，**不要留空号**。新加 N 人就在最后追加序号 `last+1 … last+N`。

### 3.5 观点立场 / 立场变化
- 观点立场：≤12 字的一句话概括，如「AGI加速+监管叙事并行」「开源扩张:Llama 免费开放换生态」
- 立场变化：≤20 字的关键转折，如「2023谨慎叙事→2025《温和奇点》乐观加速」
- 两者都要有**时间线或对比**，不能只写标签

### 3.6 发声渠道
不限 X 平台。可以是：`X @用户名` / `微博@用户名` / `B站/微博 @名字` / `官网/博客` / `访谈为主` / `(无个人账号)发布会为主` 等。

### 3.7 备注（第14列，最后一列）
- 信息未经核实时：**必须**在备注末尾标注「待核实」或「存疑」
- 典型场景：入职传闻、职位变更、上市细节、争议说法
- 示例：`「2026 加入 OpenAI」一说待核实`；`「东方算芯董事长」一说存疑，以清华教授为准`

### 3.8 英文名
能写就写；没有稳定英文名可留空或写拼音。注意人名拼写核对（曾有示例把 Demi Guo 误写成 Jing Wang）。

## 4. 操作步骤（严格按此顺序）

### Step 0 — 准备 Python 环境
```bash
export PYTHONIOENCODING=utf-8
export PYTHONDONTWRITEBYTECODE=1
```

### Step 1 — 从干净模板拷贝工作目录
```bash
rm -rf /tmp/ai_people_work && mkdir -p /tmp/ai_people_work
cp -r /c/Users/zhen/.claude/plugins/cache/minimax-skills/minimax-skills/1.0.0/skills/minimax-xlsx/templates/minimal_xlsx/* /tmp/ai_people_work/
```
> ⚠️ **必须每次 fresh 拷贝**。直接复用旧目录会导致 styles.xml 被双 patch（cellXfs 13-21 重复写入，验证脚本报 xf borderId=0）。

### Step 2 — 编辑 MAIN_ROWS
用 Edit 工具打开 `D:\yangzhen\workskill\build_ai_people_xlsx.py`，在 `MAIN_ROWS = [` 列表末尾追加新行（保持 14 个元素）。

编辑完成后**快速自检**：
- 新行元素个数 == 14
- 序号连续，没有重复
- 备注里如果有「待核实/存疑」，前面已做标注

### Step 3 — 运行生成
```bash
cd D:/yangzhen/workskill
/c/Users/zhen/.local/bin/python3.12.exe build_ai_people_xlsx.py /tmp/ai_people_work
```
正常输出末尾应打印 `DONE`，同时打印各 XML 文件大小与 sharedStrings 数量。

### Step 4 — 打包 xlsx
```bash
/c/Users/zhen/.local/bin/python3.12.exe /c/Users/zhen/.claude/plugins/cache/minimax-skills/minimax-skills/1.0.0/skills/minimax-xlsx/scripts/xlsx_pack.py /tmp/ai_people_work /tmp/AI人物追踪表_new.xlsx
```

### Step 5 — 公式校验
```bash
/c/Users/zhen/.local/bin/python3.12.exe /c/Users/zhen/.claude/plugins/cache/minimax-skills/minimax-skills/1.0.0/skills/minimax-xlsx/scripts/formula_check.py /tmp/AI人物追踪表_new.xlsx --json
```
公式校验退出码应为 0。若有错误立即停止，不要继续。

### Step 6 — 结构验证（独立双验）
```bash
/c/Users/zhen/.local/bin/python3.12.exe D:/yangzhen/workskill/verify_ai_people_xlsx.py /tmp/AI人物追踪表_new.xlsx
```
输出末尾必须是 `RESULT: ALL PASS`，否则排查失败点再退回 Step 1。

### Step 7 — 覆盖目标文件
```bash
cp /tmp/AI人物追踪表_new.xlsx D:/yangzhen/workskill/AI人物追踪表.xlsx
```
> ⚠️ **如果报 PermissionError / Device or resource busy**，说明 Excel/WPS 还在占用目标文件。请提示用户关闭后再执行本步；**不要**在锁定状态下反复重试。

### Step 8 — 清理
```bash
rm -rf /tmp/ai_people_work /tmp/AI人物追踪表_new.xlsx
```

## 5. 常见坑（经验备忘录）

| 坑 | 症状 | 解法 |
|----|------|------|
| styles.xml 双 patch | verify 报 `xf[22] borderId=0` 或 cellXfs count > 22 | 必须每次 fresh 拷贝模板，绝不复用旧 workdir |
| 模板垃圾部件混入 | zip list 出现 `minimal_xlsx/` 子目录 | `cp -r src/* dest/`（不是 `cp -r src/ dest/`），确保 flatten |
| 列错位 | 备注值错跑到公式列位置，公式也重 | 检查 build_sheet 的公式列插入逻辑；用 verify 的 ref 抽查 |
| 文件被占用 | cp 报 PermissionError | 让用户关 Excel/WPS 后重试 |
| UnicodeEncodeError | Python 报 GBK 编码错误 | 加 `export PYTHONIOENCODING=utf-8` |
| PersonNames 失效 | 言论库姓名下拉报错 | 检查 workbook.xml 的 definedName：`人物主表!$B$3:$B${last_row}` |
| `_data_style` 列偏移 | verify 报 M列样式错误（s=15而非18） | `_data_style` 函数需传入 `formula_col` 参数，计算 `hdr_ci = ci - (1 if ci > formula_col else 0)` 修正 header 索引 |

## 6. 新增列/改结构（超出本 skill 职责）

如果用户要求修改列结构（增删列、改名、改公式），本 skill **不自动处理**。此时应：
1. 明确告知用户这是一个**破坏性改动**，当前数据需迁移
2. 进入编辑模式：先读 build_ai_people_xlsx.py 的全部逻辑
3. 重新跑 Step 1–8，并**重写 verify 脚本的 expect 字段**
4. 告知用户旧 xlsx 文件会被完全重建

## 7. 推送仓库

本 skill 文件位于 `C:\Users\zhen\.claude\skills\ai-people-tracker\SKILL.md`，本地可用。是否推送到 github.com/spsz831/yz-skills 仓库，**每次单独确认**，不默认推送。
