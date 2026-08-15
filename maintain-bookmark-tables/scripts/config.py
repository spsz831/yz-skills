#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""maintain-bookmark-tables 集中配置（公开版默认值）。

所有脚本从本文件读取硬编码默认值，开箱即用作者的书签表结构。
其他人适配自己的表：改本文件对应项即可，无需改任何脚本。

依赖: 仅 openpyxl（零第三方依赖）。配置即 Python 模块，不引 yaml/toml。
本文件带完整注释，同时充当"如何自定义"的说明文档。
"""
import re

# ==========================================================================
# 一、表命名与结构
# ==========================================================================

# 书签表文件匹配规则（glob 模式，供全库扫描类脚本使用）
TABLE_GLOB = '*书签汇总.xlsx'

# 索引表标识：文件名包含任一关键字即视为索引表（4 列结构，verify 自动跳过）
INDEX_MARKERS = ('书签整理最终清单',)

# 9 列表头：顺序即默认列号 1..N。别人改列数/列名时改这里，
# 其余列语义映射（COLUMNS）会自动跟随。
COLUMN_HEADERS = [
    '序号', '名称', 'URL', '类别', '网站类型', '功能定位', '是否重复', '备注', '添加日期',
]
COLUMN_COUNT = len(COLUMN_HEADERS)

# 列语义 -> 0-based 索引。脚本按语义取值（如 cols['url']），不写死列号。
# 若改表头，这里对应关系自动按名称匹配，无需手动改。
COLUMNS = {h: i for i, h in enumerate(COLUMN_HEADERS)}


# ==========================================================================
# 二、验证指标相关
# ==========================================================================

# 网站类型"笼统值"清单：verify 报告笼统指标。用户可按自己的分类体系增删。
BAD_TYPES = ('Outlook邮箱', '免费邮箱', '教育邮箱', '临时邮箱', '在线工具', '学习教程',
             '国内平台', '国外平台', 'GitHub', 'B站')

# 备注里"同源引用"的语法（REF_RE 解析被引用名称）。
# 默认 `与同表『X』同源`，『』内为被引用名称，须与目标行名称列精确一致。
REF_RE = re.compile(r'同表『([^』]+)』')

# 备注里"跨表引用"语法：`同源已收录于XX.xlsx`。解析目标文件名。
CROSS_RE = re.compile(r'收录于([^；;。]+\.xlsx)')

# "是否重复"列的标记值（标"是"表示与其他表重复或同源子页）
DUP_MARK = '是'

# 备注里"真重复"前缀：dedup --delete 只删以此为前缀或表内归一化同 URL 的行
DUP_PREFIX = '重复：'

# 类别名里的"失效链接"标记：report_summary 据此归类疑似死链
DEAD_CATEGORY = '失效链接'


# ==========================================================================
# 三、样式（style_table.py / style_index.py）
# ==========================================================================

STYLE = {
    # 字体
    'font_name': '微软雅黑',
    'header_size': 11,
    'body_size': 10.5,
    # 颜色（十六进制无 #）
    'header_fill': '3867A6',     # 表头深蓝
    'accent_fill': 'EEF4FB',     # 数据行斑马纹浅蓝
    'total_fill': 'FFF2CC',      # 索引表合计行浅黄
    'url_color': '2563EB',       # URL 蓝字
    'border_color': '999999',    # 边框深灰（WPS 中清晰可见）
    # 行高
    'header_row_height': 26,
    'body_row_height': 22,
    # 列宽（与 COLUMN_HEADERS 顺序对应）
    'col_widths': [5, 38, 50, 14, 14, 32, 10, 30, 12],
    # 对齐：哪些列居中 / 哪些列左对齐+换行（0-based 语义名）
    'center_cols': ('序号', '类别', '网站类型', '是否重复', '添加日期'),
    'left_cols': ('名称', 'URL', '功能定位', '备注'),
}


# ==========================================================================
# 四、URL 推断（infer_from_url.py）
# ==========================================================================

# 兜底网站类型（库中最高频值）
FALLBACK_TYPE = '官网·工具'

# 内置知名平台规则：(后缀, 网站类型, 类别)。
# 后缀带 '.' 表示子域名也匹配；顺序越靠前优先级越高。
# 类型/类别值尽量取自库中已有词汇，不造新词。用户可按自己库增删。
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

# 并发 / 网络（check_urls.py）
HTTP_TIMEOUT = 8
HTTP_WORKERS = 8
HTTP_UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
           '(KHTML, like Gecko) Chrome/126.0 Safari/537.36')


# ==========================================================================
# 六、AI 补全 / 审计（ai_enrich.py / ai_audit.py）
# ==========================================================================

# LLM API 配置。注意：**API key 不在此文件**，运行时从环境变量 AI_API_KEY 读取，
# 防止 key 落进公开仓库。endpoint 留空则用 Anthropic 官方端点。
AI_ENRICH = {
    'endpoint': 'https://api.anthropic.com/v1/messages',  # Anthropic Messages API
    'model': 'claude-sonnet-5',      # 贴合 Claude 生态；OpenAI 系用户可改
    'max_tokens': 300,
    'temperature': 0.0,              # 0 = 确定性输出（补全/审计更可靠）
    'timeout': 15,
    'retries': 2,                    # 网络失败重试次数
}

# ai_enrich 批量并发（LLM 建议串行更稳，默认 3）
AI_ENRICH_WORKERS = 3


# ==========================================================================
# 五、多 sheet 文件
# ==========================================================================

# 哪些书签表文件是多 sheet 合并文件（每个 sheet 独立 9 列结构）。
# 默认自动探测：文件含 ≥2 个非空 sheet 即视为多 sheet。
# 若某个单 sheet 文件被误判，可在此显式排除。留空=全部自动探测。
MULTI_SHEET_EXCLUDE = ()


def sheet_count(path):
    """返回文件的 sheet 数；读失败返回 1（视为单 sheet）。"""
    try:
        import openpyxl
        wb = openpyxl.load_workbook(path, read_only=True)
        n = len(wb.sheetnames)
        wb.close()
        return n
    except Exception:
        return 1


def is_multi_sheet(path):
    """多 sheet 判定：≥2 sheet 且不在排除列表。"""
    name = path.replace('\\', '/').rsplit('/', 1)[-1]
    if name in MULTI_SHEET_EXCLUDE:
        return False
    return sheet_count(path) >= 2


def is_index(path):
    """索引表判定：文件名含 INDEX_MARKERS 任一关键字。"""
    name = path.replace('\\', '/').rsplit('/', 1)[-1]
    return any(m in name for m in INDEX_MARKERS)
