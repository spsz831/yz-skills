# AI杨侦探插图可执行 Prompt 规则

> 当前规则版本：v8.1。v8.1 将插图规则从物件驱动收敛为内容驱动，并明确电脑、桌面和工作台不是默认元素。

## 文档目标

这份文档不是风格理念说明，而是给插图工作流、规划脚本、Prompt 生成器直接调用的执行规则。

目标有两个：

1. 把 AI杨侦探插图风格规范拆成稳定的 prompt 约束。
2. 让 `framework / comparison / flowchart / scene` 四类正文插图都能稳定生成，并默认回到浅底编辑图解，而不是叙事场景。

## 当前默认基线

- 默认原则：内容驱动。结构化图解、真实场景、人物、物件、数据关系或抽象图形由文章段落决定，不规定固定比例。
- 每张图先确定一个核心判断，再用必要的短标签、对照或步骤解释它；框架、对比、流程和分类图分别使用最适合自己的布局，不强制统一成信息板。
- 允许一个图内主标题、一条可选短副标题和一个可选底部结论区；标题可居中或根据核心物件左对齐，模块卡片、对照列和流程箭头共同服务一个判断，不照抄文章总标题，不塞段落或说明文字。
- 分类、对比和流程主题可以使用网格、分组卡片和对照列；要求清晰的阅读层级、稳定构图和足够信息密度。禁止通用仪表盘、SaaS 新手引导页、无阅读顺序的等尺寸卡片墙和无差别三等分对照栏。
- `scene`、电脑、桌面和工作台都不是默认元素；只有文章明确涉及真实使用场景时才使用。
- 保留清晰度约束：手机宽度可读、禁止模糊、假长文本、假引用、密集小字和泛化仪表盘。
- 允许暖奶油白的轻微纸面视觉感，但禁止可见颗粒、做旧、泛黄、磨损和水彩化。

## 通用 Prompt 六要素

每条插图提示词都应覆盖下面六个维度。它们是提示词的组织骨架，不是要求每张图都写成长段落：

1. **主体场景**：画什么，人物、物件、空间、关系、数据或抽象概念是什么。
2. **艺术风格**：统一使用浅底编辑型信息图；根据内容补充半写实场景、结构化图解、轻 3D 物件或简洁抽象表达。
3. **构图视角**：说明核心主体、阅读顺序、对照关系、流程方向、俯视/平视/近景或留白位置。
4. **色彩光线**：使用暖奶油底、墨绿结构色和一到两种语义强调色，说明光线和对比关系。
5. **氛围情绪**：根据文章选择冷静、可信、实用、克制、紧张、轻松、温暖或有判断力的情绪，不默认使用“未来科技感”。
6. **技术参数**：16:9、2K、公众号正文配图、移动端可读、文字区域和清晰度要求。

提示词还应包含必要的文字要求和负面约束，但不要为了“写完整”而堆砌无关形容词。六要素的优先级是：主体内容 > 构图关系 > 清晰度和文字 > 色彩氛围 > 装饰细节。

---

## 1. 固定系统指令

每张图的基础系统指令必须包含以下意思，允许做轻微措辞调整，但不允许改变约束方向。

```text
Create a premium editorial inline illustration for a WeChat article.
This is not a poster, not a cinematic concept art image, and not generic AI tech art.
The image should help readers quickly feel one core idea, scene, contrast, or conclusion.
Use a crisp semi-realistic digital editorial illustration with believable elements appropriate to the topic, clear spatial depth, and a readable editorial composition.
Target feeling: premium, clean, grounded, low-AI-look, magazine-quality WeChat inline illustration.
```

对应执行要求：

- 插图定位必须是 `公众号正文配图`
- 不是封面海报
- 不是情绪氛围图
- 不是纯图标集合
- 不是未来科技概念图

---

## 2. 固定视觉硬规则

以下规则属于强制项，每个 prompt 都必须显式写入或等价表达。

### 2.1 画幅与质量

```text
Aspect ratio: 16:9
Quality target: 2K
Usage: inline illustration for long-form article
```

