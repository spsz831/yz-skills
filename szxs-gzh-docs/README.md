# szxs-gzh

`szxs-gzh` 是四知先生公众号日更内容的本地工作仓库。

这个仓库当前主要保存：

- 项目级规则文件
- 历史参考归档
- 与 `szxs-gzh` skill 配套的本地工作结构

这个仓库当前不再保存日更生成产物本身，例如：

- `*-draft_markdown.md`
- `*-final_markdown.md`
- `*-podcast_script.md`
- 浏览器调试日志与临时抓取文件

这些文件保留在本地工作目录中，但已通过 `.gitignore` 排除，不会再推送到 GitHub。

## 当前目录说明

- `AGENTS.md`
  - 项目级工作规则
  - 约束 51 / cikeee / 生肖校正 / 定稿校验流程

- `wechat-cover/`
  - 四知先生公众号文章封面相关模板
  - 当前包含 `weixin-cover-template.html`

- `repo/szxs-gzh/`
  - 历史归档目录
  - 保存早期 skill 交付资料、版本说明、测试说明、旧参考文件

- `.gitignore`
  - 排除本地生成稿、临时快照、Playwright 调试文件

## 当前 Git 策略

- 以本地工作目录为准维护仓库
- 生成型日更内容默认不入库
- 浏览器缓存、抓取快照、临时 HTML/TXT/PNG 不入库
- 仓库重点保存规则、结构、归档和必要说明

## 说明

当前真正生效的 `szxs-gzh` skill 不在本仓库内运行，而是在全局 skill 目录中维护。  
本仓库里的内容主要用于项目规则管理、本地工作流承载和历史资料留存。
