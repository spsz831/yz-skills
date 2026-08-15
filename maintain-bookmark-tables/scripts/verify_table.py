#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签汇总表六指标验证。全 0 才算通过。

用法: python verify_table.py <xlsx路径> [<xlsx路径>...]
退出码: 0=全部通过, 1=存在残留

六指标:
  空值     —— 类别/网站类型/功能定位/备注 任一为空
  笼统     —— 网站类型仍是笼统值（在线工具/官网/GitHub/B站/国内平台 等）
  旧引用   —— 备注含 '序号'/'与同表「'，或含『』外的『同源+「』写法
  断档     —— 类别分组在行序上被切断（同类中间插入他类）
  悬空     —— 『与同表『X』』的 X 在同表名称列不存在，且整个文件也不存在
  跨sheet  —— 『与同表『X』』的 X 不在本 sheet 名称列、但在同文件其他 sheet 存在
              （多 sheet 文件里跨子表引用不能写「同表」，须改成
               `与『X』同源（见AI书签汇总.xlsx某sheet）`）
  残行     —— 名称列为空但其余列有内容（半截残留记录，如只有 URL 无名称）
"""
import sys, io, os, re, openpyxl
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
try:
    from config import (BAD_TYPES, REF_RE, COLUMN_COUNT, COLUMNS, INDEX_MARKERS, is_index)
except ImportError:  # 直接以单文件方式运行时，提供内联默认
    BAD_TYPES = ('Outlook邮箱', '免费邮箱', '教育邮箱', '临时邮箱', '在线工具', '学习教程',
                 '国内平台', '国外平台', 'GitHub', 'B站')
    REF_RE = re.compile(r'同表『([^』]+)』')
    COLUMN_COUNT = 9
    COLUMNS = {'序号': 0, '名称': 1, 'URL': 2, '类别': 3, '网站类型': 4,
               '功能定位': 5, '是否重复': 6, '备注': 7, '添加日期': 8}
    INDEX_MARKERS = ('书签整理最终清单',)
    def is_index(path): return any(m in path for m in INDEX_MARKERS)

# 列语义快捷名（0-based 索引，随 COLUMN_HEADERS 顺序）
I_NAME = COLUMNS.get('名称', 1)
I_URL = COLUMNS.get('URL', 2)
I_CAT = COLUMNS.get('类别', 3)
I_TYPE = COLUMNS.get('网站类型', 4)
I_NOTE = COLUMNS.get('备注', 7)


def audit_ws(ws, sheet_names=None):
    """审计单个 sheet。sheet_names: {sheet名: 名称集合}，用于跨 sheet 悬空判定。"""
    rows = []
    incomplete = 0
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, COLUMN_COUNT + 1)]
        if vals[I_NAME] is None:
            # 残行：名称列为空但其余列有内容
            if any(v is not None for i, v in enumerate(vals) if i != I_NAME):
                incomplete += 1
            continue
        rows.append(vals)
    total = len(rows)
    empty = sum(1 for r in rows if not all(r[c] for c in (I_CAT, I_TYPE, I_NOTE, COLUMNS.get('功能定位', 5))))
    bad = sum(1 for r in rows if r[I_TYPE] in BAD_TYPES)
    ref = sum(1 for r in rows if r[I_NOTE] and (
        '序号' in str(r[I_NOTE]) or '与同表「' in str(r[I_NOTE])
        or ('『' not in str(r[I_NOTE]) and '同源' in str(r[I_NOTE]) and '「' in str(r[I_NOTE]))))
    order = [r[I_CAT] for r in rows]
    seen, broken, cur = set(), 0, None
    for cat in order:
        if cat != cur:
            if cat in seen:
                broken += 1
            cur = cat
        seen.add(cat)
    names = {str(r[I_NAME]).strip() for r in rows}
    file_names = set().union(*sheet_names.values()) if sheet_names else names
    dangling = cross_sheet = 0
    for r in rows:
        if not r[I_NOTE]:
            continue
        for m in REF_RE.finditer(str(r[I_NOTE])):
            target = m.group(1).strip()
            if not target or target in names:
                continue  # 本 sheet 内命中，OK
            if target in file_names:
                cross_sheet += 1  # 目标在文件其他 sheet，但用了「同表」= 写法错误
            else:
                dangling += 1  # 整个文件都找不到 = 真悬空
    return total, empty, bad, ref, broken, dangling, cross_sheet, incomplete


def audit(path):
    """审计整个文件：返回 ([(sheet名, 指标元组), ...], sheet_names)。多 sheet 文件逐 sheet 审计。"""
    wb = openpyxl.load_workbook(path)
    sheet_names = {}
    for ws in wb.worksheets:
        sheet_names[ws.title] = {str(ws.cell(r, COLUMNS['名称'] + 1).value).strip()
                                 for r in range(2, ws.max_row + 1)
                                 if ws.cell(r, COLUMNS['名称'] + 1).value}
    results = []
    for ws in wb.worksheets:
        results.append((ws.title, audit_ws(ws, sheet_names)))
    wb.close()
    return results, sheet_names


def main(argv):
    if not argv:
        print('用法: python verify_table.py <xlsx> [<xlsx>...]')
        return 2
    ok = True
    for path in argv:
        if is_index(path):
            print(f'⏭️  跳过索引表（4列结构，非{COLUMN_COUNT}列书签表）: {path}')
            continue
        results, sheet_names = audit(path)
        for title, (total, empty, bad, ref, broken, dangling, cross_sheet, incomplete) in results:
            flag = '✅' if (empty, bad, ref, broken, dangling, cross_sheet, incomplete) == (0, 0, 0, 0, 0, 0, 0) else '⚠️'
            if flag == '⚠️':
                ok = False
            label = f'{path}[{title}]' if len(results) > 1 else path
            print(f'{flag} {label}: 共{total} 空值{empty} 笼统{bad} 旧引用{ref} 断档{broken} 悬空{dangling} 跨sheet{cross_sheet} 残行{incomplete}')
            if dangling or cross_sheet:
                for seq, target, kind in _dangling_rows_ws(path, title, sheet_names):
                    print(f'    [{title}] 序号{seq} -> 『{target}』（{kind}）')
            if incomplete:
                print(f'    [{title}] 有 {incomplete} 行名称列为空的残行')
    return 0 if ok else 1


def _dangling_rows_ws(path, title, sheet_names):
    """返回指定 sheet 的 (序号, 悬空目标名, 类型) 列表，供定位修复。kind ∈ {'悬空','跨sheet'}"""
    wb = openpyxl.load_workbook(path)
    ws = wb[title]
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, COLUMN_COUNT + 1)]
        if vals[I_NAME] is None:
            continue
        rows.append(vals)
    names = {str(r[I_NAME]).strip() for r in rows}
    file_names = set().union(*sheet_names.values()) if sheet_names else names
    out = []
    for r in rows:
        if not r[I_NOTE]:
            continue
        for m in REF_RE.finditer(str(r[I_NOTE])):
            target = m.group(1).strip()
            if not target or target in names:
                continue
            kind = '悬空' if target not in file_names else '跨sheet'
            out.append((r[0], target, kind))
    wb.close()
    return out


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
