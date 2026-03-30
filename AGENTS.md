# ListenHub Skills

AI 驱动的音频内容生成技能集合，包括播客、TTS、图片生成、内容解析等。

## 项目结构

- `shared/` — 共享文档（API 摘要、认证、交互模式等）
- `<skill>/SKILL.md` — 各技能的执行指令
- `<skill>/references/` — 技能的补充参考资料

## API 文档 Single Source of Truth

**listenhub.ai 线上文档是 API 接口说明的唯一权威来源。`shared/api-*.md` 必须与线上文档严格一致。**

### 规则

1. `shared/api-*.md` 中的 API 接口说明（端点、参数、请求示例、响应结构）必须与对应的线上文档页面严格一致
2. 格式可以不同（skills 只保留 curl，不需要 JS/Python），但接口内容不允许有出入
3. 发现不一致时，以线上文档为准并修正 skills 侧
4. 新增 API 端点时，先确认线上文档已有对应页面，再在 skills 添加 agent 执行摘要

### 映射表

| skills `shared/` | 线上文档 | 仓库文件 |
|---|---|---|
| `api-tts.md` | https://listenhub.ai/docs/zh/openapi/api-reference/flowspeech | `listenhub-website-fe/content/openapi/api-reference/flowspeech.mdx` |
| `api-podcast.md` | https://listenhub.ai/docs/zh/openapi/api-reference/podcast | `listenhub-website-fe/content/openapi/api-reference/podcast.mdx` |
| `api-speakers.md` | https://listenhub.ai/docs/zh/openapi/api-reference/speakers | `listenhub-website-fe/content/openapi/api-reference/speakers.mdx` |
| `api-content-extract.md` | https://listenhub.ai/docs/zh/openapi/api-reference/content-extract | `listenhub-website-fe/content/openapi/api-reference/content-extract.mdx` |
| `api-image.md` | https://listenhub.ai/docs/zh/openapi/api-reference/image-generation | `listenhub-website-fe/content/openapi/api-reference/image-generation.mdx` |

### URL 规则

线上文档 URL 映射：`content/openapi/{path}.mdx` → `https://listenhub.ai/docs/{lang}/openapi/{path}`（lang: en/zh）
