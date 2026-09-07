# -*- coding: utf-8 -*-
"""生成 AI 人物追踪表的 xlsx XML v2(基于 minimax-xlsx 的 minimal_xlsx 模板)。

v2 变化:
  - 所有数据单元格加四边细边框
  - 标题行(合并单元格)+ 深蓝底白字表头 + 斑马纹隔行
  - 长文本列自动换行、垂直居中;短列水平居中
  - 优先级「高」红粗显示
  - 冻结前两行(标题+表头)

用法:python build_ai_people_xlsx.py <模板工作目录>
之后用 minimax-xlsx 的 xlsx_pack.py 打包。
"""
import sys
import os
from xml.sax.saxutils import escape

WORK = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\zhen\AppData\Local\Temp\xlsx_work"

# ---------- 人物主表数据 ----------
MAIN_TITLE = "AI 人物追踪表(2026-09)"
MAIN_HEADERS = ["序号", "姓名", "英文名", "机构与职位", "圈层", "国别",
                "观点立场", "立场变化", "代表事件", "发声渠道", "关注优先级", "言论数", "备注"]

MAIN_ROWS = [
    [1, "奥特曼", "Sam Altman", "OpenAI CEO", "AI领军", "海外",
     "AGI加速+监管叙事并行", "2023谨慎叙事→2025《温和奇点》乐观加速",
     "2023.11被董事会解雇,5天后回归", "X @sama;博客 samaltman.com", "高", ""],
    [2, "马斯克", "Elon Musk", "xAI创始人;Tesla/SpaceX CEO", "AI领军", "海外",
     "风险警告+开源加速并行", "2015联创OpenAI→2018退出→2024起诉OpenAI",
     "xAI Grok;2024起诉OpenAI违背使命", "X @elonmusk", "高", ""],
    [3, "阿莫迪", "Dario Amodei", "Anthropic CEO", "AI领军", "海外",
     "安全派:强AI或2026-2027到来", "2021带团队离开OpenAI创立Anthropic",
     "《Machines of Loving Grace》技术乐观路线图", "X @DarioAmodei;官网长文", "高", ""],
    [4, "哈萨比斯", "Demis Hassabis", "Google DeepMind CEO", "AI领军", "海外",
     "谨慎推进:AGI或2030前后", "AlphaGo→AlphaFold→诺奖",
     "2024诺贝尔化学奖(AlphaFold)", "X @DemisHassabis", "高", ""],
    [5, "苏茨克维", "Ilya Sutskever", "SSI(安全超级智能)创始人", "AI领军", "海外",
     "安全优先:先对齐后加速", "2023参与罢免奥特曼→2024离开→创立SSI",
     "NeurIPS 2024「预训练时代将终结」", "X @ilyasut", "高", ""],
    [6, "卡帕西", "Andrej Karpathy", "Eureka Labs创始人;前Tesla AI总监", "技术大神", "海外",
     "教育实用派", "OpenAI创始成员→Tesla→AI教育创业",
     "「LLM OS」概念;Eureka Labs", "X @karpathy;YouTube/博客", "高", ""],
    [7, "杨立昆", "Yann LeCun", "Meta首席AI科学家", "技术大神", "海外",
     "反末日论+开源派", "2023-2024持续炮轰LLM路线",
     "2018图灵奖;公开论战AI末日论", "X @ylecun", "高", ""],
    [8, "辛顿", "Geoffrey Hinton", "多伦多大学;前Google", "技术大神", "海外",
     "风险警告派:AI或失控", "2023从Google离职以自由发声",
     "2024诺贝尔物理学奖", "X @geoffreyhinton;访谈为主", "高", "灭绝概率说法多变体,引用前核实"],
    [9, "本吉奥", "Yoshua Bengio", "Mila创始人;蒙特利尔大学", "技术大神", "海外",
     "安全派:国际监管", "2018图灵奖→重心转向AI安全",
     "2024主导《国际AI安全报告》", "X @YoshuaBengio;Mila官网", "中", ""],
    [10, "李飞飞", "Fei-Fei Li", "斯坦福;World Labs创始人", "学者", "海外",
     "空间智能+务实", "ImageNet→空间智能创业",
     "ImageNet之母;2024创立World Labs", "X @drfeifei", "高", ""],
    [11, "吴恩达", "Andrew Ng", "DeepLearning.AI创始人;斯坦福", "学者", "海外",
     "实用乐观:AI平民化", "Google Brain→Coursera→AI教育",
     "「AI is the new electricity」", "X @AndrewYNg;The Batch 周报", "中", ""],
    [12, "黄仁勋", "Jensen Huang", "NVIDIA CEO", "芯片硬件", "海外",
     "加速派:算力即生产力", "图形芯片→AI算力霸主",
     "CUDA生态;GTC大会", "GTC/COMPUTEX 主题演讲", "高", ""],
    [13, "皮查伊", "Sundar Pichai", "Google CEO", "AI领军", "海外",
     "谨慎推进", "搜索→AI全线整合",
     "Gemini全线整合", "X @sundarpichai", "中", ""],
    [14, "纳德拉", "Satya Nadella", "微软CEO", "AI领军", "海外",
     "商业实用派", "云优先→AI优先",
     "百亿美元投OpenAI;Copilot全线", "X @satyanadella", "中", ""],
    [15, "安德森", "Marc Andreessen", "a16z联创", "投资圈", "海外",
     "技术乐观加速派:反监管", "互联网投资→AI重注",
     "2023.6《Why AI Will Save the World》", "X @pmarca;a16z 博客/播客", "高", ""],
    [16, "霍夫曼", "Reid Hoffman", "LinkedIn联创;Greylock", "投资圈", "海外",
     "乐观实用:AI放大人", "OpenAI早期董事→持续布道",
     "《Impromptu》《Superagency》", "X @reidhoffman;播客/著作", "中", ""],
    [17, "科斯拉", "Vinod Khosla", "Khosla Ventures创始人", "投资圈", "海外",
     "乐观但有条件警告", "2019早期承诺10亿美元投资OpenAI",
     "OpenAI最早机构投资人", "X @vkhosla", "中", ""],
    [18, "李开复", "Kai-Fu Lee", "零一万物创始人;创新工场董事长", "投资圈", "国内",
     "实用派:应用层机会", "微软/谷歌高管→创业孵化→大模型",
     "2024「大模型十巨头」论", "X @kaifulee;微博同名", "高", ""],
    [19, "梁文锋", "Liang Wenfeng", "DeepSeek创始人", "AI领军", "国内",
     "极简务实:开源+低成本", "幻方量化→DeepSeek",
     "2025.1 R1发布,引发全球关注", "(极少公开)访谈为主", "高", "极少发声,素材靠访谈转载"],
    [20, "杨植麟", "Yang Zhilin", "月之暗面(Kimi)创始人", "AI领军", "国内",
     "技术信仰派", "清华→卡内基梅隆→创业",
     "Kimi长上下文", "(极少公开)官方渠道", "高", ""],
    [21, "王小川", "Wang Xiaochuan", "百川智能创始人", "AI领军", "国内",
     "AGI+生命科学派", "搜狗CEO→二次创业",
     "搜狗出售后转型AGI", "微博@王小川", "中", ""],
    [22, "李彦宏", "Robin Li", "百度创始人", "AI领军", "国内",
     "应用务实派", "搜索→文心一言→萝卜快跑",
     "2023.3文心一言国内首发", "(无个人账号)发布会为主", "高", "闭源言论有争议,引用需上下文"],
    [23, "周靖人", "Zhou Jingren", "阿里云CTO;通义千问负责人", "AI领军", "国内",
     "开源生态派", "阿里达摩院→通义千问",
     "Qwen系列开源全球领跑", "(无个人账号)通义官方", "中", ""],
    [24, "朱啸虎", "Zhu Xiaohu", "金沙江创投主管合伙人", "投资圈", "国内",
     "商业回报务实派", "2024看空大模型创业→2025拥抱DeepSeek生态",
     "「独角兽捕手」", "微博@朱啸虎;访谈", "中", "立场反复,注意时间线"],
    [25, "王兴兴", "Wang Xingxing", "宇树科技创始人", "机器人", "国内",
     "硬件实干派", "机器狗→人形机器人",
     "2025春晚机器人扭秧歌", "(以采访与官方为主)", "高", ""],
    # ---- 以下 26-41 为 2026-09 批量扩充:海外新增 16 人 ----
    [26, "扎克伯格", "Mark Zuckerberg", "Meta CEO", "巨头掌门", "海外",
     "开源扩张:Llama 免费开放换生态", "封闭社交帝国→押注开源大模型",
     "Llama 3/4 开源;开源闭源路线之争", "Threads @zuck;Meta 官方", "高", ""],
    [27, "库克", "Tim Cook", "Apple CEO", "巨头掌门", "海外",
     "端侧务实:AI 融入硬件不炫技", "长期避谈 AI→2024 Apple Intelligence 全线接入",
     "2024 WWDC 发布 Apple Intelligence", "(极少个人发声)发布会为主", "中", ""],
    [28, "贾西", "Andy Jassy", "Amazon CEO", "巨头掌门", "海外",
     "基础设施派:AI 是 AWS 的新电力", "电商运营→All-in AI 云基建",
     "Bedrock;Trainium 芯片;Nova 模型", "X @ajassy;股东信", "中", ""],
    [29, "埃里森", "Larry Ellison", "甲骨文创始人", "巨头掌门", "海外",
     "激进扩张:AI 数据中心豪赌", "数据库巨头→AI 云基建狂人",
     "与 OpenAI 星门数据中心合作", "财报电话会/访谈", "中", "「AI 军备竞赛」类金句频出"],
    [30, "贝索斯", "Jeff Bezos", "亚马逊创始人", "巨头掌门", "海外",
     "长期主义:幕后布局 AI 与太空", "CEO 退位→双线押注",
     "投资 Perplexity 等 AI 新贵", "X @JeffBezos(偶发)", "中", ""],
    [31, "苏姿丰", "Lisa Su", "AMD CEO", "芯片硬件", "海外",
     "务实攻坚:性能对标英伟达", "2014 接手濒危 AMD→十年市值百倍",
     "Instinct MI300 撼动 AI 算力格局", "X @LisaSu;CES/财报会", "高", "黄仁勋表亲,「苏妈」对比叙事佳"],
    [32, "丹妮拉", "Daniela Amodei", "Anthropic 总裁", "AI领军", "海外",
     "安全派产品化", "OpenAI 副总裁→随兄联创 Anthropic",
     "与 Dario 共同创立 Anthropic", "X @danamodei", "中", ""],
    [33, "沙泽尔", "Noam Shazeer", "Google Gemini 联合负责人", "技术大神", "海外",
     "技术信仰:规模化至上", "Transformer 作者→创 Character.AI→2024 回归谷歌",
     "2017《Attention Is All You Need》合著", "(极少发声)技术访谈", "高", "「2026 加入 OpenAI」一说待核实"],
    [34, "沃尔夫", "Thomas Wolf", "Hugging Face 联合创始人", "AI领军", "海外",
     "开源生态布道→研究方法批评者", "纯开源乐观→2025 公开质疑 AI 研究跟风",
     "Hugging Face 开源生态;2025 批评长文", "X @Thom_Wolf;HF 博客", "中", ""],
    [35, "亚历山大·王", "Alexandr Wang", "Scale AI 创始人", "AI领军", "海外",
     "数据决定论:高质量数据定 AI 上限", "19 岁辍学创业→最年轻亿万富翁之一",
     "2025 Meta 重金入股 Scale AI", "X @alexandr_wang", "高", ""],
    [36, "珀尔", "Judea Pearl", "UCLA 教授;2011 图灵奖", "学者", "海外",
     "因果革命:现 AI 缺因果推理", "贝叶斯网络→公开批评深度学习",
     "《为什么》;「深度学习=曲线拟合」论战", "著作/演讲(无社交)", "中", "与深度学习阵营论战素材"],
    [37, "霍普菲尔德", "John Hopfield", "普林斯顿荣休教授", "学者", "海外",
     "物理视角看智能", "1982 Hopfield 网络→42 年后获诺奖",
     "2024 诺贝尔物理学奖", "诺奖演讲/访谈", "中", "「AI 之根在物理学」科普素材"],
    [38, "芬恩", "Chelsea Finn", "斯坦福教授", "学者", "海外",
     "具身智能+元学习", "纯学术→机器人实训派",
     "ALOHA 机器人;RT 系列合作", "X @chelseabfinn", "中", ""],
    [39, "布雷齐尔", "Cynthia Breazeal", "MIT Media Lab 教授", "机器人", "海外",
     "社交机器人+AI 素养教育", "Kismet(1998)→Jibo 失败→AI 教育",
     "社交机器人先驱;Jibo 创业复盘", "X @cynthiabreazeal", "低", ""],
    [40, "瑟夫", "Vint Cerf", "Google 首席互联网传道师", "学者", "海外",
     "互联网奠基人视角:AI 治理与存档", "TCP/IP 设计→警示数字信息保存",
     "「互联网之父」;TCP/IP 协议", "演讲/访谈", "低", ""],
    [41, "郭文景", "Demi Guo", "Pika 联合创始人", "AI领军", "海外",
     "技术极客:AI 视频生成前沿", "斯坦福博士辍学→25 岁创业",
     "Pika 视频生成爆款", "Pika 官方/访谈", "中", "英文名 Demi Guo(名单误作 Jing Wang)"],
    # ---- 以下 42-68 为 2026-09 批量扩充:国内新增 27 人 ----
    [42, "闫俊杰", "Yan Junjie", "MiniMax 创始人&CEO", "AI领军", "国内",
     "多模态通才:不做单一爆款", "商汤副总裁→创立 MiniMax",
     "2025 MiniMax 港股上市", "(低调)发布会/官方", "高", "上市时间与细节待核实"],
    [43, "唐杰", "Tang Jie", "智谱AI 首席科学家(奠基人)", "AI领军", "国内",
     "产学研贯通:模型即服务", "清华 KEG 实验室→智谱商业化",
     "悟道大模型;GLM 系列", "学术演讲/官方", "中", ""],
    [44, "张一鸣", "Zhang Yiming", "字节跳动创始人", "巨头掌门", "国内",
     "数据驱动实用主义:AI 全面产品化", "退居一线→豆包成国民级应用",
     "豆包用户量登顶国内 AI 应用", "(无个人社交)字节官方", "高", "极度低调,素材靠官方数据"],
    [45, "林俊旸", "Junyang Lin", "阿里通义千问技术负责人", "AI领军", "国内",
     "开源布道:Qwen 生态全球化", "阿里研究员→Qwen 开源掌门",
     "Qwen 开源衍生模型全球登顶", "X @JunyangLin;开源社区", "高", "与周靖人(23 号)分掌通义技术与战略"],
    [46, "姚顺雨", "Yao Shunyu", "腾讯首席AI科学家", "AI领军", "国内",
     "语言智能体:ReAct 范式", "OpenAI 研究员→回国加入腾讯",
     "ReAct/SWE-benchmark 论文", "学术圈/官方", "中", "腾讯任职细节待核实"],
    [47, "彭志辉(稚晖君)", "Zhihui Peng", "智元机器人 CEO", "机器人", "国内",
     "极客网红→量产实干", "华为天才少年→B 站百万粉→创业",
     "智元启元大模型;人形机器人量产", "B 站/微博 @稚晖君", "高", "自带百万粉丝,自媒体联动素材"],
    [48, "王鹤", "Wang He", "银河通用创始人;北大教授", "机器人", "国内",
     "产学研一体:具身感知", "北大助理教授→创业",
     "银河通用;具身大模型", "学术/官方", "中", ""],
    [49, "朱秋国", "Zhu Qiuguo", "云深处科技创始人", "机器人", "国内",
     "浙大系技术派:四足机器人", "浙大实验室→商业化",
     "绝影机器狗", "官方/展会", "低", ""],
    [50, "邓泰华", "Deng Taihua", "智元机器人联合创始人", "机器人", "国内",
     "研发-制造-租赁全生态", "华为无线产品线总裁→具身智能",
     "智元生态模式", "官方/访谈", "中", ""],
    [51, "周剑", "Zhou Jian", "优必选 CEO", "机器人", "国内",
     "商业化先驱:人形机器人第一股", "十一年坚持→港股上市",
     "2023 优必选港股上市", "官方/访谈", "中", ""],
    [52, "俞浩", "Yu Hao", "追觅科技创始人", "机器人", "国内",
     "技术品牌:马达自研到机器人", "清洁电器→人形机器人扩张",
     "追觅人形机器人出海", "官方/访谈", "中", ""],
    [53, "任正非", "Ren Zhengfei", "华为创始人", "巨头掌门", "国内",
     "长期主义:底层攻坚+教育为先", "至暗时刻→昇腾算力突围",
     "昇腾算力;内部讲话流出", "(无社交)内部讲话/访谈", "高", "内部讲话是金句富矿"],
    [54, "何庭波", "He Tingbo", "海思总裁", "芯片硬件", "国内",
     "备胎转正:极限生存", "2019 备胎信→数年沉潜攻坚",
     "2019《备胎正转》全员信", "(无个人社交)华为官方", "高", "「芯片女王」+备胎信,史诗级叙事"],
    [55, "梁孟松", "Liang Mengsong", "中芯国际联席 CEO", "芯片硬件", "国内",
     "制程攻坚:三年追平数代", "台积电→三星→中芯;三度请辞",
     "14nm 量产;闪辞被挽留", "(零社交)公开信/报道", "高", "三易其主+三度请辞,戏剧性拉满"],
    [56, "陈天石", "Chen Tianshi", "寒武纪创始人", "芯片硬件", "国内",
     "学术创业:AI 专用芯片", "中科大少年班→十年亏损→股王",
     "2024-2025 寒武纪股价登顶 A 股", "官方/股东大会", "高", ""],
    [57, "余凯", "Yu Kai", "地平线创始人", "芯片硬件", "国内",
     "软硬结合:智驾芯片平权", "百度研究院→创业",
     "征程 6;2024 港股上市", "官方/访谈", "中", ""],
    [58, "汪玉", "Wang Yu", "无问芯穹发起人;清华教授", "芯片硬件", "国内",
     "软硬协同:异构算力优化", "清华副院长→产业联盟发起人",
     "无问芯穹;清微智能", "学术/官方", "低", ""],
    [59, "沈亦晨", "Shen Yichen", "曦智科技创始人", "芯片硬件", "国内",
     "光计算先行者", "MIT 博士→光子芯片创业",
     "光电混合算力芯片 PACE", "官方/访谈", "低", ""],
    [60, "魏少军", "Wei Shaojun", "清华大学教授(集成电路)", "芯片硬件", "国内",
     "可重构计算架构", "集成电路教育→产业建言",
     "可重构计算芯片体系", "学术/行业论坛", "低", "「东方算芯董事长」一说存疑,以清华教授为准"],
    [61, "张建中", "Zhang Jianzhong", "摩尔线程创始人", "芯片硬件", "国内",
     "全功能 GPU 国产替代", "英伟达中国总经理→对标老东家创业",
     "国产 GPU 突围;递表上市", "官方/访谈", "中", ""],
    [62, "姚期智", "Andrew Yao", "清华大学教授;2000 图灵奖", "学者", "国内",
     "源头人才培养:中国 AI 造血", "普林斯顿终身教授→全职回国",
     "图灵奖;姚班/智班", "演讲/官方", "高", ""],
    [63, "朱松纯", "Zhu Songchun", "北大人工智能研究院院长", "学者", "国内",
     "通用 AI 另辟蹊径:小数据大任务", "UCLA 教授→回国领衔通用 AI",
     "通用智能体「通通」", "演讲/访谈", "中", "反对「大炼大模型」,差异化路线素材"],
    [64, "张林峰", "Zhang Linfeng", "深势科技创始人", "学者", "国内",
     "AI for Science:科研范式革命", "数学竞赛保送→科学计算创业",
     "分子模拟;AI 制药", "官方/学术", "低", ""],
    [65, "曾国洋", "Zeng Guoyang", "面壁智能联合创始人", "AI领军", "国内",
     "端侧小模型:轻量化智能", "清华直博→创业",
     "MiniCPM 端侧模型", "知乎/官方", "低", ""],
    [66, "印奇", "Yin Qi", "千里科技(原旷视)CEO", "AI应用", "国内",
     "AI 视觉→智驾转型", "旷视十年→更名转智驾",
     "旷视更名千里科技", "官方/访谈", "中", ""],
    [67, "刘庆峰", "Liu Qingfeng", "科大讯飞董事长", "AI领军", "国内",
     "语音+认知全栈:国产自主", "26 年坚守语音→星火大模型",
     "星火大模型;华为合作", "发布会/官方", "中", ""],
    [68, "李宏伟", "Li Hongwei", "雷鸟创新创始人", "AI应用", "国内",
     "AI+AR:空间计算入口", "TCL 系→AR 创业",
     "雷鸟 AI 眼镜", "官方/发布会", "低", ""],
]

