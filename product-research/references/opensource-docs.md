# 开源项目文档模板

> 项目名称：{name}
> 版本：{version}
> 许可证：{license}

---

## README.md

### 项目标题

一句话描述项目用途。

### ✨ 特性

- 特性 1
- 特性 2
- 特性 3

### 🚀 快速开始

#### 安装

```bash
# 方式 1
npm install {package}

# 方式 2
yarn add {package}
```

#### 基础用法

```javascript
// 代码示例
```

### 📖 文档

详细文档链接。

### 🤝 贡献

欢迎贡献！查看 [CONTRIBUTING.md](./CONTRIBUTING.md)。

### 📄 许可证

[MIT](./LICENSE)

---

## docs/getting-started.md

### 安装

#### 前置要求
- Node.js >= 18
- npm >= 8

#### 安装步骤
1. 
2. 
3. 

### 配置

#### 基础配置

```json
{
  "key": "value"
}
```

#### 高级配置
| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| | | | |

### 第一个项目

从零开始创建一个示例项目。

---

## docs/guide.md

### 核心概念

#### 概念 1
解释 + 示例。

#### 概念 2
解释 + 示例。

### 工作流程

```
步骤 1 → 步骤 2 → 步骤 3
```

### 最佳实践

#### 性能优化
1. 
2. 
3. 

#### 代码组织
建议的项目结构。

---

## docs/api.md

### API 参考

#### `methodName()`

```typescript
function methodName(param: string): ReturnType
```

**参数**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| param | string | 是 | |

**返回值**

返回类型说明。

**示例**

```javascript
// 示例代码
```

---

## docs/examples.md

### 示例集合

#### 示例 1：{场景名}

**需求**
**实现**
**代码**

#### 示例 2：{场景名}
...

---

## CONTRIBUTING.md

### 如何贡献

#### 报告 Bug
使用 [Issue 模板]()。

#### 提交 PR
1. Fork 仓库
2. 创建分支：`git checkout -b feature/xxx`
3. 提交更改：`git commit -m 'feat: add xxx'`
4. 推送分支：`git push origin feature/xxx`
5. 创建 Pull Request

#### 代码规范
- 使用 ESLint/Prettier
- 提交前运行测试：`npm test`
- 遵循 [Conventional Commits](https://www.conventionalcommits.org/)

### 开发环境搭建

```bash
git clone {repo}
cd {project}
npm install
npm run dev
```

### 项目结构

```
src/
├── index.ts
├── core/
├── utils/
└── types/
```

---

## CHANGELOG.md

### [Unreleased]

#### Added
- 

#### Changed
- 

#### Fixed
- 

### [1.0.0] - {YYYY-MM-DD}

#### Added
- 初始发布
