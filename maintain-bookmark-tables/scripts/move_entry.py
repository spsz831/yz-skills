#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签移表：把一条书签从 A 表移到 B 表（按 URL 定位，双表重编号）。

用法:
  python move_entry.py --from src.xlsx --url <url> --to dst.xlsx [--from-sheet 名] [--to-sheet 名]
                       [--cat 新类别] [--before "名称"] [--after "名称"] [--dry-run]

定位:
  --url        源表定位用，精确匹配（忽略末尾斜杠）
  --before/--after  目标表插入位置，按名称锚点（不依赖序号，幂等）
默认插入: 目标表同类别最后一行之后；目标表无该类别则追加到表尾

同文件跨 sheet 移动（如 AI 文件内移子表）直接传同一 --from/--to + 两个 sheet 名。
写回后样式会简化，建议跑 style_table.py 恢复美化。
"""
import sys, io, argparse, openpyxl
if getattr(sys.stdout, 'encoding', '').lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
try:
    from config import COLUMN_COUNT, COLUMNS
except ImportError:
    COLUMN_COUNT = 9
    COLUMNS = {'序号': 0, '名称': 1, 'URL': 2, '类别': 3, '网站类型': 4,
               '功能定位': 5, '是否重复': 6, '备注': 7, '添加日期': 8}

I_NAME = COLUMNS.get('名称', 1)
I_URL = COLUMNS.get('URL', 2)
I_CAT = COLUMNS.get('类别', 3)


def norm_url(u):
    return str(u).strip().rstrip('/') if u else ''


def load_rows(ws):
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, COLUMN_COUNT + 1)]
        if any(v is not None for v in vals):
            rows.append(vals)
    return rows


def write_rows(ws, rows):
    """清空第2行起的旧数据区，重写数据。表头保留。"""
    if ws.max_row >= 2:
        ws.delete_rows(2, ws.max_row)
    for i, vals in enumerate(rows, start=2):
        for c, v in enumerate(vals, start=1):
            ws.cell(i, c).value = v


def renumber(rows):
    seq_i = COLUMNS.get('序号', 0)
    for i, vals in enumerate(rows, start=1):
        vals[seq_i] = i


def find_row_by_url(rows, url):
    target = norm_url(url)
    for i, vals in enumerate(rows):
        if norm_url(vals[I_URL]) == target:
            return i
    return None


def find_name_row(rows, name):
    for i, vals in enumerate(rows):
        if vals[I_NAME] and str(vals[I_NAME]).strip() == str(name).strip():
            return i
    return None


def insert_pos(rows, cat, before, after):
    """返回应插入的 list 下标。优先级: --before > --after > 同类别末尾 > 表尾。"""
    if before:
        idx = find_name_row(rows, before)
        if idx is not None:
            return idx
    if after:
        idx = find_name_row(rows, after)
        if idx is not None:
            return idx + 1
    last_same = -1
    for i, vals in enumerate(rows):
        if vals[I_CAT] and cat and str(vals[I_CAT]).strip() == str(cat).strip():
            last_same = i
    return last_same + 1


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--from', dest='src', required=True)
    ap.add_argument('--url', required=True)
    ap.add_argument('--to', dest='dst', required=True)
    ap.add_argument('--from-sheet', default=None)
    ap.add_argument('--to-sheet', default=None)
    ap.add_argument('--cat', default=None)
    ap.add_argument('--before', default=None)
    ap.add_argument('--after', default=None)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args(argv)

    same_file = args.src == args.dst
    if same_file:
        wb = openpyxl.load_workbook(args.src)
        ws_src = wb[args.from_sheet] if args.from_sheet else wb.active
        ws_dst = wb[args.to_sheet] if args.to_sheet else wb.active
        if ws_src.title == ws_dst.title:
            print('✗ 源与目标 sheet 相同，无需移动')
            return 1
    else:
        wb_src = openpyxl.load_workbook(args.src)
        wb_dst = openpyxl.load_workbook(args.dst)
        ws_src = wb_src[args.from_sheet] if args.from_sheet else wb_src.active
        ws_dst = wb_dst[args.to_sheet] if args.to_sheet else wb_dst.active

    src_rows = load_rows(ws_src)
    dst_rows = load_rows(ws_dst)

    idx = find_row_by_url(src_rows, args.url)
    if idx is None:
        print(f'✗ 源表 {args.src}[{ws_src.title}] 中未找到 URL: {args.url}')
        return 1

    moved = src_rows.pop(idx)
    cat = args.cat or moved[I_CAT]
    pos = insert_pos(dst_rows, cat, args.before, args.after)
    dst_rows.insert(pos, moved)

    print(f'移动: {moved[I_NAME]}（{moved[I_URL]}）')
    print(f'  源表 {args.src}[{ws_src.title}] 原第{idx+2}行 移除')
    print(f'  目标表 {args.dst}[{ws_dst.title}] 插入第{pos+2}行（类别:{cat}）')

    if args.dry_run:
        print('--dry-run：未写入文件')
        return 0

    renumber(src_rows)
    renumber(dst_rows)
    write_rows(ws_src, src_rows)
    write_rows(ws_dst, dst_rows)
    if same_file:
        wb.save(args.src)
    else:
        wb_src.save(args.src)
        wb_dst.save(args.dst)
    print('✅ 已移动并双表重编号。建议运行 style_table.py 恢复美化样式。')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