# ---------- 言论库数据 ----------
QUOTE_TITLE = "AI 人物言论库(持续追加)"
QUOTE_HEADERS = ["序号", "人物姓名", "圈层", "言论内容", "标注", "出处与场合", "时间", "主题标签"]

QUOTE_ROWS = [
    [1, "奥特曼", "AI领军", "我们正接近一个奇点,但它会是温和的", "意译(中)",
     "个人博客《The Gentle Singularity》", "2025.6", "AGI时间表"],
    [2, "奥特曼", "AI领军", "AI能力随投入指数提升,成本每年下降约10倍", "意译(中)",
     "个人博客《Three Observations》", "2025.1", "Scaling"],
    [3, "马斯克", "AI领军", "AI可能比核武器更危险", "原文(英)",
     "推特", "2014.8", "风险警告"],
    [4, "马斯克", "AI领军", "xAI的使命是理解宇宙的真实本质", "意译(中)",
     "xAI发布会", "2023.7", "使命"],
    [5, "阿莫迪", "AI领军", "治理得当的强AI,能把100年的科学进步压缩到5-10年", "意译(中)",
     "博客《Machines of Loving Grace》", "2024.10", "乐观路线"],
    [6, "阿莫迪", "AI领军", "强大AI可能在2026-2027年间到来,对齐必须先行", "意译(中)",
     "媒体访谈", "2024", "时间表"],
    [7, "哈萨比斯", "AI领军", "AGI有望在2030年前后实现", "意译(中)",
     "媒体访谈", "2024", "时间表"],
    [8, "哈萨比斯", "AI领军", "AI for Science是AI最大的正向机会", "意译(中)",
     "诺贝尔奖相关访谈", "2024.10", "AI4S"],
    [9, "苏茨克维", "AI领军", "预训练时代将终结——数据如同化石燃料", "意译(中)",
     "NeurIPS演讲", "2024.12", "范式转移"],
    [10, "卡帕西", "技术大神", "LLM本质上是一种新型操作系统", "意译(中)",
     "视频《An Intro to LLMs》", "2023.11", "技术认知"],
    [11, "卡帕西", "技术大神", "软件2.0:由数据而非代码定义的程序", "意译(中)",
     "博客《Software 2.0》", "2017", "范式转移"],
    [12, "杨立昆", "技术大神", "自回归LLM是通往AGI道路上的岔路", "意译(中)",
     "社交媒体/访谈(多次)", "2024", "技术路线"],
    [13, "杨立昆", "技术大神", "AI末日论是一种新宗教", "意译(中)",
     "社交媒体", "2024", "反末日论"],
    [14, "辛顿", "技术大神", "AI有10-20%的概率在10-20年内导致人类灭绝", "意译(中)",
     "BBC采访", "2024.12", "生存风险"],
    [15, "辛顿", "技术大神", "我离开Google,是为了能自由谈论AI风险", "意译(中)",
     "离职访谈", "2023.5", "风险警告"],
    [16, "本吉奥", "技术大神", "AI发展速度已超出各国监管速度,国际协调刻不容缓", "意译(中)",
     "《国际AI安全报告》结论", "2025.1", "监管"],
    [17, "李飞飞", "学者", "空间智能是AI的下一个前沿——让AI理解三维世界", "意译(中)",
     "TED演讲", "2024.4", "技术路线"],
    [18, "吴恩达", "学者", "AI是新的电力", "原文(英)",
     "斯坦福演讲(多次引用)", "2017起", "技术认知"],
    [19, "黄仁勋", "芯片硬件", "买得越多,省得越多", "原文(英)",
     "COMPUTEX主题演讲", "2024.6", "算力商业"],
    [20, "黄仁勋", "芯片硬件", "推理时代的算力需求将远超训练", "意译(中)",
     "GTC大会", "2025.3", "算力"],
    [21, "皮查伊", "AI领军", "AI是比火与电更深远的技术", "原文(英)",
     "媒体采访(多次)", "2023", "技术定位"],
    [22, "安德森", "投资圈", "AI将拯救世界,而不是毁灭它", "意译(中)",
     "博客《Why AI Will Save the World》", "2023.6", "技术乐观"],
    [23, "霍夫曼", "投资圈", "AI放大人的能动性,而非取代人", "意译(中)",
     "《Superagency》/TED", "2025.2", "人机关系"],
    [24, "科斯拉", "投资圈", "AI可实现免费医生与导师,但风险同样真实", "意译(中)",
     "投资备忘录", "2023.4", "机会与风险"],
    [25, "李开复", "投资圈", "大模型进入应用为王的时代,技术与场景结合才有价值", "意译(中)",
     "媒体访谈", "2024", "商业化"],
    [26, "梁文锋", "AI领军", "我们的目标是AGI,而不是快速商业化", "意译(中)",
     "《暗涌》访谈", "2024.7", "AGI信仰"],
    [27, "梁文锋", "AI领军", "中国AI不能永远处在跟随的位置", "意译(中)",
     "《暗涌》访谈", "2024.7", "中国AI定位"],
    [28, "杨植麟", "AI领军", "把上下文越做越长,是通往AGI的关键路径之一", "意译(中)",
     "媒体访谈", "2024", "技术路线"],
    [29, "李彦宏", "AI领军", "闭源模型能力持续领先,开源模型的能力会落后", "意译(中)",
     "百度世界大会(引发争议)", "2024.11", "开源闭源之争"],
    [30, "朱啸虎", "投资圈", "大模型创业烧钱换不来壁垒,应用层才有价值", "意译(中)",
     "媒体访谈(多次)", "2024", "投资逻辑"],
    [31, "王兴兴", "机器人", "人形机器人有望在数年内进入千家万户", "意译(中)",
     "媒体采访", "2025.2", "机器人时间表"],
]

