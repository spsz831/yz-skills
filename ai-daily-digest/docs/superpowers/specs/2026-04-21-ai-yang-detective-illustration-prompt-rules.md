# AI杨侦探插图可执行 Prompt 规则

## 文档目标

这份文档不是风格理念说明，而是给插图工作流、规划脚本、Prompt 生成器直接调用的执行规则。

目标有两个：

1. 把 `AI杨侦探插图风格规范 v1` 拆成稳定的 prompt 约束。
2. 让 `framework / comparison / flowchart / scene` 四类正文插图都能按固定骨架生成，避免再次漂回通用 AI 科技图风格。

---

## 1. 固定系统指令

每张图的基础系统指令必须包含以下意思，允许做轻微措辞调整，但不允许改变约束方向。

```text
Create a premium editorial inline illustration for a WeChat article.
This is not a poster, not a cinematic concept art image, and not generic AI tech art.
The image must help readers understand a structure, comparison, mechanism, or conclusion.
Use a light editorial explainer style mixed with a small amount of light 3D object presence.
Target feeling: premium, structured, restrained, low-AI-look, magazine-quality explainer graphic.
```

对应执行要求：

- 插图定位必须是 `公众号正文解释图`
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
Style: light editorial explainer
Blend: 70% diagram / 30% light 3D object scene
Mood: premium, calm, structured, intelligent, restrained
```

### 2.3 配色硬规则

```text
Background: #F6F1E8
Structure color: #27403A
Soft accent: #D8BFC5
Small highlight accent: #A56A43
Text neutral: #2B2B2B
```

对应执行要求：

- 大底必须是浅底，优先暖白、米白、纸面白
- `#27403A` 负责结构骨架、边界、重点模块
- `#D8BFC5` 负责辅助卡片、次重点区域、层次区分
- `#A56A43` 只能少量用于标签、结论点、按钮式强调
- 不允许高饱和冷色主导

### 2.4 背景硬规则

```text
Background should feel like refined paper or editorial canvas.
Allow only subtle gradient, subtle paper texture, faint shadows, or very light structural pattern.
```

对应执行要求：

- 允许极轻纸感、极淡颗粒、极淡渐层
- 不允许舞台感背景
- 不允许深空间透视背景

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
```

额外解释：

- 不是完全禁止科技感，而是禁止“廉价 AI 科技感”
- 不是完全禁止 3D，而是禁止“主画面全变成渲染海报”

---

## 4. 构图与信息层级规则

所有 prompt 都应包含以下层级要求：

```text
Keep one clear core concept.
Use strong hierarchy and generous whitespace.
Limit the number of objects and modules.
Make the focal point obvious within one second.
Use cards, arrows, labels, zones, and structured blocks when needed.
```

对应执行要求：

- 一张图只解释一个核心判断
- 主体只能有一个视觉中心
- 留白必须明显
- 标签必须服务结构，不是装饰
- 小元素数量受控，避免满画面堆叠

---

## 5. 中文标签规则

所有正文插图默认采用中文优先标签。

固定可执行规则：

```text
Use Chinese-first labels.
Keep labels short, structural, and readable.
Use only keywords, conclusion words, module names, or contrast labels.
Do not place long paragraphs inside the image.
```

执行要求：

- 标签长度优先控制在 2 到 8 个汉字
- 优先使用模块词、结论词、关系词
- 可以少量出现英文术语，但不能喧宾夺主
- 不能出现密集小字说明

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

以下四类是项目默认正文插图类型。脚本生成 prompt 时，必须按类型附加不同子规则。

### 7.1 `framework`

适用场景：

- 分层结构
- 核心框架
- 模块关系
- 结论收束

固定附加规则：

```text
Build a layered editorial framework graphic.
Use one central structure with surrounding modules or stacked sections.
Show hierarchy, boundaries, and one key conclusion.
Prefer cards, containers, zones, labels, and structured grouping.
Keep the composition stable, balanced, and easy to scan.
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
Build a left-right comparison layout with mirrored balance.
Show two contrasting paths, systems, or roles clearly.
Use matching containers, contrast labels, and a shared comparison anchor.
Make differences obvious at a glance.
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
Build a minimal symbolic scene with one main object or one small group of objects.
Keep the environment abstract and restrained.
Retain diagram-like labels or structural hints so the image still explains rather than only atmospheres.
```

应有特征：

- 单一主物件
- 环境极简
- 仍然保留结构标签或结论标签

禁止误差：

- 不能完全变成情绪插画
- 不能变成纯 3D 展示图

---

## 8. 失败回退规则

当文章标题或段落语义不够清晰时，脚本应优先往“更稳的解释型图”回退，而不是放飞成氛围图。

默认回退顺序：

1. 优先回退到 `framework`
2. 如果标题明显存在“两边对照”，回退到 `comparison`
3. 如果标题明显存在“步骤/路径/开始/到结果”，回退到 `flowchart`
4. 不在无法判断时默认回退到 `scene`

Prompt 侧的回退表述建议：

```text
If the concept is ambiguous, prefer a structured framework graphic over a mood-based scene.
If a scene is used, keep it minimal and still anchored by labels and structural cues.
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
7. `LABELS`
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

- 是否为浅底编辑图解风
- 是否明显避开深蓝紫赛博感
- 是否存在清晰信息层级
- 是否符合 `16:9` 与 `2K`
- 是否适合作为公众号正文配图

### 10.2 结构通过项

- 是否在解释一个明确关系，而非制造纯氛围
- 是否主次清楚、焦点明确
- 是否有足够留白
- 是否标签简短可读

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

**浅底编辑图解风 + 少量轻 3D 物件，优先解释结构、对比、流程与结论，使用奶油白、墨绿、灰粉、少量铜棕，避免深蓝紫赛博感、霓虹感、海报感与通用 AI 图感。**
