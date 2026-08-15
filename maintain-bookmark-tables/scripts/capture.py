#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""零摩擦捕获：给一个 URL，自动出"进哪张表 + 名称 + 类别/类型 + 全库查重"清单。

用法:
  python capture.py https://example.com                # 只出清单（推荐先看）
  python capture.py https://example.com --online       # 联网抓 <title> 做名称
  python capture.py https://a.com --add --yes          # 直接写表（自动查重+备份+重编号）
  python capture.py https://a.com --add --table XX书签汇总.xlsx --cat 类别

工作流:
  URL → 抓 title(可选) → InferEngine 推断类别/类型 + 建议表 → 全库查重
  → 确认后调 entry.add_cmd() 写表（与日常新增完全一致的查重/备份/重编号）

设计: 复用 InferEngine / entry.find_dup_elsewhere / entry.add_cmd，不重复实现写表逻辑。
"""
import sys, io, os, argparse

if getattr(sys.stdout, 'encoding', '').lower() != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
try:
    from config import FALLBACK_TYPE
except ImportError:
    FALLBACK_TYPE = '官网·工具'


def domain_placeholder(url):
    """URL → 域名作名称占位。失败返回 '未命名书签'。"""
    try:
        return url.split('//', 1)[1].split('/', 1)[0]
    except Exception:
        return '未命名书签'


def capture(url, *, dirpath='.', online=False):
    """抓 title + 推断 + 建议表 + 全库查重。

    返回 dict: {url, title, type, cat, source, table, table_n, dup_hits}
    title 抓取失败用域名占位并标 `[无title]`（不阻塞捕获流程）。
    """
    from infer_from_url import InferEngine
    from entry import find_dup_elsewhere

    eng = InferEngine(dirpath, online=online)
    typ, cat, src = eng.infer(url)
    table, table_n = eng.suggest_table(url)

    title = ''
    if online:
        try:
            title = (InferEngine._fetch_title(url) or '').strip()
        except Exception:
            title = ''
    if not title:
        title = domain_placeholder(url)
        title_flag = ' [无title]'
    else:
        title_flag = ''

    # 全库查重：exclude 传不存在路径 → 返回所有命中
    dup_hits = find_dup_elsewhere(dirpath, url, '\0none')

    return {
        'url': url,
        'title': title + title_flag,
        'type': typ, 'cat': cat, 'source': src,
        'table': table, 'table_n': table_n,
        'dup_hits': dup_hits,
    }


def confirm_and_add(info, args):
    """把捕获结果交给 entry.add_cmd 写表。返回其退出码。"""
    from argparse import Namespace
    from entry import add_cmd

    table = args.table or info['table']
    if not table:
        print('✗ 无法确定目标表（建议表未知且未指定 --table）')
        return 2
    if not os.path.exists(table):
        print(f'✗ 目标表不存在: {table}')
        return 1

    ns = Namespace(
        name=info['title'], url=info['url'], table=table,
        cat=args.cat or info['cat'], type=args.type or info['type'],
        desc=args.desc, sheet=args.sheet,
        infer=False, force=args.force,
        before=None, after=None, no_backup=args.no_backup,
        dir=args.dir,
    )
    return add_cmd(ns)


def _selftest():
    ok = True
    # 名称占位
    ok &= domain_placeholder('https://example.com/a/b') == 'example.com'
    ok &= domain_placeholder('not-a-url') == '未命名书签'
    # 捕获：离线内置规则（github.com 精确命中，不联网）
    info = capture('https://github.com/anthropics/claude-code', dirpath='.')
    ok &= info['title'].endswith('[无title]')
    ok &= info['type'] == 'GitHub·工具仓库'
    ok &= info['cat'] == '开源工具'
    ok &= info['dup_hits'] == []  # 当前目录无书签表
    # capture 对坏 URL 不崩
    info2 = capture('https://example.com/x', dirpath='.')
    ok &= info2['title'].startswith('example.com')
    print(f'selftest: {"通过" if ok else "失败"}')
    return 0 if ok else 1


def main(argv):
    ap = argparse.ArgumentParser(description='书签零摩擦捕获（URL → 建议清单 → 一键入库）')
    ap.add_argument('url', nargs='?', help='要捕获的书签 URL')
    ap.add_argument('--dir', default='.', help='书签库目录（推断学习 + 全库查重）')
    ap.add_argument('--online', action='store_true', help='联网抓 <title> 作名称（默认域名占位）')
    ap.add_argument('--add', action='store_true', help='确认后写表（默认只出清单）')
    ap.add_argument('--yes', action='store_true', help='跳过交互确认直接写表')
    ap.add_argument('--table', default=None, help='指定目标表（默认用建议表）')
    ap.add_argument('--cat', default=None, help='覆盖类别')
    ap.add_argument('--type', dest='type', default=None, help='覆盖网站类型')
    ap.add_argument('--desc', default=None, help='功能定位')
    ap.add_argument('--sheet', default=None, help='目标 sheet（多 sheet 文件用）')
    ap.add_argument('--force', action='store_true', help='同 URL 已收录也强制插入')
    ap.add_argument('--no-backup', action='store_true', help='写前不备份')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args(argv)

    if args.selftest:
        return _selftest()
    if not args.url:
        ap.error('URL 必填')
        return 2

    info = capture(args.url, dirpath=args.dir, online=args.online)

    print(f'URL:    {info["url"]}')
    print(f'名称:   {info["title"]}')
    print(f'类型:   {info["type"] or "（未推断出）"}  ← {info["source"]}')
    print(f'类别:   {info["cat"] or "（未推断出）"}')
    if info['table']:
        print(f'建议表: {os.path.basename(info["table"])}（依据 {info["table_n"]} 条历史）')
    else:
        print(f'建议表: （库中没见过该域名，需 --table 指定）')
    if info['dup_hits']:
        print(f'⚠️ 全库查重命中 {len(info["dup_hits"])} 处（已收录则需 --force 才可重复入库）:')
        for p, s, r, n in info['dup_hits']:
            print(f'  {os.path.basename(p)}[{s}] 第{r}行  {n or ""}')

    if not args.add:
        print('\n（预览模式，未写表。加 --add 入库，--yes 跳过确认）')
        return 0

    if not args.yes and info['dup_hits']:
        print('\n⚠️ 命中重复，确认仍要写？')
        ans = input('输入 y 继续: ').strip().lower()
        if ans != 'y':
            print('已取消')
            return 0
    elif not args.yes:
        ans = input(f'写入 {os.path.basename(info["table"] or "?").replace(".xlsx","")}? [y/N] ').strip().lower()
        if ans != 'y':
            print('已取消')
            return 0

    return confirm_and_add(info, args)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
