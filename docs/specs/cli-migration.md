# Skills 仓库 CLI 迁移设计文档

Part of marswaveai/listenhub-ralph#44

## 背景

ListenHub CLI (`@marswave/listenhub-cli`) 已发布，提供完整的命令行工具覆盖所有内容创作功能。当前 skills 仓库中所有 skill 通过 curl + API 文档的方式调用后端，需要全面迁移到 CLI 调用方式。

## 目标

1. 新增 `slides` 和 `music` 两个 skill
2. 所有 skill 从 curl/API 调用迁移到 `listenhub` CLI 调用
3. 新增 `listenhub-cli` 伞型 skill，同时将已废弃的 `listenhub` skill 恢复为与 `listenhub-cli` 完全一致的内容

## 非目标

- 不迁移 `asr`（纯本地 SpeechBrain/Whisper，不涉及远端 API）
- 不迁移 `content-parser`（CLI 暂无 content-extract 命令，保留 curl + API Key 方式）
- 不改变用户交互流程（AskUserQuestion 收参 → 确认 → 执行的模式不变）

## 关键约束：API 认证模型隔离

经调研 `listenhub-api-server`，OpenAPI 路由和 CLI/Regular 路由使用**完全隔离**的认证体系：

| 维度 | OpenAPI 路由 | CLI/Regular 路由 |
|------|-------------|-----------------|
| 认证方式 | API Key (`lh_sk_*`) | JWT（OAuth Token） |
| Token 格式 | `Bearer lh_sk_keyId_secret` | `Bearer <JWT>` |
| 验证方式 | bcrypt 哈希比对 | JWT 签名验证 |
| 端点访问 | 仅 `/openapi/v1/*` | 仅 `/api/*` |

**影响**：
- Podcast two-step（`POST /v1/podcast/episodes/text-content` + `POST /v1/podcast/episodes/{episodeId}/audio`）**仅注册在 OpenAPI 路由**，CLI 用户无法访问
- CLI 不发送 `X-Source` header（该 header 仅用于分析埋点，不影响鉴权）
- `content-parser` 和 `creator` 中使用 curl 的部分仍需 `LISTENHUB_API_KEY`

---

## 一、执行模型变更

### 1.1 认证：API Key → OAuth

| 维度 | 迁移前 | 迁移后 |
|------|--------|--------|
| 认证方式 | `LISTENHUB_API_KEY` 环境变量 | `listenhub auth login` OAuth |
| 检查方式 | 读 `$LISTENHUB_API_KEY` | `listenhub auth status --json` |
| 凭证存储 | 用户手动配 `.zshrc` | CLI 自动管理 `~/.config/listenhub/credentials.json` |
| Token 刷新 | 无（永久 key） | CLI 自动刷新 |

**迁移后的 Step -1（所有 skill 统一）：**

```bash
# 检查 CLI 是否安装
if ! command -v listenhub &>/dev/null; then
  echo "需要安装 ListenHub CLI: npm install -g @marswave/listenhub-cli"
  exit 1
fi

# 检查是否已登录
AUTH=$(listenhub auth status --json 2>/dev/null)
if [ "$(echo "$AUTH" | jq -r '.authenticated')" != "true" ]; then
  echo "请先登录: listenhub auth login"
  exit 1
fi
```

### 1.2 API 调用：curl → CLI 命令

| 维度 | 迁移前 | 迁移后 |
|------|--------|--------|
| 提交任务 | `curl -sS -X POST ...` 构造完整请求 | `listenhub <cmd> create --flag ...` |
| 轮询状态 | `run_in_background` bash 循环 + jq 解析 | CLI 内建轮询（默认行为） |
| 异步模式 | 无 | `--no-wait` 立即返回 ID |
| 结果解析 | jq 从 curl 响应提取字段 | `--json` 输出结构化 JSON |
| 超时控制 | `seq 1 30` + `sleep 10` 硬编码 | `--timeout <seconds>` |

**示例 — 播客生成：**

迁移前：
```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/podcast/episodes" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -H "X-Source: skills" \
  -d '{"sources": [...], "speakers": [...], "language": "zh", "mode": "quick"}'

# 然后用 background polling loop...
```

