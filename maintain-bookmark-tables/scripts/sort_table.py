#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签汇总表按类别优先排序并重编号 1..N，覆盖写回（保留样式/冻结行）。

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


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('xlsx')
    ap.add_argument('--order', required=True, help='逗号分隔的类别顺序')
    args = ap.parse_args(argv)
    cat_order = [c.strip() for c in args.order.split(',') if c.strip()]

    wb = openpyxl.load_workbook(args.xlsx)
    ws = wb.active
    data = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, 10)]
        if vals[1] is None:
            continue
        data.append(vals)

    # 护栏：存在旧式引用（序号/「」）时拒绝排序，防止排序重编号后引用错位
    old = [r for r in data if r[7] and ('序号' in str(r[7]) or '与同表「' in str(r[7]))]
    if old:
        print(f'⚠️ 存在 {len(old)} 处旧式引用，排序重编号后引用会失效，请先改为名称式引用:')
        for r in old[:10]:
            print(f'  序号{r[0]} | {r[1]} | {r[7]}')
        print('已中止排序')
        return 1

    # 网站类型: 同类内按首次出现分组排序
    stype_order = OrderedDict()
    for i, row in enumerate(data):
        if (row[3], row[4]) not in stype_order:
            stype_order[(row[3], row[4])] = i
    cat_idx = {c: i for i, c in enumerate(cat_order)}
    idx_map = {id(row): i for i, row in enumerate(data)}
    data.sort(key=lambda row: (cat_idx.get(row[3], len(cat_order) + 1),
                               stype_order.get((row[3], row[4]), 0), idx_map[id(row)]))

    for i, row in enumerate(data):
        rr = i + 2
        for c in range(1, 10):
            ws.cell(rr, c).value = row[c - 1]
        ws.cell(rr, 1).value = i + 1
    wb.save(args.xlsx)
    print(f'已排序并重编号 {len(data)} 条: {args.xlsx}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
