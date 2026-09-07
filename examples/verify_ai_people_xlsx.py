# -*- coding: utf-8 -*-
"""独立验证 AI人物追踪表.xlsx v3:边框全覆盖、合并标题、下拉验证、新列结构、公式、行数。

用法:python verify_ai_people_xlsx.py [xlsx路径]
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
F = sys.argv[1] if len(sys.argv) > 1 else r"D:/yangzhen/workskill/AI人物追踪表.xlsx"
ok = True


def fail(msg):
    global ok
    ok = False
    print("FAIL:", msg)


z = zipfile.ZipFile(F)
names = z.namelist()
print("parts:", [n for n in names if "minimal_xlsx" not in n])
if any("minimal_xlsx" in n for n in names):
    fail("包内混入模板垃圾部件 minimal_xlsx/*")

# 1. styles.xml: borderId 1 四边 thin,cellXfs 22
st = z.read("xl/styles.xml").decode("utf-8")
sroot = ET.fromstring(st)
borders = sroot.find("m:borders", NS)
if borders.get("count") != "2":
    fail(f"borders count={borders.get('count')}")
b1 = borders.findall("m:border", NS)[1]
for side in ("left", "right", "top", "bottom"):
    el = b1.find(f"m:{side}", NS)
    if el is None or el.get("style") != "thin":
        fail(f"border1 {side} not thin")
cellxfs = sroot.find("m:cellXfs", NS)
n_xf = int(cellxfs.get("count"))
if n_xf != 22:
    fail(f"cellXfs count={n_xf}")
for i, xf in enumerate(cellxfs.findall("m:xf", NS)):
    if i >= 14 and xf.get("borderId") != "1":
        fail(f"xf[{i}] borderId={xf.get('borderId')}")
print(f"styles OK: borders=2(thin 四边), cellXfs=22, xf14-21 全部 borderId=1")

# 2. sharedStrings
shared = ET.fromstring(z.read("xl/sharedStrings.xml").decode("utf-8"))
si = ["".join(t.itertext()) for t in shared.findall("m:si", NS)]
if int(shared.get("uniqueCount")) != len(si):
    fail("uniqueCount mismatch")
print(f"sharedStrings: count={shared.get('count')} unique={shared.get('uniqueCount')} (len={len(si)})")

# 3. 每个 sheet
expect = {
    "xl/worksheets/sheet1.xml": dict(title="AI 人物追踪表(2026-09)",
                                     data_rows=68, ncols=13, formulas=68, merge="A1:M1",
                                     first="奥特曼", last="李宏伟", dv=3),
    "xl/worksheets/sheet2.xml": dict(title="AI 人物言论库(持续追加)",
                                     data_rows=31, ncols=8, formulas=0, merge="A1:H1",
                                     first="奥特曼", last="王兴兴", dv=3),
}
border_styles = {"15", "16", "17", "18", "19", "20", "21"}
for part, exp in expect.items():
    root = ET.fromstring(z.read(part).decode("utf-8"))
    mc = root.find("m:mergeCells", NS)
    if mc is None or mc.get("count") != "1" or mc.find("m:mergeCell", NS).get("ref") != exp["merge"]:
        fail(f"{part}: mergeCells != {exp['merge']}")
    pane = root.find(".//m:pane", NS)
    if pane is None or pane.get("ySplit") != "2" or pane.get("state") != "frozen":
        fail(f"{part}: freeze pane wrong")
    # 下拉验证
    dvs = root.find("m:dataValidations", NS)
    if dvs is None or int(dvs.get("count")) != exp["dv"]:
        fail(f"{part}: dataValidations 缺失或数量错")
    else:
        for dv in dvs.findall("m:dataValidation", NS):
            f1 = dv.find("m:formula1", NS)
            if dv.get("type") != "list" or f1 is None or not f1.text:
                fail(f"{part}: dataValidation {dv.get('sqref')} 配置异常")
        print(f"{part} DV OK: {[dv.get('sqref') for dv in dvs]}")
    rows = root.findall(".//m:sheetData/m:row", NS)
    if len(rows) != exp["data_rows"] + 2:
        fail(f"{part}: rows={len(rows)} != {exp['data_rows']+2}")
    a1 = rows[0].find('m:c[@r="A1"]', NS)
    t = si[int(a1.find("m:v", NS).text)]
    if t != exp["title"]:
        fail(f"{part}: title {t!r}")
    if a1.get("s") != "13":
        fail(f"{part}: title style {a1.get('s')}")
    hdr = rows[1].findall("m:c", NS)
    if len(hdr) != exp["ncols"]:
        fail(f"{part}: header cols {len(hdr)}")
    for c in hdr:
        if c.get("s") != "14":
            fail(f"{part}: header cell {c.get('r')} style={c.get('s')}")
    zebra = plain = n_formula = empty_styled = 0
    for r in rows[2:]:
        cells = r.findall("m:c", NS)
        if len(cells) != exp["ncols"]:
            fail(f"{part} row {r.get('r')}: {len(cells)} cols")
        for c in cells:
            s = c.get("s", "")
            if s not in border_styles:
                fail(f"{part} {c.get('r')}: style {s} 无边框")
            if s in {"16", "20", "21"}:
                zebra += 1
            elif s in {"15", "18", "19"}:
                plain += 1
            if c.find("m:f", NS) is not None:
                n_formula += 1
                if "COUNTIF(言论库!B:B,B" not in c.find("m:f", NS).text:
                    fail(f"{part}: 公式异常")
            if c.find("m:v", NS) is None and c.find("m:f", NS) is None:
                empty_styled += 1  # 空备注格:有样式无边框值
    if zebra == 0 or plain == 0:
        fail(f"{part}: zebra={zebra} plain={plain}")
    if n_formula != exp["formulas"]:
        fail(f"{part}: formulas {n_formula} != {exp['formulas']}")
    b_first = rows[2].find('m:c[@r="B3"]', NS)
    b_last = rows[-1].find(f'm:c[@r="B{len(rows)}"]', NS)
    if si[int(b_first.find("m:v", NS).text)] != exp["first"]:
        fail(f"{part}: first row wrong")
    if si[int(b_last.find("m:v", NS).text)] != exp["last"]:
        fail(f"{part}: last row wrong")
    print(f"{part} OK: {exp['data_rows']} 数据行 x {exp['ncols']} 列全边框, "
          f"zebra={zebra} plain={plain}, 公式={n_formula}, 空备注格={empty_styled}")

# 4. 内容抽查:国别简化、发声渠道、优先级红粗、新人物板块
s1 = ET.fromstring(z.read("xl/worksheets/sheet1.xml").decode("utf-8"))
def val(ref):
    c = s1.find(f'.//m:c[@r="{ref}"]', NS)
    if c is None:
        return (None, None)
    v = c.find("m:v", NS)
    if v is None:
        return (c, None)
    if c.get("t") == "s":
        return (c, si[int(v.text)])
    return (c, v.text)  # 数字/公式缓存值原样返回

regions = {val(f"F{r}")[1] for r in range(3, 71)}
if regions != {"国内", "海外"}:
    fail(f"国别取值 {regions} != {{国内,海外}}")
if val("F3")[1] != "海外" or val("F20")[1] != "国内":
    fail("国别分组抽查失败(奥特曼应海外/李开复应国内)")
if "X @sama" not in (val("J3")[1] or ""):
    fail(f"J3 发声渠道异常: {val('J3')[1]!r}")
if val("K3")[0].get("s") != "18":
    fail(f"K3 优先级高样式 != 18")
# 空备注:奥特曼 M3 应为带样式空格
m3, m3v = val("M3")
if m3 is None or m3v is not None or m3.get("s") not in border_styles:
    fail(f"M3 空备注格异常: s={getattr(m3,'get',lambda k:None)('s')} v={m3v}")
# 辛顿备注(M10 行=8号→行10)
if "核实" not in (val("M10")[1] or ""):
    fail(f"M10 辛顿备注缺失: {val('M10')[1]!r}")
# 新增人物抽查:扎克伯格(26号→行28)、稚晖君(47号→行49)、梁孟松(55号→行57)、李宏伟(68号→行70)
spots = {
    "B28": "扎克伯格", "E28": "巨头掌门", "F28": "海外", "K28": "高",
    "B49": "彭志辉(稚晖君)", "E49": "机器人",
    "B57": "梁孟松", "E57": "芯片硬件",
    "B70": "李宏伟", "E70": "AI应用", "A70": "68",
}
for ref, want in spots.items():
    got = val(ref)[1]
    if got != want and not (isinstance(want, str) and want.isdigit() and got == want):
        fail(f"{ref} 期望 {want!r} 实际 {got!r}")
# 存疑人物备注抽查:沙泽尔(33号→行35)、魏少军(60号→行62)
if "待核实" not in (val("M35")[1] or ""):
    fail(f"M35 沙泽尔待核实备注缺失: {val('M35')[1]!r}")
if "存疑" not in (val("M62")[1] or ""):
    fail(f"M62 魏少军存疑备注缺失: {val('M62')[1]!r}")
# 圈层取值全部在合法集合内
VALID_CIRCLES = {"AI领军", "技术大神", "学者", "芯片硬件", "投资圈", "机器人", "巨头掌门", "AI应用"}
bad = {val(f"E{r}")[1] for r in range(3, 71)} - VALID_CIRCLES - {None}
if bad:
    fail(f"圈层非法取值: {bad}")
print("内容抽查 OK: 国别=国内/海外, 新人物板块/存疑备注/圈层合法, K3 红粗, 空备注格带边框")

# 5. 命名区域 PersonNames(言论库姓名下拉来源)
wbx = z.read("xl/workbook.xml").decode("utf-8")
wbr = ET.fromstring(wbx)
dns = wbr.find("m:definedNames", NS)
if dns is None:
    fail("workbook.xml 缺 definedNames")
else:
    dn = dns.find('m:definedName[@name="PersonNames"]', NS)
    if dn is None or "人物主表!$B$3:$B$70" not in (dn.text or ""):
        fail(f"PersonNames 定义异常: {dn.text if dn is not None else None}")
    else:
        print("命名区域 OK: PersonNames = 人物主表!$B$3:$B$70")
# 言论库 B 列下拉应引用 PersonNames(非内嵌)
s2 = ET.fromstring(z.read("xl/worksheets/sheet2.xml").decode("utf-8"))
dv_b = s2.find('.//m:dataValidations/m:dataValidation[@sqref="B3:B500"]', NS)
f1 = dv_b.find("m:formula1", NS) if dv_b is not None else None
if f1 is None or f1.text != "PersonNames":
    fail(f"言论库姓名下拉应引用 PersonNames, 实际: {f1.text if f1 is not None else None}")
if "calcId" not in wbx:
    fail("workbook.xml 缺 calcPr")
z.close()

print()
print("RESULT:", "ALL PASS" if ok else "HAS FAILURES")
raise SystemExit(0 if ok else 1)
