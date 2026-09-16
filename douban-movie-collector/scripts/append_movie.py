# -*- coding: utf-8 -*-
"""
append_movie.py — 向影视收藏表 xlsx 追加或更新影视条目
用法：
  python append_movie.py --xlsx <表格路径> --json '<JSON数组>' [--update] [--force]
JSON 数组元素字段（除 name 外均可选）：
  name 必填；link 网盘链接；code 提取码；country 国家地区；year 年份；
  genre 类型；director 导演；rating 豆瓣评分；status 观看状态(默认"想看")；
  date 收藏日期(默认今天)；remark 备注
行为：
  1. 按表头名定位列，序号自动顺延
  2. 按豆瓣 ID 或“片名+年份+媒体类型”定位条目，同名候选不唯一时跳过
  3. 样式从上一数据行整行复制，日期列写 date 并使用 yyyy-mm-dd 格式
  4. 网盘链接和豆瓣链接写入 Excel 原生超链接，显示为可点击短标签
  4. 使用同目录临时文件原子替换；目标文件被占用时返回 LOCKED，不生成 _new.xlsx
输出：JSON 摘要（写入行号 / 跳过的重复项 / 保存状态）
"""
import sys, json, argparse, copy, re, os, tempfile
from datetime import datetime, date
from pathlib import Path
from openpyxl.utils import get_column_letter
from openpyxl import load_workbook


def norm(s):
    """归一化电影名用于查重：去空白、全半角统一、去书名号"""
    if s is None:
        return ""
    s = str(s).strip().replace("《", "").replace("》", "")
    return re.sub(r"\s+", "", s).lower()


OPTIONAL_COLUMNS = [
    "媒体类型", "集数", "季数", "豆瓣ID", "豆瓣链接", "评分核验日期",
]
MEDIA_TYPES = {"电影", "电视剧", "迷你剧", "综艺", "纪录片"}


def ensure_columns(ws, header, enabled=True, include_series_columns=False):
    """为旧模板追加可选字段；已有表头不重复创建。"""
    if not enabled:
        return header
    next_col = ws.max_column + 1
    columns = OPTIONAL_COLUMNS if include_series_columns else [
        name for name in OPTIONAL_COLUMNS if name not in ("集数", "季数")
    ]
    for name in columns:
        key = re.sub(r"[\s/]+", "", name)
        if key in header:
            continue
        cell = ws.cell(row=1, column=next_col)
        cell.value = name
        if ws.max_column >= 1:
            src = ws.cell(row=1, column=max(1, next_col - 1))
            cell._style = copy.copy(src._style)
        header[key] = next_col
        next_col += 1
    return header


def as_int(value, field):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{field} 必须是整数") from exc


def as_positive_int(value, field):
    value = as_int(value, field)
    if value is not None and value < 1:
        raise ValueError(f"{field} 必须大于等于 1")
    return value


def as_media_type(value):
    if value in (None, ""):
        return None
    value = {"韩剧": "电视剧", "国剧": "电视剧", "美剧": "电视剧"}.get(str(value).strip(), str(value).strip())
    if value not in MEDIA_TYPES:
        raise ValueError(f"media_type 必须是：{'、'.join(sorted(MEDIA_TYPES))}")
    return value


def default_media_type(movie):
    return as_media_type(movie.get("media_type") or ("电视剧" if movie.get("episodes") else "电影"))


def sheet_for_media_type(media_type):
    return "电影收藏" if media_type == "电影" else "电视剧收藏"


def as_rating(value):
    if value in (None, ""):
        return None
    try:
        value = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("rating 必须是 0-10 的数字") from exc
    if not 0 <= value <= 10:
        raise ValueError("rating 必须在 0-10 之间")
    return value


def as_date(value, field="date"):
    if value in (None, ""):
        return date.today()
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    try:
        return datetime.strptime(str(value), "%Y-%m-%d").date()
    except ValueError as exc:
        raise ValueError(f"{field} 必须是 YYYY-MM-DD") from exc


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