迁移后：
```bash
listenhub podcast create \
  --query "2026年AI趋势" \
  --mode quick \
  --lang zh \
  --speaker "原野" \
  --json
```

### 1.3 Speaker 查询

迁移前：
```bash
curl -sS "https://api.marswave.ai/openapi/v1/speakers/list?language=zh" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "X-Source: skills"
```

迁移后：
```bash
listenhub speakers list --lang zh --json
```

---

## 二、新增 Skill

### 2.1 `/slides` — 幻灯片生成

基于 storybook API 的 `slides` mode，CLI 命令 `listenhub slides create`。

**定位**：从主题/URL/文本生成幻灯片，可选语音旁白。与 `/explainer` 共用 storybook 后端但交互语义不同——slides 偏演示文稿，explainer 偏视频讲解。

**CLI 映射**：

| 参数 | CLI flag | 默认值 |
|------|----------|--------|
| 主题 | `--query` | — |
| 参考 URL | `--source-url`（可重复） | — |
| 参考文本 | `--source-text`（可重复） | — |
| 语言 | `--lang` | 自动检测 |
| 主播 | `--speaker` / `--speaker-id` | 内建默认 |
| 图片尺寸 | `--image-size` | 2K |
| 宽高比 | `--aspect-ratio` | 16:9 |
| 视觉风格 | `--style` | — |
| 跳过音频 | 默认跳过，`--no-skip-audio` 启用 | 跳过 |

**交互流程**：

1. 主题/内容（自由文本）
2. 语言（从输入推断，可覆盖）
3. 是否需要语音旁白（默认否）
4. 如需旁白 → Speaker 选择
5. 视觉风格（可选）
6. 确认 & 生成

**SKILL.md 参照**：以 `explainer/SKILL.md` 为模板，调整 mode 为 slides，默认跳过音频。

> **skip-audio 语义对比**：slides 默认跳过音频（加 `--no-skip-audio` 启用旁白），explainer 默认生成音频（加 `--skip-audio` 跳过）。交互流程中 slides 问"是否需要语音旁白？（默认否）"，explainer 问"输出类型？（文本脚本 / 文本+视频）"。

### 2.2 `/music` — AI 音乐生成

全新功能，CLI 命令 `listenhub music generate` 和 `listenhub music cover`。

**定位**：从文字描述生成原创音乐，或从参考音频创建翻唱版本。

**CLI 映射**：

| 子命令 | 功能 | 关键参数 |
|--------|------|----------|
| `music generate` | 文生音乐 | `--prompt`（必填）, `--style`, `--title`, `--instrumental` |
| `music cover` | 翻唱 | `--audio`（必填，本地文件或 URL）, `--prompt`, `--style`, `--title`, `--instrumental` |
| `music list` | 列表 | `--page`, `--page-size`, `--status`（可选值：`pending` / `generating` / `uploading` / `success` / `failed`） |
| `music get <id>` | 详情 | — |

**交互流程**：

1. 创作模式：原创 / 翻唱
2. （原创）音乐描述 prompt
3. （翻唱）参考音频文件或 URL
4. 风格（可选）
5. 标题（可选，可自动生成）
6. 是否纯音乐（无人声）
7. 确认 & 生成

**注意**：music 的超时时间较长（默认 600s），polling 间隔 10s。

---

## 三、现有 Skill 迁移

以下 skill 需要从 curl/API 迁移到 CLI 调用：

### 3.1 `/podcast`

| 项目 | 变更 |
|------|------|
| 认证 | API Key → CLI auth |
| 创建 | curl POST → `listenhub podcast create` |
| 轮询 | bash loop → CLI 内建等待 |
| Speaker | curl speakers API → `listenhub speakers list` |
| 参考 | `shared/api-podcast.md` → CLI `--help` |

**CLI 命令对应**：
```bash
listenhub podcast create \
  --query "{topic}" \
  --source-url "{url}" \          # 可重复
  --source-text "{text}" \        # 可重复
  --mode {quick|deep|debate} \
  --lang {en|zh|ja} \
  --speaker "{name}" \            # 可重复，最多 2 个
  --speaker-id "{id}" \           # 可重复，直接指定 speaker inner ID
  --json
```