### 2.2 风格主定义

```text
Style: crisp semi-realistic digital editorial illustration with clean deep-green linework and controlled realistic depth
Blend: structured editorial explanation with topic-appropriate visual elements; use light 3D objects only when they help explain the subject
Mood: premium, clean, grounded, editorial, low-AI-look
```

### 2.3 配色硬规则

```text
Background paper: #F6F1E8
Deep structure / outline: #27403A
Soft accent: #D8BFC5
Small copper highlight: #A56A43
Text / line neutral: #2B2B2B
```

对应执行要求：

- 大底必须是浅底，优先暖白、米白、纸面白
- `#27403A` 负责清晰、克制的手绘轮廓线、物件边界和阴影
- `#D8BFC5` 用于辅助物件、次重点区域和层次区分
- `#A56A43` 只作小面积的高光、关键标记或材质提亮
- 不允许高饱和冷色主导

### 2.3.1 颜色职责

基础色用于维持账号识别，强调色用于区分类别和关系，不能只把整张图染成一套棕绿颜色。

```text
Keep cream and deep green as the visual base.
Choose one or two semantic accent families per image: muted blue #6E9CCF for information, search, data, or connection; sage #779B86 for tools, workflow, or completion; amber #D6A447 for action, decision, or warning; coral #D98578 for creation, people, or contrast.
Use the selected accents consistently on category tabs, key task objects, or highlighted paths. Do not use all accent families in one image.
```

### 2.3.2 图标与任务物件

- 图标必须对应读者能理解的具体动作或产物，不使用抽象贴纸凑数量。
- 只有文章涉及工具或操作时，才使用编辑器、终端、文件、表格、接口连接器、画笔等物件；其他主题可以使用人物、环境、流程、数据关系或简洁符号。
- 每个任务物件应具备清晰外轮廓、轻厚度、有限材质和可识别动作；避免单纯的圆形符号、孤立拼图块或无语义装饰。

### 2.4 背景硬规则

```text
Background should feel like a clean, believable editorial setting, not refined paper or an abstract canvas.
Build a lightly tinted real-use environment with a clear ground plane, tabletop, wall plane, or product-experience space.
Use a cream base with two or three restrained powder-pink or copper-tan organic color fields; use no paper texture, grain, scratches, haze, or aging effect.
```

对应执行要求：

- 允许干净柔和渐层、可辨认的地面/桌面/墙面和克制的真实光影
- 允许灰粉或铜棕色块组织空间，但不能用柔雾、纸感或旧化纹理遮住边缘
- 背景细节必须明显弱于主体，但可形成与文章直接相关的产品体验、工作或使用现场
- 禁止纯白空背景
- 禁止窗景、书架、台灯、绿植齐全的泛化桌面场景，除非文章明确在讲该生活场景
- 不允许舞台感背景
- 不允许深空间透视背景

背景选择规则：

- 默认使用暖色底和少量有机色块；是否加入桌面、墙面、地面或真实环境，由文章内容决定。背景必须有插图感，但不能抢走信息主体。
- 只有文章明确讲一个生活或使用现场时，才使用简化场景背景；它必须承担信息，不能只是装饰。
- 彩色场景背景最多保留一个低矮地面或一个简化环境轮廓，不能变成风景画。

---

## 2.5 清晰度硬规则

每个 prompt 必须加入以下清晰度约束：

```text
Prioritize clean, high-legibility shapes over decorative texture.
Use medium-weight consistent outlines, crisp object edges, solid fills, and strong foreground-background separation.
Every core object and label must remain recognizable at mobile article width.
Keep focal objects, labels, and information-bearing props sharp even when the background uses subtle texture or soft shadow.
Avoid tiny icons, thin faint connectors, paper grain, distressed texture, blurred edges, soft focus, haze, and low-contrast beige-on-beige details.
```

执行要求：

