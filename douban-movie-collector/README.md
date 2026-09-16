# douban-movie-collector

个人影视收藏管理 Skill，配套 Excel 收藏表，支持电影、电视剧、迷你剧、综艺和纪录片。

当前版本：`v1.2.0`

## 能做什么

- 追加或更新影视收藏
- 核对年份、类型、导演、豆瓣评分和豆瓣 ID
- 自动区分电影与电视剧工作表
- 支持集数、季数、观看状态和备注
- 网盘链接、豆瓣链接自动生成可点击超链接
- 检查重复片名、缺少评分、缺少集数和异常链接
- 将收藏表同步到个人 GitHub 私有仓库

## 换电脑首次使用

先登录 GitHub，并确保账号有私有仓库 `spsz831/movie-collection` 的访问权限。

```powershell
git clone https://github.com/spsz831/yz-skills.git
python yz-skills/douban-movie-collector/scripts/setup_movie_collection.py
```

初始化脚本会自动：

1. 定位当前电脑的 Codex skills 目录。
2. 安装最新 `douban-movie-collector`。
3. 克隆个人影视收藏私有仓库。
4. 将最新 Excel 表格放入 skill 的 `examples` 目录。

如果需要自定义路径：

```powershell
python setup_movie_collection.py `
  --skills-dir "你的 Codex skills 目录" `
  --collection-dir "你的 movie-collection 仓库目录"
```

## 日常使用

收藏电影或电视剧时，直接对 Codex 说：

```text
收藏电影《电影名称》
链接：https://pan.quark.cn/s/xxxxx
```

继续收藏时始终使用同一份正式 Excel 表格，不新建副本。

## 数据检查

```powershell
python audit_movie_collection.py `
  --xlsx "正式收藏表路径" `
  --check-links
```

可检查重复片名、缺少评分、缺少链接、缺少集数/季数和无法访问的链接。

## 同步 GitHub

```powershell
python sync_movie_collection.py
```

脚本会自动定位收藏表和私有仓库。若本地仓库存在未提交修改，会停止同步，避免覆盖本地内容。也可以手动指定路径：

```powershell
python sync_movie_collection.py `
  --xlsx "正式收藏表路径" `
  --repo "movie-collection 仓库路径"
```

## 观看状态

支持四种状态：

- `想看`
- `已看`
- `弃看`
- `重看`

表格中可通过下拉选项修改，状态单元格会使用不同颜色标记。