**Two-step 流程移除**：Podcast two-step（先生成文本再生成音频）是 OpenAPI 专属功能，路由仅注册在 `openapi-controllers/episode.ts`，且只接受 API Key 认证。CLI 用户（OAuth/JWT）无法访问这些端点。迁移后 podcast skill 仅支持 one-step 模式，原 two-step 相关的交互步骤（Generation Method 选择、draft 预览、脚本编辑）全部移除。

### 3.2 `/tts`

```bash
listenhub tts create \
  --text "{text}" \
  --source-url "{url}" \
  --source-text "{text}" \
  --mode {smart|direct} \
  --lang {en|zh|ja} \
  --speaker "{name}" \
  --speaker-id "{id}" \
  --json
```

### 3.3 `/explainer`

```bash
listenhub explainer create \
  --query "{topic}" \
  --source-url "{url}" \
  --mode {info|story} \
  --lang {en|zh|ja} \
  --speaker "{name}" \
  --speaker-id "{id}" \
  --image-size {2K|4K} \
  --aspect-ratio {16:9|9:16|1:1} \
  --style "{style}" \
  --skip-audio \                  # 仅文本脚本
  --json
```

**skip-audio 语义**：explainer 默认**生成音频**（加 `--skip-audio` 跳过）。与 slides 相反——slides 默认**跳过音频**（加 `--no-skip-audio` 启用）。Skill 交互中需明确体现这一默认值差异。

### 3.4 `/image-gen`

```bash
listenhub image create \
  --prompt "{description}" \
  --model "{model}" \
  --lang "{lang}" \               # 提示词语言提示
  --aspect-ratio {16:9|9:16|1:1} \
  --size {1K|2K|4K} \
  --reference "{path-or-url}" \   # 可重复，最多 5 个，支持本地文件和 URL
  --json
```

### 3.5 不迁移的 Skill

| Skill | 原因 |
|-------|------|
| `/asr` | 纯本地（SpeechBrain/Whisper），不调用远端 API |
| `/content-parser` | CLI 暂无 content-extract 命令 |
| `/creator` | 编排层——调用子 skill 时读取子 skill 的 SKILL.md，子 skill 迁移后 creator 自动使用新的 CLI 执行方式。creator 模板中显式引用 shared/ 文档的地方需要更新（步骤 11）。creator 直接调用 content-parser 的部分走 content-parser 内联的 curl 方式 |

---

## 四、shared/ 目录变更

### 4.1 新增文件

| 文件 | 内容 |
|------|------|
| `shared/cli-authentication.md` | CLI 安装检查 + `listenhub auth login/status` |
| `shared/cli-patterns.md` | CLI 执行模式：`--json` 输出解析、`--no-wait` 异步、`--timeout` 控制、错误处理 |
| `shared/cli-speakers.md` | `listenhub speakers list --json` 替代 curl speaker API |

### 4.2 保留不变的文件

| 文件 | 原因 |
|------|------|
| `shared/config-pattern.md` | config 管理模式不变（outputMode/language/defaultSpeakers），移除其中的 API Key Check 章节 |
| `shared/output-mode.md` | 输出模式选择不变 |
| `shared/speaker-selection.md` | 交互流程不变，底层查询改用 `listenhub speakers list --json` |

### 4.3 删除旧 API 文档

以下文件全部删除：

- `shared/api-podcast.md`
- `shared/api-tts.md`
- `shared/api-image.md`
- `shared/api-storybook.md`
- `shared/api-content-extract.md`
- `shared/api-speakers.md`
- `shared/authentication.md`（API Key 认证，被 `shared/cli-authentication.md` 替代）
- `shared/common-patterns.md`（curl 轮询模式，被 `shared/cli-patterns.md` 替代）

**content-parser 内联处理**：`content-parser` 仍使用 curl + API Key（CLI 暂无 content-extract 命令），将其依赖的 API 信息（认证 header、端点地址、请求/响应格式、轮询模式）全部内联到 `content-parser/SKILL.md` 中，不再引用 `shared/` 目录。这样 `shared/` 可以干净地只包含 CLI 相关的文档。

---

## 五、`listenhub-cli` 伞型 Skill + `listenhub` 同步

新增 `listenhub-cli/SKILL.md`，同时将 `listenhub/SKILL.md` 更新为**完全一致**的内容（不再是废弃状态）。