# ---------- sharedStrings ----------
_str_index = {}
_si_list = []
_ref_count = 0


def sidx(text):
    global _ref_count
    _ref_count += 1
    if text not in _str_index:
        _str_index[text] = len(_si_list)
        _si_list.append(text)
    return _str_index[text]


def cell_text(ref, text, style):
    return f'<c r="{ref}" t="s" s="{style}"><v>{sidx(text)}</v></c>'


def cell_num(ref, value, style):
    return f'<c r="{ref}" s="{style}"><v>{value}</v></c>'


def cell_formula(ref, formula, style="17"):
    return f'<c r="{ref}" s="{style}"><f>{escape(formula)}</f><v></v></c>'


def col_letter(n):
    r = ""
    while n > 0:
        n, rem = divmod(n - 1, 26)
        r = chr(65 + rem) + r
    return r


def build_sheet(title, headers, rows, align_map, widths,
                formula_col=None, formula_fn=None, row_ht=26, tab_selected=True,
                data_validations=None):
    """生成带边框/斑马/标题行的工作表 XML。

    样式索引(v2 append 到 styles.xml):
      13 大标题(粗14pt) 14 表头(白字深蓝) 15 数据左 16 斑马左
      17 公式绿居中 18 优先级高红粗 19 数据居中 20 斑马居中 21 斑马优先级高
    align_map: {列号: "center"|"left"}
    data_validations: [(sqref, formula1), ...]
      formula1 原样写入:内嵌列表传 '"选项1,选项2"'(带引号);
      引用命名区域传 'PersonNames'(不带引号,列表过长超 255 字符时用)
    """
    ncols = len(headers)
    xml = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    xml.append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
               'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    xml.append(f'<sheetViews><sheetView{" tabSelected=\"1\"" if tab_selected else ""} workbookViewId="0">'
               '<pane ySplit="2" topLeftCell="A3" activePane="bottomLeft" state="frozen"/>'
               '</sheetView></sheetViews>')
    xml.append('<sheetFormatPr defaultRowHeight="15" x14ac:dyDescent="0.25" '
               'xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac"/>')
    xml.append("<cols>")
    for i, w in enumerate(widths, 1):
        xml.append(f'<col min="{i}" max="{i}" width="{w}" customWidth="1"/>')
    xml.append("</cols>")
    xml.append("<sheetData>")

    # Row 1: 大标题(合并整行)
    xml.append(f'<row r="1" ht="34" customHeight="1">'
               f'{cell_text("A1", title, "13")}</row>')
    xml.append(f'<row r="2" ht="26" customHeight="1">')
    head_cells = []
    for ci, h in enumerate(headers, 1):
        head_cells.append(cell_text(f"{col_letter(ci)}2", h, "14"))
    xml[-1] = f'<row r="2" ht="26" customHeight="1">{"".join(head_cells)}</row>'

    # 数据行(斑马:第奇数条数据行灰底)
    # 注意:row 的字段对应"除公式列外"的所有列,公式列按 formula_col 插入
    for ri, row in enumerate(rows):
        excel_r = ri + 3
        zebra = (ri % 2 == 1)
        cells = []
        data_ci = 0
        for ci in range(1, ncols + 1):
            ref = f"{col_letter(ci)}{excel_r}"
            if ci == formula_col:
                cells.append(cell_formula(ref, formula_fn(excel_r)))
                continue
            val = row[data_ci]
            data_ci += 1
            centered = align_map.get(ci, "left") == "center"
            style = _data_style(ci, val, zebra, centered, headers)
            if val == "" or val is None:
                # 空值:仍输出带样式的空单元格,保证边框/斑马不断行
                cells.append(f'<c r="{ref}" s="{style}"/>')
            elif isinstance(val, (int, float)):
                cells.append(cell_num(ref, val, style))
            else:
                cells.append(cell_text(ref, val, style))
        xml.append(f'<row r="{excel_r}" ht="{row_ht}" customHeight="1">{"".join(cells)}</row>')

    xml.append("</sheetData>")
    xml.append(f'<mergeCells count="1"><mergeCell ref="A1:{col_letter(ncols)}1"/></mergeCells>')
    if data_validations:
        dv = [f'<dataValidations count="{len(data_validations)}">']
        for sqref, formula in data_validations:
            dv.append(f'<dataValidation type="list" allowBlank="1" showInputMessage="1" '
                      f'showErrorMessage="1" sqref="{sqref}">'
                      f'<formula1>{escape(formula)}</formula1>'
                      f'</dataValidation>')
        dv.append("</dataValidations>")
        xml.append("".join(dv))
    xml.append('<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" '
               'header="0.3" footer="0.3"/>')
    xml.append("</worksheet>")
    return "\n".join(xml)


