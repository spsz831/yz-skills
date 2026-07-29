# 素材命名与归档规范

## 文件命名规则

### 基本原则

1. **统一前缀**：`{product}-` 开头
2. **小写连字符**：使用 `-` 连接单词
3. **类型后缀**：明确文件类型
4. **来源标识**：第三方素材标注来源

### 命名模板

```
{product}-{type}[-{source}].md
```

### 示例

#### 官方素材
- `libtv-official.md` - 官网
- `libtv-docs.md` - 官方文档
- `libtv-homepage.md` - 首页截图
- `libtv-pricing.md` - 定价页

#### 第三方评测
- `libtv-review-zhihu.md` - 知乎评测
- `libtv-review-sohu.md` - 搜狐评测
- `libtv-review-bestblogs.md` - BestBlogs评测

#### 社交媒体
- `libtv-social-weibo.md` - 微博
- `libtv-social-twitter.md` - Twitter/X

#### 最终报告
- `libtv-research-report.md` - 调研报告（标准命名）
- `libtv-research-report-v2.md` - 第二版
- `libtv-competitive-analysis.md` - 竞品对比
- `libtv-product-brief.md` - 产品简报

## 目录结构

### 标准结构

```
workspace/
├── {product}-official.md           # 官网
├── {product}-guide.md              # 官方文档
├── {product}-homepage.md           # 首页截图
├── {product}-review-{source}.md    # 评测文章
├── {product}-social.md             # 社交媒体
├── {product}-research-report.md    # 最终报告
└── images/                         # 截图和图片
    ├── {product}-homepage.png
    └── {product}-pricing.png
```

### 实际案例

```
语雀内容分类/
├── libtv-01-official.md
├── libtv-02-guide.md
├── libtv-03-github.md
├── libtv-04-dreamina-review.md
├── libtv-05-pexo.md
├── libtv-06-zhihu1.md
├── libtv-07-sohu.md
├── libtv-08-bestblogs.md
├── libtv-09-zhihu2.md
├── libtv-homepage.md
├── libtv-ai-research-report.md
└── workspace/
    └── libtv-notes.md
```

## 命名约定

### 产品名标准化

| 实际名称 | 标准命名 | 说明 |
|----------|----------|------|
| LibTV | `libtv` | 全小写 |
| Runway ML | `runway` | 去掉 ML |
| Pika Labs | `pika` | 去掉 Labs |
| 可灵 AI | `kling` | 用英文 |
| 即梦 AI | `jimeng` | 拼音 |
| BrowserAct | `browseract` | 全小写 |
| Tableau | `tableau` | 全小写 |

### 来源标识

| 来源 | 标识 | 示例 |
|------|------|------|
| 知乎 | `zhihu` | `libtv-zhihu.md` |
| 搜狐 | `sohu` | `libtv-sohu.md` |
| BestBlogs | `bestblogs` | `libtv-bestblogs.md` |
| 36氪 | `36kr` | `libtv-36kr.md` |
| 极客公园 | `geekpark` | `libtv-geekpark.md` |

### 版本管理

- **第一版**：`{product}-research-report.md`
- **第二版**：`{product}-research-report-v2.md`
- **第三版**：`{product}-research-report-v3.md`

## 归档检查清单

### 收集阶段

- [ ] 所有素材统一命名
- [ ] 标注来源和日期
- [ ] 分类存放（官方/第三方/社交）

### 调研阶段

- [ ] 工作笔记存放到 `workspace/`
- [ ] 截图存放到 `images/`
- [ ] 临时文件及时清理

### 完成阶段

- [ ] 最终报告使用标准命名
- [ ] 删除或归档临时文件
- [ ] 整理目录结构

## 常见问题

### Q: 素材太多怎么命名？

A: 
1. 使用序号：`libtv-01-zhihu.md`, `libtv-02-zhihu.md`
2. 按日期：`libtv-20240101-zhihu.md`
3. 按主题：`libtv-pricing-zhihu.md`, `libtv-feature-zhihu.md`

### Q: 多个评测来自同一平台？

A: 
- 加序号：`libtv-zhihu1.md`, `libtv-zhihu2.md`
- 加作者：`libtv-zhihu-author1.md`, `libtv-zhihu-author2.md`

### Q: 需要保留原始文件名吗？

A: 
- 不需要，统一按规范重命名
- 在文件开头注明原始来源和 URL

## 最佳实践

1. **及时重命名**：下载后立即按规范命名
2. **保持简洁**：文件名不要太长
3. **一致性强**：同类素材使用相同模式
4. **便于搜索**：使用关键词（如 `pricing`, `feature`）
5. **版本清晰**：明确标注版本号
