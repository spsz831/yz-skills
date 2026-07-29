# 运行总结模板（Run Summary）

参考 deep-research V8，记录每次产品调研的执行情况，用于复盘和改进。

---

## 何时生成

每次完成产品调研后，在 `workspace/` 下生成 `run-summary.json`。

---

## 模板

```json
{
  "skill_version": "1.2.0",
  "timestamp": "2024-12-15T10:30:00Z",
  
  "product": {
    "name": "LibTV",
    "type": "AI视频创作平台",
    "company": "LiblibAI"
  },
  
  "output": {
    "type": "research-report",
    "word_count": 12000,
    "chapter_count": 11,
    "file": "libtv-ai-research-report.md"
  },
  
  "sources": {
    "total_count": 15,
    "official": 3,
    "third_party": 8,
    "social_media": 4,
    "average_score": 7.8,
    "core_sources": 12
  },
  
  "research_process": {
    "plan_created": true,
    "notes_generated": 5,
    "registry_created": true,
    "tension_discovery_applied": true,
    "quality_gates_passed": true
  },
  
  "search_metrics": {
    "web_search_count": 8,
    "web_fetch_count": 15,
    "browser_sessions": 2,
    "duplicate_searches": 1
  },
  
  "quality_metrics": {
    "citation_count": 45,
    "cross_validated_claims": 12,
    "unresolved_conflicts": 2,
    "limitations_documented": true
  },
  
  "evaluation": {
    "self_check_completed": true,
    "gates_passed": 5,
    "gates_failed": 0,
    "issues_found": [
      "定价信息来源单一，仅有官网数据"
    ]
  },
  
  "modules_used": {
    "structured_notes": true,
    "source_scoring": true,
    "conflict_handling": true,
    "tension_discovery": true,
    "quality_gates": true,
    "browser_testing": true
  },
  
  "lessons_learned": [
    "官方飞书文档需要浏览器实测才能获取完整内容",
    "竞品对比时发现即梦AI涨价信息对用户决策影响很大"
  ],
  
  "improvements_for_next_time": [
    "提前准备更多英文来源",
    "增加用户访谈类来源"
  ]
}
```

---

## 字段说明

### 基础信息
- `skill_version`: 使用的 product-research 技能版本
- `timestamp`: 调研完成时间（ISO 8601 格式）

### 产品信息
- `product.name`: 产品名称
- `product.type`: 产品类型
- `product.company`: 开发公司

### 输出信息
- `output.type`: 输出类型（research-report / product-article / competitive-analysis / industry-analysis / product-brief / opensource-docs / skill-mcp-docs）
- `output.word_count`: 报告字数
- `output.chapter_count`: 章节数
- `output.file`: 输出文件名

### 来源统计
- `sources.total_count`: 总来源数
- `sources.official`: 官方来源数
- `sources.third_party`: 第三方来源数
- `sources.social_media`: 社交媒体来源数
- `sources.average_score`: 平均来源评分
- `sources.core_sources`: 核心来源数（评分 ≥ 7）

### 调研过程
- `research_process.plan_created`: 是否创建研究计划
- `research_process.notes_generated`: 生成的笔记数
- `research_process.registry_created`: 是否创建来源清单
- `research_process.tension_discovery_applied`: 是否应用张力发现
- `research_process.quality_gates_passed`: 是否通过质量门控

### 搜索指标
- `search_metrics.web_search_count`: WebSearch 调用次数
- `search_metrics.web_fetch_count`: WebFetch 调用次数
- `search_metrics.browser_sessions`: 浏览器实测次数
- `search_metrics.duplicate_searches`: 重复搜索次数（应尽量减少）

### 质量指标
- `quality_metrics.citation_count`: 引用总数
- `quality_metrics.cross_validated_claims`: 交叉验证的论断数
- `quality_metrics.unresolved_conflicts`: 未解决的冲突数
- `quality_metrics.limitations_documented`: 是否记录局限性

### 评估结果
- `evaluation.self_check_completed`: 是否完成自检
- `evaluation.gates_passed`: 通过的门控数
- `evaluation.gates_failed`: 失败的门控数
- `evaluation.issues_found`: 发现的问题列表

### 使用的模块
- `modules_used.*`: 记录使用了哪些可选模块

### 经验教训
- `lessons_learned`: 本次调研的经验
- `improvements_for_next_time`: 下次改进建议

---

## 存档位置

```
workspace/
├── run-summary.json           # 运行总结
├── research-plan.md           # 研究计划
├── research-notes/            # 调研笔记
├── registry.md                # 来源清单
└── {product}-research-report.md  # 最终报告
```

---

## 用途

1. **复盘改进**：分析哪些步骤有效，哪些可以优化
2. **模式识别**：发现常见问题和改进机会
3. **质量追踪**：跟踪调研质量趋势
4. **知识积累**：记录经验教训供后续调研参考

---

## 简化版（简报/速览）

对于轻量级调研，可以使用简化版：

```json
{
  "skill_version": "1.2.0",
  "timestamp": "2024-12-15T10:30:00Z",
  "product": {"name": "LibTV"},
  "output": {"type": "product-brief", "word_count": 800},
  "sources": {"total_count": 5, "average_score": 7.2},
  "quality_gates_passed": true,
  "lessons_learned": ["快速调研时注意来源时效性"]
}
```