def _data_style(ci, val, zebra, centered, headers):
    """按列语义选样式:优先级列特殊,公式列 17,其余按对齐+斑马。"""
    header = headers[ci - 1]
    if header in ("关注优先级",):
        if val == "高":
            return "21" if zebra else "18"
        return "20" if zebra else "19"
    if centered:
        return "20" if zebra else "19"
    return "16" if zebra else "15"


def patch_styles(path):
    """向模板 styles.xml 追加 v2 样式(append-only,不动原 13 个 slot)。"""
    with open(path, encoding="utf-8") as f:
        s = f.read()
    if "Big title (v2)" in s:
        raise SystemExit(f"错误:{path} 已 patch 过 v2 样式。"
                         "请先重新拷贝干净模板目录再运行本脚本。")

    new_fonts = (
        '    <!-- 5: Header white bold (v2) -->\n'
        '    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="00FFFFFF"/></font>\n'
        '    <!-- 6: Big title bold 14pt (v2) -->\n'
        '    <font><b/><sz val="14"/><name val="Calibri"/><color rgb="00000000"/></font>\n'
        '    <!-- 7: Priority-high red bold (v2) -->\n'
        '    <font><b/><sz val="11"/><name val="Calibri"/><color rgb="00C00000"/></font>\n'
    )
    s = s.replace('<fonts count="5">', '<fonts count="8">')
    s = s.replace("  </fonts>", new_fonts + "  </fonts>")

    new_fills = (
        '    <!-- 3: Header dark blue (v2) -->\n'
        '    <fill><patternFill patternType="solid">'
        '<fgColor rgb="001F4E79"/><bgColor indexed="64"/></patternFill></fill>\n'
        '    <!-- 4: Zebra light gray (v2) -->\n'
        '    <fill><patternFill patternType="solid">'
        '<fgColor rgb="00F2F2F2"/><bgColor indexed="64"/></patternFill></fill>\n'
    )
    s = s.replace('<fills count="3">', '<fills count="5">')
    s = s.replace("  </fills>", new_fills + "  </fills>")

    new_border = (
        '    <!-- 1: thin box border all sides (v2) -->\n'
        '    <border>'
        '<left style="thin"><color rgb="00BFBFBF"/></left>'
        '<right style="thin"><color rgb="00BFBFBF"/></right>'
        '<top style="thin"><color rgb="00BFBFBF"/></top>'
        '<bottom style="thin"><color rgb="00BFBFBF"/></bottom>'
        '<diagonal/>'
        '</border>\n'
    )
    s = s.replace('<borders count="1">', '<borders count="2">')
    s = s.replace("  </borders>", new_border + "  </borders>")

    AL_L = '<alignment horizontal="left" vertical="center" wrapText="1"/>'
    AL_C = '<alignment horizontal="center" vertical="center" wrapText="1"/>'
    AL_CN = '<alignment horizontal="center" vertical="center"/>'
    new_xfs = (
        f'    <!-- 13: Big title (v2) -->\n'
        f'    <xf numFmtId="0" fontId="6" fillId="0" borderId="0" xfId="0" applyFont="1" '
        f'applyAlignment="1">{AL_CN}</xf>\n'
        f'    <!-- 14: Column header, white on dark blue, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="5" fillId="3" borderId="1" xfId="0" applyFont="1" '
        f'applyFill="1" applyBorder="1" applyAlignment="1">{AL_C}</xf>\n'
        f'    <!-- 15: Data left, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" '
        f'applyAlignment="1">{AL_L}</xf>\n'
        f'    <!-- 16: Data left zebra, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyBorder="1" '
        f'applyFill="1" applyAlignment="1">{AL_L}</xf>\n'
        f'    <!-- 17: Cross-sheet COUNTIF, green centered, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" '
        f'applyBorder="1" applyAlignment="1">{AL_CN}</xf>\n'
        f'    <!-- 18: Priority high, red bold centered, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="7" fillId="0" borderId="1" xfId="0" applyFont="1" '
        f'applyBorder="1" applyAlignment="1">{AL_CN}</xf>\n'
        f'    <!-- 19: Data centered, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" '
        f'applyAlignment="1">{AL_C}</xf>\n'
        f'    <!-- 20: Data centered zebra, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyBorder="1" '
        f'applyFill="1" applyAlignment="1">{AL_C}</xf>\n'
        f'    <!-- 21: Priority high zebra, red bold centered, boxed (v2) -->\n'
        f'    <xf numFmtId="0" fontId="7" fillId="4" borderId="1" xfId="0" applyFont="1" '
        f'applyBorder="1" applyFill="1" applyAlignment="1">{AL_CN}</xf>\n'
    )
    s = s.replace('<cellXfs count="13">', '<cellXfs count="22">')
    s = s.replace("  </cellXfs>", new_xfs + "  </cellXfs>")

    with open(path, "w", encoding="utf-8") as f:
        f.write(s)
    print("styles.xml patched: fonts 5→8, fills 3→5, borders 1→2, cellXfs 13→22")


