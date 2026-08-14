#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""书签 URL 自动推断：给 URL / 表批量生成 网站类型 + 类别 建议。

用法:
  python infer_from_url.py <url> [...]                  # 给单个/多个 URL 出建议
  python infer_from_url.py <xlsx> --enrich [--changed]  # 给表里所有行出建议清单（不改表）
  python infer_from_url.py --selftest                   # 内置自检（不依赖库目录）

推断优先级:
  1. 内置知名平台规则（网站类型值全部取自库中已有词汇，不造新词）
  2. 从现有库学习: 域名 -> 网站类型/类别 多数派（--dir 指向书签目录，默认当前目录）
  3. 兜底: 官网·工具（库中最高频）+ 类别建议留空

说明: 推断是"建议"，最终类别/类型由人工或 LLM 确认；改表请走正常新增/编辑流程。
"""
import sys, io, os, re, glob
import argparse
from collections import Counter, defaultdict
from urllib.parse import urlparse

# 注意: stdout 包装放在 main() 里执行，被其他脚本 import（如 import_html）时不重复包装

# (后缀, 网站类型, 类别) —— 后缀带 '.' 表示子域名也匹配；类型值均来自库中已有词汇
# 顺序越靠前优先级越高；精确域名优先于后缀，后缀按长度优先
BUILTIN_RULES = [
    # GitHub 系列
    ('gist.github.com', 'GitHub·Gist', '代码分享'),
    ('.github.io', 'GitHub·个人主页', '个人站点'),
    ('github.com', 'GitHub·工具仓库', '开源工具'),
    # 飞书 / 谷歌 / 微信 / 小红书 等平台
    ('.feishu.cn', '飞书·云文档', '学习教程'),
    ('.larkoffice.com', '飞书·云文档', '学习教程'),
    ('docs.google.com', 'Google文档', '教程文档'),
    ('chromewebstore.google.com', 'Chrome·插件', '浏览器插件'),
    ('mp.weixin.qq.com', '微信·文章', '社区资讯'),
    ('creator.xiaohongshu.com', '平台·创作后台', '自媒体'),
    ('x.com', 'X·推文', '社交媒体'),
    ('twitter.com', 'X·推文', '社交媒体'),
    # 技能 / MCP 生态
    ('skills.sh', '官网·技能市场', 'Skill'),
    ('lobehub.com', '官网·平台', 'Skill市场'),
    ('clawhub.ai', 'ClawHub·技能平台', 'Skill'),
    ('modelscope.cn', 'ModelScope·模型库', '模型平台'),
    ('huggingface.co', 'HuggingFace·模型页', '模型仓库'),
    # 论坛社区
    ('linux.do', '社区·论坛', '论坛社区'),
    ('cdk.linux.do', '官网·CDK页', '论坛社区'),
    # 文档 / 笔记
    ('notion.so', 'Notion·官方', '文档笔记'),
    ('yuque.com', '语雀·文档', '内容平台'),
    # 教程视频
    ('bilibili.com', '教程·B站视频', '教程文档'),
    ('youtube.com', '油管·视频教程', '学习教程'),
    ('zhuanlan.zhihu.com', '知乎·专栏', '学习教程'),
    ('zhihu.com', '知乎·专栏', '学习教程'),
    ('blog.csdn.net', 'CSDN·博客', '教程博客'),
    ('csdn.net', 'CSDN·博客', '教程博客'),
    # 云 / CDN / 部署
    ('dash.cloudflare.com', 'CDN·Cloudflare', 'CDN/DNS'),
    ('cloudflare.com', 'CDN·Cloudflare', 'CDN/DNS'),
    ('railway.com', '部署平台·PaaS', '部署平台'),
    ('vercel.app', '部署平台·静态托管', '部署平台'),
    ('netlify.app', '部署平台·静态托管', '部署平台'),
    # 本地
    ('localhost', '本地·工具', '本地开发'),
    ('127.0.0.1', '本地·工具', '本地开发'),
    # 主流平台兜底
    ('openai.com', '官网·平台', 'AI聊天'),
    ('chatgpt.com', '官网·平台', 'AI聊天'),
    ('anthropic.com', '官网·平台', 'AI聊天'),
    ('google.com', '官网·搜索', '搜索工具'),
    ('kaggle.com', 'Kaggle·教程', '学习教程'),
    ('producthunt.com', 'ProductHunt·产品页', '社区平台'),
    ('substack.com', 'Substack·博客', '个人博客'),
    ('patreon.com', '官网·社区', '创作者'),
    ('telegram.org', '官网·社区', '社区平台'),
    ('discord.com', '官网·社区', '社区平台'),
    ('notion.com', '官网·文档', '文档笔记'),
    ('cloud.aliyun.com', '阿里·控制台', '官方平台'),
    ('console.aliyun.com', '阿里·控制台', '官方平台'),
    ('volcengine.com', '官网·活动页', '官方平台'),
    ('weibo.com', '官网·社区', '社交媒体'),
    ('douban.com', '豆瓣·小组', '社区平台'),
]

FALLBACK_TYPE = '官网·工具'  # 库中最高频网站类型


def normalize_host(url):
    """URL -> 小写去 www 的 host；解析失败返回 ''。"""
    try:
        host = (urlparse(url.strip()).hostname or '').lower()
        if host.startswith('www.'):
            host = host[4:]
        return host
    except Exception:
        return ''


class InferEngine:
    """内置规则 + 库学习 的推断器。"""

    def __init__(self, directory='.'):
        # 内置规则: 精确域名 / 后缀 -> (类型, 类别)，后缀按长度降序
        self.exact = {}     # host -> (type, cat)
        self.suffix = []    # [(suffix, type, cat)] 后缀以 '.' 开头
        for suffix, typ, cat in BUILTIN_RULES:
            if suffix.startswith('.'):
                self.suffix.append((suffix, typ, cat))
            else:
                self.exact[suffix] = (typ, cat)
        self.suffix.sort(key=lambda x: -len(x[0]))
        # 库学习: domain -> (类型Counter, 类别Counter)
        self.learn = defaultdict(lambda: (Counter(), Counter()))
        self.load_library(directory)

    def load_library(self, directory):
        """扫描目录所有 *书签汇总.xlsx，学习 域名 -> 类型/类别 多数派。"""
        try:
            import openpyxl
        except ImportError:
            return
        files = sorted(p for p in glob.glob(os.path.join(directory, '*书签汇总.xlsx'))
                       if not os.path.basename(p).startswith('~$'))
        for f in files:
            try:
                wb = openpyxl.load_workbook(f, read_only=True)
                ws = wb.active
                for r in range(2, ws.max_row + 1):
                    url = ws.cell(r, 3).value
                    typ = ws.cell(r, 5).value
                    cat = ws.cell(r, 4).value
                    host = normalize_host(str(url)) if url else ''
                    if not host:
                        continue
                    if typ:
                        self.learn[host][0][str(typ).strip()] += 1
                    if cat:
                        self.learn[host][1][str(cat).strip()] += 1
                wb.close()
            except Exception:
                continue
        self.learn_loaded = bool(files)

    def _learned(self, host):
        """返回 (类型, 类别) 或 None —— 学习多数派，支持子域名最长后缀。"""
        if not self.learn:
            return None
        keys = [host] + [s for s in self.learn if s.startswith('.') and host.endswith(s)]
        keys = sorted(keys, key=len, reverse=True)
        for k in keys:
            if k not in self.learn:
                continue
            tc, cc = self.learn[k]
            if tc:
                typ = tc.most_common(1)[0][0]
                cat = cc.most_common(1)[0][0] if cc else ''
                return (typ, cat)
        return None

    def infer(self, url):
        """返回 (网站类型建议, 类别建议, 来源)。来源 ∈ 内置/库学习×N/兜底。"""
        host = normalize_host(url)
        if not host:
            return (FALLBACK_TYPE, '', '无法解析')
        # 1. 内置规则：先精确，再祖先域名（chat.openai.com -> openai.com），最后后缀
        if host in self.exact:
            typ, cat = self.exact[host]
            return (typ, cat, '内置')
        parts = host.split('.')
        for i in range(1, len(parts)):
            anc = '.'.join(parts[i:])
            if anc in self.exact:
                typ, cat = self.exact[anc]
                return (typ, cat, '内置')
        for suffix, typ, cat in self.suffix:
            if host.endswith(suffix):
                return (typ, cat, '内置')
        # 2. 库学习
        learned = self._learned(host)
        if learned:
            typ, cat = learned
            return (typ, cat, '库学习')
        # 3. 兜底
        return (FALLBACK_TYPE, '', '兜底')


def main(argv):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    ap = argparse.ArgumentParser(description='书签 URL 自动推断 网站类型/类别')
    ap.add_argument('inputs', nargs='*', help='URL 或 xlsx 表路径')
    ap.add_argument('--enrich', action='store_true', help='表模式: 给表每行生成建议清单（不改表）')
    ap.add_argument('--changed', action='store_true', help='表模式: 只显示建议与当前不同的行')
    ap.add_argument('--dir', default='.', help='书签库目录（学习用），默认当前目录')
    ap.add_argument('--selftest', action='store_true', help='内置自检')
    args = ap.parse_args(argv)

    engine = InferEngine(args.dir)

    if args.selftest:
        cases = [
            ('https://github.com/foo/bar', 'GitHub·工具仓库'),
            ('https://skills.sh/xxx', '官网·技能市场'),
            ('https://linux.do/t/123', '社区·论坛'),
            ('https://a.feishu.cn/doc/1', '飞书·云文档'),
            ('https://www.x.com/user', 'X·推文'),
            ('https://blog.csdn.net/foo', 'CSDN·博客'),
            ('http://127.0.0.1:8080', '本地·工具'),
            ('https://chat.openai.com/', '官网·平台'),
            ('https://gist.github.com/u/1', 'GitHub·Gist'),
        ]
        failed = 0
        for url, expect in cases:
            typ, cat, src = engine.infer(url)
            ok = typ == expect
            failed += 0 if ok else 1
            print(f"{'✅' if ok else '❌'} {url} -> {typ}（{src}） 期望 {expect}")
        print(f'selftest: {"通过" if failed == 0 else f"{failed} 处失败"}')
        return 0 if failed == 0 else 1

    if not args.inputs:
        print('用法: python infer_from_url.py <url> [<url>...] 或 <xlsx> --enrich')
        return 2

    # 表模式
    if args.enrich:
        import openpyxl
        for path in args.inputs:
            wb = openpyxl.load_workbook(path, read_only=True)
            ws = wb.active
            print(f'\n== {os.path.basename(path)} ==')
            print(f'{"序号":<4}{"名称":<40}{"URL":<45}{"类型":<16}{"类别":<12}来源')
            for r in range(2, ws.max_row + 1):
                name = ws.cell(r, 2).value
                if name is None:
                    continue
                url = str(ws.cell(r, 3).value or '').strip()
                cur_t, cur_c = ws.cell(r, 5).value, ws.cell(r, 4).value
                sug_t, sug_c, src = engine.infer(url)
                if args.changed and sug_t == str(cur_t).strip() and sug_c == str(cur_c).strip():
                    continue
                print(f'{str(ws.cell(r,1).value):<4}{str(name)[:38]:<40}{url[:43]:<45}{sug_t:<16}{sug_c:<12}{src}')
            wb.close()
        return 0

    # URL 模式
    for url in args.inputs:
        typ, cat, src = engine.infer(url)
        print(f'{url}\n  网站类型: {typ}\n  类别: {cat or "（待定）"}\n  来源: {src}\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
