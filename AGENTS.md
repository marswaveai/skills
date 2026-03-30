# ListenHub Skills

AI 驱动的音频内容生成技能集合，包括播客、TTS、图片生成、内容解析等。

## 项目结构

- `shared/` — 共享文档（API 摘要、认证、交互模式等）
- `<skill>/SKILL.md` — 各技能的执行指令
- `<skill>/references/` — 技能的补充参考资料

## API 文档 Single Source of Truth

**`listenhub-website-fe` 仓库的 MDX 文档是 API 代码示例和端点说明的唯一权威来源。**

`shared/api-*.md` 只是面向 AI agent 的执行摘要（端点、参数表、curl 模板），不是完整 API 文档。

### 规则

1. 修改 API 行为相关内容时，以 `listenhub-website-fe` 的 MDX 为准
2. 禁止在 `shared/api-*.md` 中添加与 website-fe 重复的详细代码示例或大段说明文字
3. 发现 `shared/api-*.md` 与 website-fe MDX 不一致时，以 website-fe 为准并修正 skills 侧
4. 新增 API 端点时，先确认 website-fe 已有对应 MDX 文档，再在 skills 添加 agent 执行摘要

### 文件映射

| skills `shared/` | website-fe 权威文档路径 |
|---|---|
| `api-tts.md` | `content/openapi/api-reference/flowspeech.mdx` |
| `api-podcast.md` | `content/openapi/api-reference/podcast.mdx` |
| `api-speakers.md` | `content/openapi/api-reference/speakers.mdx` |
| `api-content-extract.md` | `content/openapi/api-reference/content-extract.mdx` |
| `api-image.md` | `content/openapi/api-reference/image-generation.mdx` |
