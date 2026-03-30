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

**website-fe 的 MDX 文档作为 API 代码示例的 single source of truth。**

skills 不再独立维护完整的 API 参考文档，改为引用 website-fe 的 MDX 作为权威来源。具体做法：

### 1. 重构 `shared/api-*.md`

将现有的完整 API 文档精简为 **agent 执行摘要**，只保留 AI agent 调用 API 时需要的关键信息：

- 端点路径、HTTP 方法
- 必填/选填参数表（保留，这是 agent 构造请求的关键）
- 一个精简的 curl 示例模板（保留 `X-Source: skills` header）
- 响应结构摘要（保留关键字段说明）

**删除**：与 website-fe 重复的详细说明文字、完整响应 JSON 示例等。

### 2. 在每个 `shared/api-*.md` 头部添加权威来源引用

```markdown
> **权威 API 文档**: 完整参数说明、多语言代码示例、错误码详情请参考
> [listenhub-website-fe](https://github.com/marswaveai/listenhub-website-fe) 的对应 MDX 文件。
> 本文件仅为 agent 执行摘要。
```

### 3. 建立引用映射关系

在每个 `shared/api-*.md` 中明确标注对应的 website-fe 文件路径：

```markdown
**对应 MDX**: `listenhub-website-fe/content/openapi/api-reference/flowspeech.mdx`
```

### 4. 创建 AGENTS.md

在 skills 仓库根目录创建 `AGENTS.md`，写入 single source of truth 规则，确保所有 agent（包括 Ralph）在修改 API 文档时遵守。

## AGENTS.md 规则内容

以下内容将写入 `skills/AGENTS.md`：

```markdown
## API 文档 Single Source of Truth

**listenhub-website-fe 的 MDX 文档是 API 代码示例的唯一权威来源。**

### 规则

1. `shared/api-*.md` 是 agent 执行摘要，不是完整 API 文档。修改 API 行为时，以 website-fe 的 MDX 为准。
2. 禁止在 `shared/api-*.md` 中添加与 website-fe 重复的详细代码示例或说明文字。
3. 如果发现 `shared/api-*.md` 与 website-fe MDX 内容不一致，以 website-fe 为准并修正 skills 侧。
4. 新增 API 端点时，先在 website-fe 创建 MDX 文档，再在 skills 中添加 agent 执行摘要。

### 映射关系

| skills `shared/` | website-fe 权威文档 |
|---|---|
| `api-tts.md` | `content/openapi/api-reference/flowspeech.mdx` |
| `api-podcast.md` | `content/openapi/api-reference/podcast.mdx` |
| `api-speakers.md` | `content/openapi/api-reference/speakers.mdx` |
| `api-content-extract.md` | `content/openapi/api-reference/content-extract.mdx` |
| `api-image.md` | `content/openapi/api-reference/image-generation.mdx` |
```

## 不改动的部分

- `shared/authentication.md` — 包含 skills 特有的认证流程（`X-Source: skills`），不与 website-fe 重复
- `shared/common-patterns.md` — agent 交互模式，skills 独有
- `shared/config-pattern.md`、`output-mode.md`、`speaker-selection.md` — agent 行为规范，skills 独有
- `SKILL.md` 中对 `shared/` 的引用方式不变

## 实现步骤

1. 创建 `AGENTS.md`，写入 single source of truth 规则和映射表
2. 重构每个 `shared/api-*.md`：精简为 agent 执行摘要，头部添加权威来源引用
3. 确保精简后的内容不丢失 agent 调 API 必需的信息（端点、参数表、curl 模板）

## 边界情况

- **api-storybook.md** 在 website-fe 没有对应 MDX，暂时保持原样，待 website-fe 补充后再迁移
- **新 API 端点**：规则要求先在 website-fe 建 MDX，但如果 website-fe 还没准备好，skills 可以先写临时文档并标注 `TODO: 待 website-fe 补充后迁移`

## 测试策略

- 重构后逐个 skill 手动测试 API 调用是否正常
- 验证 `SKILL.md` 引用路径仍然有效
- 检查 agent 执行摘要包含足够信息让 AI agent 成功构造 API 请求
