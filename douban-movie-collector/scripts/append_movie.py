# -*- coding: utf-8 -*-
"""
append_movie.py — 向电影收藏表 xlsx 追加影片行
用法：
  python append_movie.py --xlsx <表格路径> --json '<JSON数组>' [--force]
JSON 数组元素字段（除 name 外均可选）：
  name 必填；link 网盘链接；code 提取码；country 国家地区；year 年份；
  genre 类型；director 导演；rating 豆瓣评分；status 观看状态(默认"想看")；
  date 收藏日期(默认今天)；remark 备注
行为：
  1. 按表头名定位列，序号自动顺延
  2. 电影名查重（完全匹配），重复则跳过；--force 允许重复写入
  3. 样式从上一数据行整行复制，日期列写 datetime 并强制 yyyy-mm-dd 格式
  4. 保存时若文件被占用，改存 <原名>_new.xlsx 并在输出中标记 LOCKED
输出：JSON 摘要（写入行号 / 跳过的重复项 / 保存状态）
"""
import sys, json, argparse, shutil, copy, re
from datetime import datetime, date
from pathlib import Path
from openpyxl import load_workbook


def norm(s):
    """归一化电影名用于查重：去空白、全半角统一、去书名号"""
    if s is None:
        return ""
    s = str(s).strip().replace("《", "").replace("》", "")
    return re.sub(r"\s+", "", s).lower()


