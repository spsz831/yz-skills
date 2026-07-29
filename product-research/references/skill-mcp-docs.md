# Skill/MCP 文档模板

> 名称：{skill-name}
> 类型：Skill / MCP Server
> 版本：{version}

---

## 1. 概述

### 功能简介

一句话说明这个 Skill/MCP 做什么。

### 使用场景

- 场景 1
- 场景 2
- 场景 3

---

## 2. 安装

### 前置要求

- Claude Code 版本
- 依赖工具

### 安装步骤

```bash
# 安装命令
claude skill install {skill-name}

# 或
npm install -g @mcp/{server-name}
```

### 配置

#### Claude Code 配置

```json
{
  "mcpServers": {
    "{server-name}": {
      "command": "npx",
      "args": ["-y", "@mcp/{server-name}"],
      "env": {
        "API_KEY": "your-api-key"
      }
    }
  }
}
```

---

## 3. 使用方式

### 基础用法

#### 方式 1：{场景名}

```bash
# 命令示例
```

#### 方式 2：{场景名}

```bash
# 命令示例
```

### 高级用法

#### 自定义配置

```json
{
  "option1": "value",
  "option2": "value"
}
```

---

## 4. API 参考

### 工具列表

| 工具名 | 说明 | 参数 |
|--------|------|------|
| `tool_name` | 功能描述 | 参数说明 |

### 工具详解

#### `tool_name`

**功能**

详细说明。

**参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| param1 | string | 是 | |
| param2 | number | 否 | |

**示例**

```javascript
// 调用示例
```

**返回值**

```json
{
  "result": "..."
}
```

---

## 5. 示例

### 示例 1：{场景名}

**需求**

描述要实现的目标。

**实现**

```bash
# 完整代码/命令
```

**结果**

说明输出。

### 示例 2：{场景名}
...

---

## 6. 开发指南

### 项目结构

```
src/
├── index.ts
├── tools/
│   ├── tool1.ts
│   └── tool2.ts
├── utils/
└── types/
```

### 开发环境

```bash
git clone {repo}
cd {project}
npm install
npm run dev
```

### 添加新工具

1. 在 `src/tools/` 创建文件
2. 实现工具接口
3. 在 `index.ts` 注册
4. 编写测试

### 测试

```bash
npm test
```

---

## 附录

### 常见问题

#### Q: {问题}
A: {答案}

### 更新日志

#### v1.0.0
- 初始发布
