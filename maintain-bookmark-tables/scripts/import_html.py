#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""解析浏览器导出的书签 HTML（Netscape Bookmark 格式），生成待入库清单。

用法:
  python import_html.py <bookmarks.html>                     # 解析并列出全部书签
  python import_html.py <bookmarks.html> --infer [--dir 库目录] # 附 网站类型/类别 建议

支持 Chrome / Edge / Firefox 导出（<!DOCTYPE NETSCAPE-Bookmark-file-1>）。
只读解析，不写任何表；输出为 Markdown 清单，由人工/LLM 确认后再走新增流程。

--dir 传给 infer_from_url.py 的学习引擎，默认当前目录。
"""
import sys, io, os, glob, argparse
from html.parser import HTMLParser
from urllib.parse import urlparse

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


class BookmarkParser(HTMLParser):
    """解析 Netscape bookmark HTML，收集 (文件夹路径, 名称, URL)。"""

    def __init__(self):
        super().__init__()
        self.stack = []        # [(dl深度, 文件夹名)]
        self.depth = 0
        self.in_folder = False
        self.folder_buf = []
        self.in_link = False
        self.link_href = ''
        self.link_buf = []
        self.bookmarks = []    # [(path_list, name, url)]

    def handle_starttag(self, tag, attrs):
        if tag == 'dl':
            self.depth += 1
        elif tag == 'h3':
            self.in_folder = True
            self.folder_buf = []
        elif tag == 'a':
            self.in_link = True
            self.link_href = dict(attrs).get('href', '')
            self.link_buf = []

    def handle_data(self, data):
        if self.in_folder:
            self.folder_buf.append(data)
        elif self.in_link:
            self.link_buf.append(data)

    def handle_endtag(self, tag):
        if tag == 'h3':
            name = ''.join(self.folder_buf).strip()
            if name:
                self.stack.append((self.depth, name))
            self.in_folder = False
        elif tag == 'a':
            name = ''.join(self.link_buf).strip()
            href = self.link_href.strip()
            if href:
                self.bookmarks.append(([n for _, n in self.stack], name, href))
            self.in_link = False
        elif tag == 'dl':
            self.depth -= 1
            while self.stack and self.stack[-1][0] > self.depth:
                self.stack.pop()


def main(argv):
    ap = argparse.ArgumentParser(description='解析浏览器书签 HTML 生成待入库清单')
    ap.add_argument('html', nargs='?', default=None, help='浏览器导出的 bookmarks.html 路径')
    ap.add_argument('--infer', action='store_true', help='附 网站类型/类别 建议（复用 infer_from_url）')
    ap.add_argument('--dir', default='.', help='书签库目录（infer 学习用）')
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args(argv)

    if args.selftest:
        sample = """<!DOCTYPE NETSCAPE-Bookmark-file-1>
<TITLE>Bookmarks</TITLE><H1>Bookmarks</H1><DL><p>
<DT><H3>AI</H3><DL><p>
<DT><A HREF="https://github.com/a/b">Repo A</A>
<DT><H3>图片</H3><DL><p>
<DT><A HREF="https://ai.feishu.cn/doc/x">飞书文档</A>
</DL><p></DL><p>
</DL><p>"""
        p = BookmarkParser()
        p.feed(sample)
        want = [(['AI'], 'Repo A', 'https://github.com/a/b'),
                (['AI', '图片'], '飞书文档', 'https://ai.feishu.cn/doc/x')]
        got = [(path, name, url) for path, name, url in p.bookmarks]
        ok = got == want
        for path, name, url in got:
            print(f"{' / '.join(path)} > {name} — {url}")
        print(f'selftest: {"通过" if ok else "失败"}')
        return 0 if ok else 1

    if not args.html:
        print('用法: python import_html.py <bookmarks.html> [--infer [--dir 库目录]]')
        return 2
    with open(args.html, encoding='utf-8', errors='replace') as fh:
        content = fh.read()
    p = BookmarkParser()
    p.feed(content)

    if not p.bookmarks:
        print(f'⚠️ 未解析到书签（{args.html}）。确认是 Netscape bookmark 格式（<DT><A HREF=...>）。')
        return 1

    infer = None
    if args.infer:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from infer_from_url import InferEngine
        infer = InferEngine(args.dir)

    print(f'共解析 {len(p.bookmarks)} 条书签（按文件夹分组）\n')
    # 按文件夹路径分组，保持原始顺序
    groups = []
    idx = {}
    for path, name, url in p.bookmarks:
        key = ' / '.join(path) or '（未分类）'
        if key not in idx:
            idx[key] = len(groups)
            groups.append([key, []])
        groups[idx[key]][1].append((name, url))
    for key, items in groups:
        print(f'## {key}（{len(items)} 条）')
        for name, url in items:
            if infer:
                typ, cat, src = infer.infer(url)
                extra = f'  —— 建议: {typ}' + (f' / {cat}' if cat else '')
            else:
                extra = ''
            title = name if name else url
            print(f'- {title} | {url}{extra}')
        print()

    # 统计提示：哪些路径在现有库里可能找不到对应表
    tables = {os.path.splitext(os.path.basename(f))[0].replace('书签汇总', '')
              for f in glob.glob(os.path.join(args.dir, '*书签汇总.xlsx'))}
    print('提示: 可参照现有表', ' / '.join(sorted(tables)) or '（当前目录未找到表）')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