def strip_source_tags(text):
    """剥离备注中的片源/画质/字幕描述，保留剧情简介本身。

    常见的冗余片源词：分辨率（1080P/4K/720P）、压制品类（WEB-DL/BDRip/蓝光原盘）、
    字幕/语言（中字/国语/英语/泰语/多字幕）、"资源"字样。
    清洗后若为空字符串则返回 None，让列留空而非填空白。
    """
    if text is None or not str(text).strip():
        return None
    s = str(text).strip()

    # 定义所有需要剥离的片源标签（按长度从长到短，避免部分匹配）
    tags_to_remove = [
        # 分辨率
        '1080Pi', '1080PK', '1080P', '1080p', '720P', '4K', '4k', '480P', '2160P',
        # 压制格式
        '蓝光原盘', 'BDRip', 'bdstrip', 'BD Rip', 'WEB-DL', 'web-dl', 'WEB DL', 'WEBRip', 'webr-rip',
        'HDRip', 'HDTV', 'hdtv', 'CAM', 'TS', 'TC', 'DVDRip', 'dvdrip', 'remux',
        # 字幕/语言
        '中字', '国语', '英语', '泰语', '日语', '韩语', '中文', '日文', '韩文',
        '多字幕', '多国字幕', '原声', '中英字幕', '国语配音', '无字幕', '中英双字',
        '字幕组', '字幕', '配音', '翻译', '译制',
        # 资源相关
        '资源',
    ]

    for tag in tags_to_remove:
        s = s.replace(tag, '')

    # 清理残留的分隔符和空白
    s = re.sub(r'[；;·•\-—]+\s*', ' ', s)  # 分隔符变空格
    s = re.sub(r'\s{2,}', ' ', s)  # 多个空格变一个
    s = s.strip().rstrip(' ,')

    # 清理空括号
    s = re.sub(r'[（(）)]', '', s)

    # 如果只剩下空白或空字符串，返回 None
    if not s:
        return None

    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", required=True)
    ap.add_argument("--json", required=True, help="影片信息 JSON 数组字符串")
    ap.add_argument("--sheet", default=None, help="工作表名，默认自动找『电影收藏』否则第一个")
    ap.add_argument("--force", action="store_true", help="允许写入重复电影名")
    args = ap.parse_args()

    movies = json.loads(args.json)
    if isinstance(movies, dict):
        movies = [movies]
    if not movies:
        print(json.dumps({"ok": False, "error": "empty input"}, ensure_ascii=False))
        return

    xlsx_path = Path(args.xlsx)
    wb = load_workbook(xlsx_path)

    # 定位工作表
    if args.sheet and args.sheet in wb.sheetnames:
        ws = wb[args.sheet]
    elif "电影收藏" in wb.sheetnames:
        ws = wb["电影收藏"]
    else:
        ws = wb.worksheets[0]

    # 表头 → 列号映射（第 1 行）；匹配时归一化：去空格和 "/"，兼容「国家/地区」「国家地区」等写法
    def _norm_header(s):
        return re.sub(r"[\s/]+", "", s)

    header = {}
    for c in range(1, ws.max_column + 1):
        v = ws.cell(row=1, column=c).value
        if v is not None and str(v).strip():
            header[_norm_header(v)] = c

    def col(*names):
        """按候选名找列号（归一化后匹配）"""
        for n in names:
            if _norm_header(n) in header:
                return header[_norm_header(n)]
        return None

    c_idx  = col("序号")
    c_name = col("电影名称", "片名")
    c_link = col("网盘链接", "链接")
    c_code = col("提取码")
    c_country = col("国家地区", "国家")
    c_year = col("年份")
    c_genre = col("类型")
    c_dir  = col("导演")
    c_rate = col("豆瓣评分")
    c_stat = col("观看状态")
    c_date = col("收藏日期")
    c_remark = col("备注")
    if c_name is None or c_link is None:
        print(json.dumps({"ok": False, "error": f"找不到关键列，现有表头: {list(header)}"}, ensure_ascii=False))
        return

    # 找最后有内容的数据行（按名称列和链接列判断），并做查重索引
    last_row, last_serial, existing = 1, 0, {}
    for r in range(2, ws.max_row + 1):
        nm = ws.cell(row=r, column=c_name).value
        lk = ws.cell(row=r, column=c_link).value if c_link else None
        if (nm is not None and str(nm).strip()) or (lk is not None and str(lk).strip()):
            last_row = r
            if c_idx:
                sv = ws.cell(row=r, column=c_idx).value
                try:
                    last_serial = max(last_serial, int(sv))
                except (TypeError, ValueError):
                    pass
            if nm:
                existing[norm(nm)] = r

    written, skipped = [], []
    for m in movies:
        name = str(m.get("name", "")).strip()
        if not name:
            skipped.append({"movie": m, "reason": "缺少电影名"})
            continue
        key = norm(name)
        if key in existing and not args.force:
            skipped.append({"movie": name, "reason": f"已存在于第 {existing[key]} 行（查重命中）"})
            continue

        row = last_row + 1
        src_row = last_row  # 样式来源行
        # 整行复制上一数据行样式（字体/填充/边框/对齐/数字格式）
        for c in range(1, ws.max_column + 1):
            src = ws.cell(row=src_row, column=c)
            dst = ws.cell(row=row, column=c)
            dst._style = copy.copy(src._style)

        def put(cno, val):
            if cno:
                ws.cell(row=row, column=cno).value = val

        put(c_idx, last_serial + 1)
        put(c_name, name)
        put(c_country, m.get("country"))
        y = m.get("year")
        put(c_year, int(y) if y not in (None, "") else None)
        put(c_genre, m.get("genre"))
        put(c_dir, m.get("director"))
        rt = m.get("rating")
        if rt not in (None, ""):
            try:
                rt = float(rt)
            except (TypeError, ValueError):
                rt = None
        put(c_rate, rt)
        put(c_stat, m.get("status") or "想看")
        dt = m.get("date")
        if dt in (None, ""):
            dt = date.today()
        elif isinstance(dt, str):
            dt = datetime.strptime(dt, "%Y-%m-%d").date()
        if c_date:
            cd = ws.cell(row=row, column=c_date)
            cd.value = dt
            cd.number_format = "yyyy-mm-dd"
        put(c_link, m.get("link"))
        put(c_code, m.get("code"))
        # 备注清洗：只保留剧情简介，剥离片源/画质/字幕描述
        raw_remark = m.get("remark")
        put(c_remark, strip_source_tags(raw_remark))

        written.append({"row": row, "name": name, "serial": last_serial + 1})
        existing[key] = row
        last_row, last_serial = row, last_serial + 1

    # 保存；被占用则改存 _new 副本
    saved = str(xlsx_path)
    status = "ok"
    try:
        wb.save(xlsx_path)
    except PermissionError:
        alt = xlsx_path.with_name(xlsx_path.stem + "_new.xlsx")
        wb.save(alt)
        saved = str(alt)
        status = "LOCKED"
    except Exception as e:  # 其他异常：改存副本兜底
        alt = xlsx_path.with_name(xlsx_path.stem + "_new.xlsx")
        wb.save(alt)
        saved = str(alt)
        status = f"fallback:{type(e).__name__}"

    print(json.dumps({
        "ok": True, "status": status, "saved_to": saved,
        "written": written, "skipped": skipped,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