- 图的重点是手机端一眼看懂，不是放大后的纹理。
- 主体物件、文字和关系线必须大、清楚、对比足够。
- 不为营造质感而牺牲线条、文字和物件边缘。
- 清晰不等于留空：一张图保留一个明确重点和必要的辅助信息即可，不规定固定物件数量。
- 辅助信息必须服务同一个核心判断，不能用无意义小图标和背景杂物凑密度。
- 文字标签必须是画面中的一级信息，不可做成很小、很浅的装饰字；标签与背景必须有足够明度和色相对比。
- 模型可使用细腻渐层、轻材质和柔和投影提升美观，但主体轮廓、文字和信息物件绝不能因此变糊。

---

## 3. 禁止项黑名单

以下内容建议作为固定 `AVOID:` 段落直接注入 prompt。

```text
Avoid dark blue backgrounds.
Avoid purple cyberpunk glow.
Avoid neon gradients and sci-fi lighting.
Avoid floating futuristic HUD panels.
Avoid fake future city scenes.
Avoid dense collage layouts.
Avoid complex mechanical robots.
Avoid realistic human faces.
Avoid poster-like cinematic drama.
Avoid screenshots, UI mock screenshots, logos, and watermarks.
Avoid glossy ecommerce 3D render look.
Avoid vintage paper, sepia wash, distressed metal, rusty machinery, exposed industrial pipes, conveyor-belt AI machines, and retro-factory aesthetics.
Avoid generic potted plants, coffee cups, bookshelves, desk lamps, or decorative desk clutter unless directly required by the article.
Avoid article-profile-inappropriate promotional or repeated visuals. For model-release articles, allow product-entry, official-showroom, launch-stage, giant-brand-wall, giant-model-name, or hero-chip imagery at most once.
```

额外解释：

- 不是完全禁止科技感，而是禁止“廉价 AI 科技感”
- 不是完全禁止 3D，而是禁止“主画面全变成渲染海报”

---

## 4. 构图与信息层级规则

所有 prompt 都应包含以下层级要求：

```text
Keep one clear core concept, expressed through the best-fit editorial structure: a framework, comparison, flow, categorized directory, or focused object story.
Use purposeful whitespace and one obvious focal point, but do not make the scene sparse.
Use one central subject plus four to six related, information-bearing props or states.
Allow free placement if the image stays clear and balanced.
Use cards, arrows, labels, zones, or structured blocks when they materially improve the reading order; do not use them as a generic SaaS template.
```

对应执行要求：

- 一张图只承载一个核心判断；分类图可有一个总结构和多个有明确分工的类别区
- 主体必须有一个清楚的阅读中心，不要求所有类别图都强行塞进单一物件
- 留白必须明显
- 标签必须服务理解，不是为了显得专业
- 小元素数量受控，避免满画面堆叠
- 不要默认做成左右模块板、上下流程板、中心结构板

---

## 5. 图中文字规则

所有正文插图默认使用少量物件化文字。文字不是标题，也不是正文替身，而是提升理解和信息密度的画面部件。

固定可执行规则：

```text
Do not repeat the full article title or section heading as a poster headline.
Use one concise image-specific Chinese title when it improves comprehension, and optionally one short subtitle of no more than 18 Chinese characters.
Use three to six short Chinese labels attached to important objects, paths, inputs, outputs, or states.
Keep each label to two to eight Chinese characters, except one optional numeric or model-name label.
Labels must be high-contrast and large enough to read on a mobile article, and must look like natural object labels rather than a layout title or caption.
Do not place paragraphs, long slogans, or explanatory copy inside the image. One short bottom conclusion strip is allowed when it summarizes the image's core judgment.
```

执行要求：