def main():
    # 1. patch styles.xml(先做,不依赖字符串登记顺序)
    patch_styles(os.path.join(WORK, "xl", "styles.xml"))

    # 2. 两个 sheet
    last_row = 2 + len(MAIN_ROWS)  # 主表数据末行(68 人 → 70)
    CIRCLE_OPTS = "AI领军,技术大神,学者,芯片硬件,投资圈,机器人,巨头掌门,AI应用"
    main_align = {1: "center", 2: "center", 5: "center", 6: "center", 11: "center"}
    main_xml = build_sheet(
        MAIN_TITLE, MAIN_HEADERS, MAIN_ROWS, main_align,
        widths=[6, 10, 16, 30, 11, 8, 24, 30, 34, 20, 10, 9, 26],
        formula_col=12,
        formula_fn=lambda r: f"COUNTIF(言论库!B:B,B{r})",
        row_ht=28,
        data_validations=[
            (f"E3:E{last_row}", f'"{CIRCLE_OPTS}"'),
            (f"F3:F{last_row}", '"国内,海外"'),
            (f"K3:K{last_row}", '"高,中,低"'),
        ],
    )
    quote_align = {1: "center", 2: "center", 3: "center", 5: "center", 7: "center", 8: "center"}
    quote_xml = build_sheet(
        QUOTE_TITLE, QUOTE_HEADERS, QUOTE_ROWS, quote_align,
        widths=[6, 10, 11, 46, 11, 28, 10, 13],
        row_ht=26, tab_selected=False,
        data_validations=[
            # 68 人名单超 255 字符,用命名区域 PersonNames 引用主表 B 列
            ("B3:B500", "PersonNames"),
            ("C3:C500", f'"{CIRCLE_OPTS}"'),
            ("E3:E500", '"意译(中),原文(英),原文(中)"'),
        ],
    )

    # 3. sharedStrings
    sst = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>']
    sst.append(f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
               f'count="{_ref_count}" uniqueCount="{len(_si_list)}">')
    for t in _si_list:
        sst.append(f"<si><t>{escape(t)}</t></si>")
    sst.append("</sst>")

    # 4. workbook.xml
    wb = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
          '<fileVersion appName="xl" lastEdited="7" lowestEdited="7"/>',
          '<workbookPr defaultThemeVersion="166925"/>',
          '<bookViews><workbookView xWindow="0" yWindow="0" windowWidth="20140" '
          'windowHeight="10960"/></bookViews>',
          '<sheets>',
          '<sheet name="人物主表" sheetId="1" r:id="rId1"/>',
          '<sheet name="言论库" sheetId="2" r:id="rId4"/>',
          '</sheets>',
          # PersonNames:言论库「人物姓名」下拉的来源(引用主表 B 列,名单超 255 字符无法内嵌)
          '<definedNames>',
          f'<definedName name="PersonNames">人物主表!$B$3:$B${2 + len(MAIN_ROWS)}</definedName>',
          '</definedNames>',
          '<calcPr calcId="191029"/>',
          '</workbook>']

    # 5. workbook.xml.rels
    rels = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">',
            '<Relationship Id="rId1" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet1.xml"/>',
            '<Relationship Id="rId2" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
            'Target="styles.xml"/>',
            '<Relationship Id="rId3" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" '
            'Target="sharedStrings.xml"/>',
            '<Relationship Id="rId4" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet2.xml"/>',
            '</Relationships>']

    # 6. [Content_Types].xml
    ct = ['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">',
          '<Default Extension="rels" '
          'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>',
          '<Default Extension="xml" ContentType="application/xml"/>',
          '<Override PartName="/xl/workbook.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
          '<Override PartName="/xl/worksheets/sheet1.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
          '<Override PartName="/xl/worksheets/sheet2.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
          '<Override PartName="/xl/styles.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>',
          '<Override PartName="/xl/sharedStrings.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>',
          '</Types>']

    writes = {
        "xl/worksheets/sheet1.xml": main_xml,
        "xl/worksheets/sheet2.xml": quote_xml,
        "xl/sharedStrings.xml": "\n".join(sst),
        "xl/workbook.xml": "\n".join(wb),
        "xl/_rels/workbook.xml.rels": "\n".join(rels),
        "[Content_Types].xml": "\n".join(ct),
    }
    for rel, content in writes.items():
        path = os.path.join(WORK, rel)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"wrote {rel} ({len(content)} chars)")

    print(f"sharedStrings: unique={len(_si_list)}, refs={_ref_count}")
    print("DONE")


if __name__ == "__main__":
    main()
