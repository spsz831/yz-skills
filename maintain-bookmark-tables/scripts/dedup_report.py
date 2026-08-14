#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""列出书签汇总表中标记为重复的行。默认仅报告，不删除。

用法:
  python dedup_report.py <xlsx>                 # 列出重复项
  python dedup_report.py <xlsx> --suggest       # 报告 URL 归一化后相同但未标记的候选组
  python dedup_report.py <xlsx> --delete        # 删除"真重复"行并重编号

"是否重复=是" 含两种语义，--delete 只删其中"真重复":
  真重复（可删）  —— 备注以 '重复：' 开头，或表内归一化后同 URL 的多行
  同源子页（保留）—— 备注为 '与同表『X』同源' 的关联行/子页，绝不删除

URL 归一化（norm_url）：去协议 / 去 www / 去尾斜杠 / 去 query 与 fragment，
使 www.x.com/a 与 x.com/a?x=1 等判为同一 URL。归一化仅用于判重建议与 --delete
清单，不修改表内任何值。

删除是破坏性操作：--delete 前会打印将被删除的行，并等待输入 y 确认。
"""
import sys, io, argparse, openpyxl
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
from collections import Counter
from urllib.parse import urlparse


def norm_url(url):
    """URL 归一化用于判重：小写、去协议/www/尾斜杠/query/fragment。"""
    if not url:
        return ''
    u = url.strip().lower()
    if not u.startswith(('http://', 'https://')):
        return u  # 非 http(s) 不动，避免误伤
    p = urlparse(u)
    host = (p.hostname or '').lower()
    if host.startswith('www.'):
        host = host[4:]
    path = p.path or ''
    while path.endswith('/'):
        path = path[:-1]
    return f'{host}{path}'


def load(path):
    wb = openpyxl.load_workbook(path)
    ws = wb.active
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, 10)]
        if vals[1] is None:
            continue
        rows.append(vals)
    return wb, ws, rows


def del_able(rows):
    """真重复行：备注以『重复：』开头，或表内归一化后同 URL 的多行。"""
    norm_cnt = Counter(norm_url(str(r[2])) for r in rows if r[2])
    return [r for r in rows if str(r[6]).strip() == '是' and (
        str(r[7]).strip().startswith('重复：') or norm_cnt.get(norm_url(str(r[2])), 0) > 1)]


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('xlsx')
    ap.add_argument('--delete', action='store_true', help='删除真重复行（需 y 确认）')
    ap.add_argument('--suggest', action='store_true',
                    help='报告归一化后同 URL 但未标重复的候选组（不删）')
    args = ap.parse_args(argv)

    wb, ws, rows = load(args.xlsx)
    dup = [r for r in rows if str(r[6]).strip() == '是']
    if not dup:
        print(f'✅ {args.xlsx}: 无重复行')
    else:
        print(f'{args.xlsx}: {len(dup)} 条标记重复')
        for r in dup:
            print(f'  序号{r[0]} | {r[1]} | {r[2]} | {r[7]}')

    # --suggest: 归一化后同 URL 的组，标出其中未标记"是"的候选
    if args.suggest:
        groups = {}
        for r in rows:
            key = norm_url(str(r[2]))
            if not key:
                continue
            groups.setdefault(key, []).append(r)
        cand = [(k, v) for k, v in groups.items() if len(v) > 1]
        if not cand:
            print('（无归一化后重复的候选组）')
            return 0
        print(f'\n归一化后同 URL 的候选组 {len(cand)} 组（未标"是"的可考虑标重复）:')
        for k, v in cand:
            marked = sum(1 for r in v if str(r[6]).strip() == '是')
            print(f'  [{k}] {len(v)} 条，已标{marked}条:')
            for r in v:
                flag = '是' if str(r[6]).strip() == '是' else '否'
                print(f'    序号{r[0]} | {str(r[1])[:30]} | {r[2]} | 重复={flag} | {r[7]}')
        return 0

    if not args.delete:
        if dup:
            print('（未删除。确认后加 --delete 执行；仅删除"重复："或归一化同 URL 的真重复，同源子页会保留）')
        return 0

    deletable = del_able(rows)
    if not deletable:
        print('⚠️ 无可删除的真重复行（所有"是"行均为同源子页/关联行，--delete 不会删除它们）')
        return 0

    # 删除前最终确认（破坏性操作）
    print(f'\n将删除以下 {len(deletable)} 行真重复并重编号（其余 {len(dup) - len(deletable)} 条同源子页保留）:')
    for r in deletable:
        print(f'  序号{r[0]} | {r[1]} | {r[2]}')
    print(f'输入 y 确认: ', end='', flush=True)
    if input().strip().lower() != 'y':
        print('已取消，未做任何修改')
        return 1

    del_ids = {id(r) for r in deletable}
    keep = [r for r in rows if id(r) not in del_ids]
    wb2 = openpyxl.load_workbook(args.xlsx)
    ws2 = wb2.active
    # 清空现有数据区
    for r in range(2, ws2.max_row + 1):
        for c in range(1, 10):
            ws2.cell(r, c).value = None
    for i, row in enumerate(keep):
        rr = i + 2
        for c in range(1, 10):
            ws2.cell(rr, c).value = row[c - 1]
        ws2.cell(rr, 1).value = i + 1
    wb2.save(args.xlsx)
    print(f'已删除 {len(deletable)} 行真重复，保留 {len(keep)} 条')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