- 标签数量按内容决定，只保留能帮助理解的短标签；单个标签通常为 2 到 8 个汉字，可额外保留 1 个模型名或关键数字标签
- 禁止把整篇文章标题、段落标题、口号或长结论当成图中大字
- 默认使用顶部居中的短标题区；可有一条 18 字以内的短副标题和一个底部短结论区，但不得出现段落字幕或多条说明句
- 全文章统一字体规范：主标题使用现代中文杂志宋体/人文宋体风格；副标题、模块标签、按钮和屏幕文字使用清晰现代黑体/无衬线风格；英文产品名使用干净中性无衬线字体，官方 wordmark 仅在确有需要时使用
- 禁止书法体、毛笔字、篆体、卡通泡泡字、手写体、仿宋体混用、随机艺术字体和同一张图使用多套标题字体
- 每张图最多三种文字层级：主标题、短副标题/结论、模块标签；字号、字重和颜色在同一批图片中保持一致
- 生图模型无法可靠保证逐字准确和跨图字形一致。对标题、产品名、模型名和关键数字有硬性要求时，提示词应要求预留清晰文字区，生成后通过统一模板或后处理叠字完成最终文字
- 屏幕里只允许短标签、简短代码行、列表块、图表轮廓或结构化占位内容；禁止大段生成中文、论文引用、复杂公式、虚构数据来源和不可核验 UI 文案。
- 标签必须嵌入屏幕页签、文件封面、任务卡、笔记本或评估表，不使用悬浮牌、品牌墙、展厅招牌或舞台式字幕。

## 5.1 文章级去重规则

同一篇文章必须先选择 Visual Profile，再为每张图定义不同的叙事角色。Profile 负责文章类型的专用约束；产品入口、官网页、发布会大屏、品牌展厅整篇最多一张，只是 model-release Profile 的规则，不适用于所有文章。

无论 Profile 如何，都禁止在同一篇中重复同一间场景、同一组设备、同一人物姿势或同一中心构图。完整 Profile 定义见 docs\illustration-visual-profiles.md。

---

## 6. 轻 3D 物件白名单

当插图需要加入轻 3D 物件增强记忆点时，优先从白名单中选择。

建议白名单：

- 卡片
- 芯片
- 屏幕
- 控制台
- 模块盒子
- 标签牌
- 简洁设备
- 容器型结构块

执行要求：

- 物件数量少
- 轮廓完整
- 有轻厚度
- 有柔和阴影
- 有材料感，但不过分反光
- 物件只是辅助，不可盖过图解结构

---

## 7. 按类型执行的 Prompt 子模板

以下四类是项目目前常用的正文插图类型，不是完整分类。脚本生成 prompt 时，可以使用其中一个、组合多个，或针对新题材创建新的子模板；所有模板都必须回到“通用 Prompt 六要素”。

### 7.1 `framework`

适用场景：

- 分层结构
- 核心框架
- 模块关系
- 结论收束

固定附加规则：

```text
Build an editorial framework illustration with a clear core idea.
Use only the minimum structure needed to explain the point.
Avoid rigid stacked sections unless the article truly needs them.
Allow asymmetry and free placement if the image stays clear.
Keep the composition light, readable, and not template-like.
Use one large memorable visual anchor and a small number of varied supporting regions; do not turn the framework into an equal-card wall.
```

应有特征：

- 中心主体 + 模块分层
- 结构边界清楚
- 适合承接“文章核心判断”

禁止误差：

- 不能做成海报主视觉
- 不能只有一个物件没有结构解释

### 7.2 `comparison`

适用场景：

- 两条路径对比
- 两类人群对比
- 两种产品逻辑对比

固定附加规则：

```text
Build a comparison illustration that shows two contrasting paths, systems, or roles clearly.
Use left-right balance only if it feels natural.
Prefer scene-based contrast over rigid mirrored containers when possible.
Make differences obvious at a glance.
Keep one route or shared input visually dominant when the real relationship is asymmetric; avoid two identical columns with swapped labels.
```

应有特征：

- 左右镜像或准镜像结构
- 两边信息重量相对平衡
- 中间可有共同锚点或对照线

禁止误差：

- 不能左右失衡
- 不能把对比画成流程图

### 7.3 `flowchart`

适用场景：

- 机制过程
- 工作流
- 路径演进
- 判断链路

固定附加规则：

```text
Build a directional flow illustration.
Show a start, intermediate steps, and an outcome.
Use arrows, connectors, stages, or transitions clearly.
Keep the path readable in one viewing direction.
```

应有特征：

- 有起点、过程、结果
- 有明确箭头或方向
- 节点不宜过多

禁止误差：

