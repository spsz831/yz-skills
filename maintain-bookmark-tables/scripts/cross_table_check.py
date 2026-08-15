#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签汇总表跨表一致性检查（只读）。

用法: python cross_table_check.py [目录]      # 默认扫描当前目录 *书签汇总.xlsx

检查三项:
  1. 悬空引用 —— 备注里 与同表『X』/见同表『X』 的 X 是否真的存在于同表名称列
                 （排序后名称引用是唯一可靠的引用方式，目标名必须精确匹配）
  2. 跨表引用 —— 备注里 "同源已收录于XX书签汇总.xlsx" 的 XX 文件是否存在
  3. URL 跨表 —— 同一 URL 出现在 ≥2 张表，提示核对是否应标记重复。
                 已标「是否重复=是」的行归为「已标记」不再告警，只报未标记的。
"""
import sys, io, re, glob, os, openpyxl
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
try:
    from config import (REF_RE, CROSS_RE, TABLE_GLOB, COLUMN_COUNT,
                        COLUMNS, DUP_MARK)
except ImportError:
    REF_RE = re.compile(r'同表『([^』]+)』')
    CROSS_RE = re.compile(r'收录于([^；;。]+\.xlsx)')
    TABLE_GLOB = '*书签汇总.xlsx'
    COLUMN_COUNT = 9
    COLUMNS = {'序号': 0, '名称': 1, 'URL': 2, '类别': 3, '网站类型': 4,
               '功能定位': 5, '是否重复': 6, '备注': 7, '添加日期': 8}
    DUP_MARK = '是'

I_NAME = COLUMNS.get('名称', 1)
I_URL = COLUMNS.get('URL', 2)
I_DUP = COLUMNS.get('是否重复', 6)
I_NOTE = COLUMNS.get('备注', 7)


def load(path):
    wb = openpyxl.load_workbook(path)
    ws = wb.active
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, COLUMN_COUNT + 1)]
        if vals[I_NAME] is None:
            continue
        rows.append(vals)
    return rows


def main(argv):
    directory = argv[0] if argv else '.'
    files = sorted(p for p in glob.glob(os.path.join(directory, TABLE_GLOB))
                   if not os.path.basename(p).startswith('~$'))
    if not files:
        print(f'目录下未找到 {TABLE_GLOB}: {directory}')
        return 1

    all_rows = {}      # path -> rows
    name_owner = {}    # 名称 -> [path,...]
    url_owner = {}     # URL -> [(path, marked), ...]  是否重复=是
    for f in files:
        rows = load(f)
        all_rows[f] = rows
        for r in rows:
            name_owner.setdefault(str(r[I_NAME]).strip(), []).append(f)
            marked = str(r[I_DUP]).strip() == DUP_MARK if r[I_DUP] else False
            url_owner.setdefault(str(r[I_URL]).strip(), []).append((f, marked))

    ok = True
    print(f'扫描 {len(files)} 张表\n')

    # 1. 悬空引用
    dangling = []
    for f, rows in all_rows.items():
        names = {str(r[I_NAME]).strip() for r in rows}
        for r in rows:
            note = str(r[I_NOTE])
            for m in REF_RE.finditer(note):
                target = m.group(1).strip()
                if target and target not in names:
                    dangling.append((f, r[0], target))
    if dangling:
        ok = False
        print(f'⚠️ 悬空引用 {len(dangling)} 处（同表『X』目标名不存在）:')
        for f, seq, target in dangling:
            print(f'  {os.path.basename(f)} 序号{seq} -> 『{target}』')
    else:
        print('✅ 悬空引用: 0')

    # 2. 跨表引用文件存在性
    missing = []
    for f, rows in all_rows.items():
        for r in rows:
            for m in CROSS_RE.finditer(str(r[I_NOTE])):
                target = os.path.join(directory, m.group(1).strip())
                if not os.path.exists(target):
                    missing.append((f, r[0], m.group(1)))
    if missing:
        ok = False
        print(f'⚠️ 跨表引用指向不存在的文件 {len(missing)} 处:')
        for f, seq, t in missing:
            print(f'  {os.path.basename(f)} 序号{seq} -> {t}')
    else:
        print('✅ 跨表引用文件: 齐全')

    # 3. URL 跨表重复（已标"是否重复=是"的行不再告警）
    dup_url = {u: ps for u, ps in url_owner.items() if len(ps) > 1 and u}
    unmarked = {u: ps for u, ps in dup_url.items() if not all(m for _, m in ps)}
    if unmarked:
        ok = False
        print(f'⚠️ 同 URL 出现在多表且未标重复 {len(unmarked)} 组（核对是否应标"是否重复=是"）:')
        for u, ps in unmarked.items():
            print(f'  {u}')
            for p, m in ps:
                print(f'    -> {os.path.basename(p)}' + ('' if m else '  [未标记]'))
    else:
        print('✅ 跨表 URL 重复: 0 处未标记')

    marked_done = {u: ps for u, ps in dup_url.items() if all(m for _, m in ps)}
    if marked_done:
        print(f'ℹ️  同 URL 跨表且已标重复 {len(marked_done)} 组（无需处理）')

    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
