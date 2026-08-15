#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签汇总表按类别优先排序并重编号 1..N，覆盖写回。

注意：排序写回只搬内容不搬样式，斑马纹会按原行号错位。
排序完成后必须重跑 style_table.py 恢复美化（冻结行/auto_filter 不受影响）。

用法: python sort_table.py <xlsx> --order "类别A,类别B,类别C,..."

排序规则（类别优先）:
  1. 类别: 按 --order 出现的顺序
  2. 网站类型: 同一类别内按首次出现的顺序分组
  3. 原行序: 其余保持稳定（同名行不被打散）

类别不在 --order 中时排到最后。重写序号列前先完整核对引用不依赖序号。
"""
import sys, io, argparse, openpyxl
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from collections import OrderedDict
try:
    from config import COLUMN_COUNT, COLUMNS
except ImportError:
    COLUMN_COUNT = 9
    COLUMNS = {'序号': 0, '名称': 1, 'URL': 2, '类别': 3, '网站类型': 4,
               '功能定位': 5, '是否重复': 6, '备注': 7, '添加日期': 8}

I_NOTE = COLUMNS.get('备注', 7)
I_CAT = COLUMNS.get('类别', 3)
I_TYPE = COLUMNS.get('网站类型', 4)


def sort_sheet(ws, cat_order):
    """对单个 sheet 排序并重编号。返回排序条数。"""
    data = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, COLUMN_COUNT + 1)]
        if vals[COLUMNS.get('序号', 0)] is None:
            continue
        data.append(vals)

    # 护栏：存在旧式引用（序号/「」）时拒绝排序，防止排序重编号后引用错位
    old = [r for r in data if r[I_NOTE] and ('序号' in str(r[I_NOTE]) or '与同表「' in str(r[I_NOTE]))]
    if old:
        print(f'⚠️ 存在 {len(old)} 处旧式引用，排序重编号后引用会失效，请先改为名称式引用:')
        for r in old[:10]:
            print(f'  序号{r[0]} | {r[1]} | {r[I_NOTE]}')
        return None

    # 网站类型: 同类内按首次出现分组排序
    stype_order = OrderedDict()
    for i, row in enumerate(data):
        if (row[I_CAT], row[I_TYPE]) not in stype_order:
            stype_order[(row[I_CAT], row[I_TYPE])] = i
    cat_idx = {c: i for i, c in enumerate(cat_order)}
    idx_map = {id(row): i for i, row in enumerate(data)}
    data.sort(key=lambda row: (cat_idx.get(row[I_CAT], len(cat_order) + 1),
                               stype_order.get((row[I_CAT], row[I_TYPE]), 0), idx_map[id(row)]))

    for i, row in enumerate(data):
        rr = i + 2
        for c in range(1, COLUMN_COUNT + 1):
            ws.cell(rr, c).value = row[c - 1]
        ws.cell(rr, COLUMNS.get('序号', 0) + 1).value = i + 1
    return len(data)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('xlsx')
    ap.add_argument('--order', required=True, help='逗号分隔的类别顺序')
    ap.add_argument('--sheet', nargs='*', default=None,
                    help='指定要排序的 sheet 名（多 sheet 文件用，可多个）；默认只处理 active')
    args = ap.parse_args(argv)
    cat_order = [c.strip() for c in args.order.split(',') if c.strip()]

    wb = openpyxl.load_workbook(args.xlsx)
    sheets = [wb[s] for s in args.sheet] if args.sheet else [wb.active]
    total_sorted = 0
    for ws in sheets:
        n = sort_sheet(ws, cat_order)
        if n is None:
            wb.close()
            return 1
        total_sorted += n
        print(f'  已排序并重编号 {n} 条: [{ws.title}]')
    wb.save(args.xlsx)
    print(f'共排序 {total_sorted} 条: {args.xlsx}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
