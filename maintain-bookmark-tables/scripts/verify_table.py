#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签汇总表五指标验证。全 0 才算通过。

用法: python verify_table.py <xlsx路径> [<xlsx路径>...]
退出码: 0=全部通过, 1=存在残留

五指标:
  空值   —— 类别/网站类型/功能定位/备注 任一为空
  笼统   —— 网站类型仍是笼统值（在线工具/官网/GitHub/B站/国内平台 等）
  旧引用 —— 备注含 '序号'/'与同表「'，或含『』外的『同源+「』写法
  断档   —— 类别分组在行序上被切断（同类中间插入他类）
  悬空   —— 『与同表『X』』的 X 在同表名称列不存在（引用必须基于名称且精确匹配）
"""
import sys, io, re, openpyxl
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BAD_TYPES = ('Outlook邮箱', '免费邮箱', '教育邮箱', '临时邮箱', '在线工具', '学习教程',
             '国内平台', '国外平台', 'GitHub', 'B站')
REF_RE = re.compile(r'同表『([^』]+)』')


def audit(path):
    wb = openpyxl.load_workbook(path)
    ws = wb.active
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, 10)]
        if vals[1] is None:
            continue
        rows.append(vals)
    total = len(rows)
    empty = sum(1 for r in rows if not all(r[c] for c in (3, 4, 5, 7)))
    bad = sum(1 for r in rows if r[4] in BAD_TYPES)
    ref = sum(1 for r in rows if r[7] and (
        '序号' in str(r[7]) or '与同表「' in str(r[7])
        or ('『' not in str(r[7]) and '同源' in str(r[7]) and '「' in str(r[7]))))
    order = [r[3] for r in rows]
    seen, broken, cur = set(), 0, None
    for cat in order:
        if cat != cur:
            if cat in seen:
                broken += 1
            cur = cat
        seen.add(cat)
    names = {str(r[1]).strip() for r in rows}
    dangling = sum(1 for r in rows if r[7] and any(
        m.group(1).strip() and m.group(1).strip() not in names
        for m in REF_RE.finditer(str(r[7]))))
    return total, empty, bad, ref, broken, dangling


def main(argv):
    if not argv:
        print('用法: python verify_table.py <xlsx> [<xlsx>...]')
        return 2
    ok = True
    for path in argv:
        total, empty, bad, ref, broken, dangling = audit(path)
        flag = '✅' if (empty, bad, ref, broken, dangling) == (0, 0, 0, 0, 0) else '⚠️'
        if flag == '⚠️':
            ok = False
        print(f'{flag} {path}: 共{total} 空值{empty} 笼统{bad} 旧引用{ref} 断档{broken} 悬空{dangling}')
        if dangling:
            for seq, target in _dangling_rows(path):
                print(f'    序号{seq} -> 『{target}』')
    return 0 if ok else 1


def _dangling_rows(path):
    """返回 (序号, 悬空目标名) 列表，供定位修复。"""
    wb = openpyxl.load_workbook(path)
    ws = wb.active
    rows = []
    for r in range(2, ws.max_row + 1):
        vals = [ws.cell(r, c).value for c in range(1, 10)]
        if vals[1] is None:
            continue
        rows.append(vals)
    names = {str(r[1]).strip() for r in rows}
    out = []
    for r in rows:
        if not r[7]:
            continue
        for m in REF_RE.finditer(str(r[7])):
            target = m.group(1).strip()
            if target and target not in names:
                out.append((r[0], target))
    return out


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