两个 skill 内容相同，仅 frontmatter 的 `name` 字段不同（`listenhub-cli` vs `listenhub`）。这样无论用户安装的是哪个 skill name，都能获得同样的路由能力。

**作用**：当用户触发通用 ListenHub 关键词时，路由到具体的子 skill。

```yaml
---
name: listenhub-cli  # listenhub/SKILL.md 中为 name: listenhub
description: |
  ListenHub CLI skills 入口。当用户触发任何 ListenHub 相关操作时路由到对应 skill。
  触发词: "make a podcast", "explainer video", "read aloud", "TTS",
  "generate image", "做播客", "解说视频", "朗读", "生成图片",
  "幻灯片", "slides", "音乐", "music", "generate music".
---
```

**路由表**：

| 用户意图 | 路由到 |
|---------|--------|
| 播客 | `/podcast` |
| 讲解视频 | `/explainer` |
| 朗读 / TTS | `/tts` |
| 生成图片 | `/image-gen` |
| 幻灯片 | `/slides` |
| 音乐 | `/music` |
| 提取 URL 内容 | `/content-parser` |

---

## 六、SKILL.md 元数据变更

所有迁移后的 SKILL.md frontmatter 统一调整：

```yaml
# 迁移前
metadata:
  openclaw:
    emoji: "🎙️"
    requires:
      env: ["LISTENHUB_API_KEY"]
    primaryEnv: "LISTENHUB_API_KEY"

# 迁移后
metadata:
  openclaw:
    emoji: "🎙️"
    requires:
      bin: ["listenhub"]
    primaryBin: "listenhub"
```

- `requires.env` → `requires.bin`：从环境变量依赖改为二进制依赖
- `primaryEnv` → `primaryBin`：主要依赖标识

---

## 七、README 更新

- `README.md` / `README.zh.md` 项目名称保持 "ListenHub Skills" 不变
- 安装说明新增 CLI 安装步骤：`npm install -g @marswave/listenhub-cli`
- Skill 列表补充 slides 和 music
- 认证说明从 API Key 改为 OAuth

---

## 八、Config 模式保留

`.listenhub/<skill>/config.json` 的 config 管理模式保持不变：

- `outputMode`（inline/download/both）
- `language`
- `defaultSpeakers`
- skill 特有的默认值

变化点：
- 不再有 "Step -1: API Key Check" → 改为 "Step -1: CLI Auth Check"
- Speaker 查询从 curl 改为 `listenhub speakers list --json`
- 其余 config 读写、Zero-Question Boot、Setup Flow 逻辑不变

---

## 九、实现顺序

建议分步实施，降低一次性变更风险：

| 步骤 | 内容 | 依赖 |
|------|------|------|
| 1 | 新增 `shared/cli-authentication.md`、`shared/cli-patterns.md`、`shared/cli-speakers.md` | 无 |
| 2 | 新增 `/slides` SKILL.md | 步骤 1 |
| 3 | 新增 `/music` SKILL.md | 步骤 1 |
| 4 | 迁移 `/podcast` SKILL.md（移除 two-step，仅 one-step） | 步骤 1 |
| 5 | 迁移 `/tts` SKILL.md | 步骤 1 |
| 6 | 迁移 `/explainer` SKILL.md | 步骤 1 |
| 7 | 迁移 `/image-gen` SKILL.md | 步骤 1 |
| 8 | 内联 `/content-parser` SKILL.md（将 shared/ API 文档信息内联） | 无 |
| 9 | 新增 `listenhub-cli/SKILL.md` + 更新 `listenhub/SKILL.md` 为一致内容 | 步骤 2-7 |
| 10 | 更新 `shared/speaker-selection.md` 中的查询方式 | 步骤 1 |
| 11 | 删除旧 `shared/` API 文档（api-*.md、authentication.md、common-patterns.md） | 步骤 8 |
| 12 | 更新 `creator/` 模板中对 shared/ 的引用 | 步骤 4-7, 11 |
| 13 | 更新 `shared/config-pattern.md`（移除 API Key Check 章节） | 步骤 1 |
| 14 | 更新 README（品牌不变，补充 CLI 安装和新 skill） | 步骤 2-9 |

步骤 2-8 可并行执行。