def set_native_hyperlink(cell, value, label):
    """写入可点击的 Excel 原生超链接，同时保留当前单元格底色。"""
    if value in (None, ""):
        return
    value = str(value).strip()
    if not re.match(r"^https?://", value, re.I):
        cell.value = value
        return
    cell.value = label
    cell.hyperlink = value
    font = copy.copy(cell.font)
    font.color = "0563C1"
    font.underline = "single"
    cell.font = font
    alignment = copy.copy(cell.alignment)
    alignment.horizontal = "center"
    alignment.vertical = "center"
    cell.alignment = alignment


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", required=True)
    ap.add_argument("--json", required=True, help="影片信息 JSON 数组字符串")
    ap.add_argument("--sheet", default=None, help="工作表名；不指定时按媒体类型自动选择")
    ap.add_argument("--force", action="store_true", help="允许写入重复电影名")
    ap.add_argument("--update", action="store_true", help="命中已有条目时更新非空字段，而不是跳过")
    ap.add_argument("--no-schema", action="store_true", help="不自动追加媒体类型/豆瓣ID等可选列")
    args = ap.parse_args()

    movies = json.loads(args.json)
    if isinstance(movies, dict):
        movies = [movies]
    if not movies:
        print(json.dumps({"ok": False, "error": "empty input"}, ensure_ascii=False))
        return

    xlsx_path = Path(args.xlsx)
    wb = load_workbook(xlsx_path)

    # 定位工作表；一批数据必须属于同一媒体类别，避免误写到同一张表。
    if args.sheet:
        if args.sheet not in wb.sheetnames:
            print(json.dumps({"ok": False, "error": f"找不到工作表: {args.sheet}"}, ensure_ascii=False))
            return
        ws = wb[args.sheet]
    else:
        target_sheets = {sheet_for_media_type(default_media_type(m)) for m in movies}
        if len(target_sheets) > 1:
            print(json.dumps({"ok": False, "error": "一批数据包含电影和电视剧，请分成两批写入"}, ensure_ascii=False))
            return
        target_sheet = target_sheets.pop()
        if target_sheet not in wb.sheetnames:
            print(json.dumps({"ok": False, "error": f"找不到工作表: {target_sheet}"}, ensure_ascii=False))
            return
        ws = wb[target_sheet]

    # 表头 → 列号映射（第 1 行）；匹配时归一化：去空格和 "/"，兼容「国家/地区」「国家地区」等写法
    def _norm_header(s):
        return re.sub(r"[\s/]+", "", s)

    header = {}
    for c in range(1, ws.max_column + 1):
        v = ws.cell(row=1, column=c).value
        if v is not None and str(v).strip():
            header[_norm_header(v)] = c
    header = ensure_columns(
        ws,
        header,
        enabled=not args.no_schema,
        include_series_columns=ws.title == "电视剧收藏",
    )

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
    c_media = col("媒体类型")
    c_episodes = col("集数")
    c_seasons = col("季数")
    c_douban_id = col("豆瓣ID")
    c_douban_url = col("豆瓣链接")
    c_rating_date = col("评分核验日期")
    if c_name is None or c_link is None:
        print(json.dumps({"ok": False, "error": f"找不到关键列，现有表头: {list(header)}"}, ensure_ascii=False))
        return

    def put_link(row_no, cno, value, label):
        if cno and value not in (None, ""):
            set_native_hyperlink(ws.cell(row=row_no, column=cno), value, label)

    # 找最后有内容的数据行，并建立安全查重索引
    last_row, last_serial, existing = 1, 0, {}
    existing_meta = {}
    existing_ids = {}
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
                key = norm(nm)
                existing.setdefault(key, []).append(r)
                existing_meta[r] = {
                    "year": ws.cell(row=r, column=c_year).value if c_year else None,
                    "media_type": ws.cell(row=r, column=c_media).value if c_media else None,
                }
            if c_douban_id and ws.cell(row=r, column=c_douban_id).value:
                existing_ids[str(ws.cell(row=r, column=c_douban_id).value).strip()] = r

    written, skipped = [], []
    for m in movies:
        name = str(m.get("name", "")).strip()
        if not name:
            skipped.append({"movie": m, "reason": "缺少电影名"})
            continue
        key = norm(name)
        douban_id = str(m.get("douban_id", "")).strip()
        media_type = as_media_type(m.get("media_type"))
        year = as_int(m.get("year"), "year")
        if douban_id:
            candidate_rows = [existing_ids[douban_id]] if douban_id in existing_ids else []
        else:
            candidate_rows = existing.get(key, [])
            if len(candidate_rows) > 1 and (year is not None or media_type):
                candidate_rows = [
                    r for r in candidate_rows
                    if (year is None or existing_meta[r]["year"] == year)
                    and (not media_type or existing_meta[r]["media_type"] == media_type)
                ]
        if len(candidate_rows) > 1:
            skipped.append({"movie": name, "reason": "同名条目不唯一，请提供 douban_id 或确认年份/媒体类型"})
            continue
        matched_row = candidate_rows[0] if candidate_rows else None
        if matched_row and args.update:
            def update(cno, val):
                if cno and val not in (None, ""):
                    ws.cell(row=matched_row, column=cno).value = val
            update(c_name, name)
            update(c_country, m.get("country"))
            update(c_year, year)
            update(c_genre, m.get("genre"))
            update(c_dir, m.get("director"))
            update(c_rate, as_rating(m.get("rating")))
            update(c_stat, m.get("status"))
            if c_link and m.get("link") not in (None, ""):
                set_native_hyperlink(ws.cell(row=matched_row, column=c_link), m.get("link"), "打开网盘")
            update(c_code, m.get("code"))
            update(c_media, media_type)
            update(c_episodes, as_positive_int(m.get("episodes"), "episodes"))
            update(c_seasons, as_positive_int(m.get("seasons"), "seasons"))
            update(c_douban_id, douban_id)
            if c_douban_url and m.get("douban_url") not in (None, ""):
                set_native_hyperlink(ws.cell(row=matched_row, column=c_douban_url), m.get("douban_url"), "打开豆瓣")
            update(c_remark, strip_source_tags(m.get("remark")))
            if c_rating_date and m.get("rating") not in (None, ""):
                ws.cell(row=matched_row, column=c_rating_date).value = as_date(m.get("rating_date"), "rating_date")
                ws.cell(row=matched_row, column=c_rating_date).number_format = "yyyy-mm-dd"
            if c_date and m.get("date") not in (None, ""):
                ws.cell(row=matched_row, column=c_date).value = as_date(m["date"])
                ws.cell(row=matched_row, column=c_date).number_format = "yyyy-mm-dd"
            written.append({"row": matched_row, "name": name, "action": "updated"})
            continue
        if matched_row and not args.force:
            skipped.append({"movie": name, "reason": f"已存在于第 {matched_row} 行（查重命中，可用 --update 更新）"})
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
        put(c_year, year)
        put(c_genre, m.get("genre"))
        put(c_dir, m.get("director"))
        rt = as_rating(m.get("rating"))
        put(c_rate, rt)
        put(c_stat, m.get("status") or "想看")
        dt = as_date(m.get("date"))
        if c_date:
            cd = ws.cell(row=row, column=c_date)
            cd.value = dt
            cd.number_format = "yyyy-mm-dd"
        put_link(row, c_link, m.get("link"), "打开网盘")
        put(c_code, m.get("code"))
        normalized_media_type = media_type or default_media_type(m)
        put(c_media, normalized_media_type)
        put(c_episodes, as_positive_int(m.get("episodes"), "episodes"))
        put(c_seasons, as_positive_int(m.get("seasons"), "seasons"))
        put(c_douban_id, douban_id or None)
        put_link(row, c_douban_url, m.get("douban_url"), "打开豆瓣")
        if c_rating_date and rt is not None:
            ws.cell(row=row, column=c_rating_date).value = as_date(m.get("rating_date"), "rating_date")
            ws.cell(row=row, column=c_rating_date).number_format = "yyyy-mm-dd"
        # 备注清洗：只保留剧情简介，剥离片源/画质/字幕描述
        raw_remark = m.get("remark")
        put(c_remark, strip_source_tags(raw_remark))

        written.append({"row": row, "name": name, "serial": last_serial + 1})
        existing.setdefault(key, []).append(row)
        existing_meta[row] = {"year": year, "media_type": normalized_media_type}
        if douban_id:
            existing_ids[douban_id] = row
        last_row, last_serial = row, last_serial + 1

    if last_row >= 1:
        ws.auto_filter.ref = f"A1:{get_column_letter(ws.max_column)}{last_row}"

    # 原子保存；被占用时不生成容易混淆的 _new 副本
    saved = str(xlsx_path)
    status = "ok"
    temp_path = None
    try:
        fd, temp_name = tempfile.mkstemp(prefix=xlsx_path.stem + ".", suffix=".tmp.xlsx", dir=xlsx_path.parent)
        os.close(fd)
        temp_path = Path(temp_name)
        wb.save(temp_path)
        os.replace(temp_path, xlsx_path)
        check_wb = load_workbook(xlsx_path, read_only=True, data_only=False)
        check_ws = check_wb[ws.title]
        for item in written:
            if check_ws.cell(row=item["row"], column=c_name).value in (None, ""):
                raise ValueError(f"保存后复核失败：第 {item['row']} 行名称为空")
        check_wb.close()
    except PermissionError:
        status = "LOCKED"
    except Exception as e:
        status = f"error:{type(e).__name__}"
    finally:
        if temp_path and temp_path.exists():
            temp_path.unlink()

    print(json.dumps({
        "ok": status == "ok", "status": status, "saved_to": saved if status == "ok" else None,
        "written": written, "skipped": skipped,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