- 不能画成静态对照板
- 不能没有方向性

### 7.4 `scene`

适用场景：

- 象征性定调图
- 关键概念具象化
- 单一主物件承载文章意象

固定附加规则：

```text
Build a believable human-scale product or work moment with a person or a small group using real screens, devices, documents, or physical objects.
Let posture, sightline, hand action, and spatial distance carry the idea.
Keep the environment specific to the article and visually clean, rather than abstractly technical or generically decorated.
Use three to five object-bound labels when they sharpen the story. A short centered title is allowed for the image's core idea; never use an explanatory paragraph.
```

应有特征：

- 有一个明确的小场景或动作
- 环境简洁，但看得出这是一个具体瞬间
- 不附加结构标签或结论标签

禁止误差：

- 不能完全变成情绪插画
- 不能变成纯 3D 展示图

---

## 8. 失败回退规则

当文章标题或段落语义不够清晰时，脚本应优先往“更稳的解释型图”回退，而不是放飞成氛围图。

默认回退顺序：

1. 优先回退到 `scene + framework`
2. 如果标题明显存在“两边对照”，回退到 `comparison`
3. 如果标题明显存在“步骤/路径/开始/到结果”，回退到 `flowchart`
4. 不在无法判断时默认回退到重模块框架板

Prompt 侧的回退表述建议：

```text
If the concept is ambiguous, prefer one concrete human-scale scene over a framework board.
If structure is needed, hide it inside object relationships and spatial arrangement; never turn it into a template-style explainer panel.
```

---

## 9. 标准 Prompt 骨架

项目脚本生成 prompt 时，建议固定为以下骨架顺序：

1. 元数据头部
2. 任务定义
3. `STYLE DIRECTION`
4. `PALETTE`
5. `COMPOSITION`
6. `TYPE TEMPLATE`
7. `TEXT`
8. `OBJECT GUIDANCE`
9. `AVOID`
10. `FAILSAFE`
11. `OUTPUT`

推荐骨架示意：

```text
Create a premium editorial inline illustration for a WeChat article.

STYLE DIRECTION:
- ...

PALETTE:
- ...

COMPOSITION:
- ...

TYPE TEMPLATE:
- ...

LABELS:
- ...

OBJECT GUIDANCE:
- ...

AVOID:
- ...

FAILSAFE:
- ...

OUTPUT:
- 16:9
- 2K
- suitable for article inline placement
```

---

## 10. 验收检查清单

生成后用以下检查项快速验收。

### 10.1 基础通过项

- 是否为浅底叙事编辑插画，而不是图解板
- 是否明显避开深蓝紫赛博感
- 是否存在清晰信息层级
- 是否符合 `16:9` 与 `2K`
- 是否适合作为公众号正文配图

### 10.2 结构通过项

- 是否在解释一个明确关系，而非制造纯氛围
- 是否主次清楚、焦点明确
- 是否有足够留白
- 是否使用了一个有层级的短标题，而非整篇文章标题、说明文字或多余标签

### 10.3 品牌通过项

- 是否比常见 AI 科技图更克制
- 是否具备编辑感、质感、判断感
- 是否保留了 `AI杨侦探` 的浅底品牌气质

若以上任意 3 项不满足，则该图不应直接回填文章。

---

## 11. 项目落地要求

脚本与工作流层面应遵守以下约束：

1. 规划脚本必须把这份规则显式写进 prompt，不依赖隐式默认值。
2. 每张图都必须产出独立 prompt 文件，供追溯与复跑。
3. 规划结果必须保留类型信息，便于后续校验 prompt 是否匹配。
4. 同一篇文章的插图资产继续按文章级目录归档。

---

## 12. 一句话执行版

`AI杨侦探` 正文插图的可执行 prompt 规则是：

**浅底编辑信息图解：一个核心判断、统一的标题与副标题层级、三到八个可读短标签和可选底部结论区；使用现代中文杂志宋体标题、清晰黑体标签，配合奶油白、墨绿、灰粉与少量铜棕，在手机端保持清楚、美观且有信息量。**
