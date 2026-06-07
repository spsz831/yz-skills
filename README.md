# YZ Skills

我自己常用的一些 AI Skills，按可直接安装、可独立维护的结构整理在这里。

这个仓库只收 `skill` 相关内容，不收完整应用项目、不收运行产物、不收本机调试缓存。

## Skills

### `szxs-gzh`

四知先生公众号日更工作流。

适用场景：

- 生成四知先生公众号每日黄历文章初稿
- 人工修正生肖顺序、电影位、宜忌、排版后输出 `final_markdown`
- 基于最终稿生成双人播客逐字稿

目录：

- [szxs-gzh](./szxs-gzh/)
- [szxs-gzh-docs](./szxs-gzh-docs/)

### `zhen-fmt`

固定角色、固定气质的一致性插画生成 skill。

适用场景：

- 基于固定人物参考图生成新场景插画
- 生成个人日系氛围插画风提示词
- 调用 Gemini 跑图并保存本地输出

目录：

- [zhen-fmt](./zhen-fmt/)

### `ai-daily-digest`

AI 日报 / 公众号稿 / 插图规划 / 定稿发布链路 skill。

适用场景：

- 跑日报
- 把日报转成公众号稿
- 规划并生成插图
- 整理插图归档
- 输出可发布的最终文章

目录：

- [ai-daily-digest](./ai-daily-digest/)
- [ai-daily-digest-docs](./ai-daily-digest-docs/)

## 当前仓库结构

```text
yz-skills/
├─ README.md
├─ LICENSE
├─ .gitignore
├─ szxs-gzh/
├─ szxs-gzh-docs/
├─ zhen-fmt/
├─ ai-daily-digest/
└─ ai-daily-digest-docs/
```

## 目录约定

### skill 目录

一个 skill 一个目录，通常包含：

- `SKILL.md`
- `references/`
- `config/`
- `prompt-modules/`
- `scripts/`
- `tests/`
- `examples/`
- `templates/`

不是每个 skill 都必须包含以上全部目录，以实际需要为准。

### `*-docs` 目录

如果某个 skill 还有项目级说明、日常操作说明、AGENTS 规则文件，就单独放在 `*-docs/` 目录中，避免和 skill 本体混在一起。

## 安装方式

在支持 Skill 的 Agent 里直接说：

```text
帮我安装这个 skill：
https://github.com/<your-name>/yz-skills/tree/main/<skill-name>
```

例如：

```text
帮我安装这个 skill：
https://github.com/<your-name>/yz-skills/tree/main/szxs-gzh
```

## 仓库原则

- 一个 skill 一个目录
- 每个 skill 目录只放和它自己有关的内容
- 只有在本地真实用过、可复用的 skill 才收进来
- 不收 `.env`、运行产物、调试截图、缓存目录
- 不把完整应用项目混进 skill 仓库
