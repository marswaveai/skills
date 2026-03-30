# [Feature] 统一 API 文档代码示例 — Single Source of Truth

**Issue**: marswaveai/listenhub-ralph#32
**Repo**: skills
**Status**: Draft

---

## 问题

skills 仓库的 `shared/api-*.md` 维护了一套 API 文档（端点说明、参数表、curl 示例、响应示例），而 `listenhub-website-fe/content/openapi/` 的 MDX 文件维护了同一套 API 的完整文档（含 cURL / JavaScript / Python 多语言示例）。两边独立维护，内容重复且容易不一致。

### 重复文件对照

| skills `shared/` | website-fe `content/openapi/api-reference/` |
|---|---|
| `api-tts.md` | `flowspeech.mdx` |
| `api-podcast.md` | `podcast.mdx` |
| `api-speakers.md` | `speakers.mdx` |
| `api-content-extract.md` | `content-extract.mdx` |
| `api-image.md` | `image-generation.mdx` |
| `api-storybook.md` | (无直接对应) |

### 差异

- **skills**: 仅 curl 示例，面向 AI agent 执行，包含 `X-Source: skills` header
- **website-fe**: 多语言示例（cURL / JS / Python），面向开发者阅读，是用户文档的权威来源

## 方案

**listenhub.ai 线上文档是 API 接口说明的 single source of truth。skills 的 `shared/api-*.md` 必须与线上文档严格一致。**

### 线上文档 URL 规则

listenhub-website-fe 使用 Fumadocs + Next.js，MDX 文件到线上 URL 的映射：

```
content/openapi/{path}.mdx     → https://listenhub.ai/docs/en/openapi/{path}
content/openapi/{path}.zh.mdx  → https://listenhub.ai/docs/zh/openapi/{path}
```

### 核心要求：严格一致

`shared/api-*.md` 中的 API 接口说明（端点、参数、请求示例、响应结构）必须与对应的线上文档页面**严格一致**。具体来说：

- **端点路径、HTTP 方法**：必须与线上文档一致
- **参数表（字段名、类型、必填/选填、说明）**：必须与线上文档一致
- **curl 示例**：请求结构必须与线上文档的 cURL 示例一致（skills 可额外保留 `X-Source: skills` header）
- **响应结构和字段说明**：必须与线上文档一致

skills 的 `shared/api-*.md` 面向 AI agent 执行，所以格式可以不同（只保留 curl，不需要 JS/Python 多语言示例），但涉及 API 接口本身的内容不允许与线上文档有出入。

### 实现方式

#### 1. 在每个 `shared/api-*.md` 头部标注对应的线上文档地址

```markdown
> **权威来源**: https://listenhub.ai/docs/zh/openapi/api-reference/flowspeech
> **仓库文件**: `listenhub-website-fe/content/openapi/api-reference/flowspeech.mdx`
> 本文件的 API 接口说明必须与上述线上文档严格一致。
```

#### 2. 精简 `shared/api-*.md` 为 agent 执行摘要

保留 agent 调 API 必需的信息，删除与线上文档重复的大段说明文字：

- 保留：端点路径、参数表、curl 示例模板、响应结构摘要
- 删除：与线上文档重复的概念解释、使用建议等叙述性文字

#### 3. 创建 AGENTS.md

在 skills 仓库根目录创建 `AGENTS.md`，写入 single source of truth 规则和完整映射表。

### 映射关系

| skills `shared/` | 线上文档 | 仓库文件 |
|---|---|---|
| `api-tts.md` | [listenhub.ai/docs/zh/openapi/api-reference/flowspeech](https://listenhub.ai/docs/zh/openapi/api-reference/flowspeech) | `content/openapi/api-reference/flowspeech.mdx` |
| `api-podcast.md` | [listenhub.ai/docs/zh/openapi/api-reference/podcast](https://listenhub.ai/docs/zh/openapi/api-reference/podcast) | `content/openapi/api-reference/podcast.mdx` |
| `api-speakers.md` | [listenhub.ai/docs/zh/openapi/api-reference/speakers](https://listenhub.ai/docs/zh/openapi/api-reference/speakers) | `content/openapi/api-reference/speakers.mdx` |
| `api-content-extract.md` | [listenhub.ai/docs/zh/openapi/api-reference/content-extract](https://listenhub.ai/docs/zh/openapi/api-reference/content-extract) | `content/openapi/api-reference/content-extract.mdx` |
| `api-image.md` | [listenhub.ai/docs/zh/openapi/api-reference/image-generation](https://listenhub.ai/docs/zh/openapi/api-reference/image-generation) | `content/openapi/api-reference/image-generation.mdx` |

## 不改动的部分

- `shared/authentication.md` — 包含 skills 特有的认证流程（`X-Source: skills`），不与 website-fe 重复
- `shared/common-patterns.md` — agent 交互模式，skills 独有
- `shared/config-pattern.md`、`output-mode.md`、`speaker-selection.md` — agent 行为规范，skills 独有
- `SKILL.md` 中对 `shared/` 的引用方式不变

## 实现步骤

1. 创建 `AGENTS.md`，写入 single source of truth 规则、线上 URL 和仓库文件的完整映射表
2. 重构每个 `shared/api-*.md`：头部添加线上文档地址，精简为 agent 执行摘要
3. 逐个比对线上文档，确保 API 接口说明（端点、参数、示例、响应）严格一致
4. 确保精简后仍包含 agent 调 API 必需的信息（端点、参数表、curl 模板）

## 边界情况

- **api-storybook.md** 在线上文档没有对应页面，暂时保持原样，待线上文档补充后再纳入映射
- **新 API 端点**：先在 website-fe 创建 MDX 并部署上线，再在 skills 添加 agent 执行摘要
- **线上文档与仓库文件不同步**：以线上文档为准（线上 = 已部署 = 已生效）

## 测试策略

- 逐个对比 `shared/api-*.md` 与对应线上文档页面，确认接口说明严格一致
- 验证 `SKILL.md` 引用路径仍然有效
- 检查 agent 执行摘要包含足够信息让 AI agent 成功构造 API 请求
