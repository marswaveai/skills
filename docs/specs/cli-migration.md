# Skills 仓库 CLI 迁移设计文档

Part of marswaveai/listenhub-ralph#44

## 背景

ListenHub CLI (`@marswave/listenhub-cli`) 已发布，提供完整的命令行工具覆盖所有内容创作功能。当前 skills 仓库中所有 skill 通过 curl + API 文档的方式调用后端，需要全面迁移到 CLI 调用方式。

## 目标

1. 新增 `slides` 和 `music` 两个 skill
2. 所有 skill 从 curl/API 调用迁移到 `listenhub` CLI 调用
3. 项目品牌从 "ListenHub Skills" 升级为 "ListenHub CLI Skills"
4. 新增 `listenhub-cli` 伞型 skill，替代已废弃的 `listenhub` skill

## 非目标

- 不迁移 `asr`（纯本地 SpeechBrain/Whisper，不涉及远端 API）
- 不迁移 `content-parser`（CLI 暂无 content-extract 命令，保留 curl 方式）
- 不改变用户交互流程（AskUserQuestion 收参 → 确认 → 执行的模式不变）

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

### 2.2 `/music` — AI 音乐生成

全新功能，CLI 命令 `listenhub music generate` 和 `listenhub music cover`。

**定位**：从文字描述生成原创音乐，或从参考音频创建翻唱版本。

**CLI 映射**：

| 子命令 | 功能 | 关键参数 |
|--------|------|----------|
| `music generate` | 文生音乐 | `--prompt`（必填）, `--style`, `--title`, `--instrumental` |
| `music cover` | 翻唱 | `--audio`（必填，本地文件或 URL）, `--prompt`, `--style`, `--title`, `--instrumental` |
| `music list` | 列表 | `--page`, `--page-size`, `--status` |
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
  --json
```

Two-step 流程：用 `--no-wait` 提交，`listenhub creation get <id> --json` 轮询文本，确认后用直接 API 提交音频（CLI 暂不支持 two-step 的第二步，保留 curl）。

### 3.2 `/tts`

```bash
listenhub tts create \
  --text "{text}" \
  --source-url "{url}" \
  --source-text "{text}" \
  --mode {smart|direct} \
  --lang {en|zh|ja} \
  --speaker "{name}" \
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
  --image-size {2K|4K} \
  --aspect-ratio {16:9|9:16|1:1} \
  --style "{style}" \
  --skip-audio \                  # 仅文本脚本
  --json
```

注意：explainer 的 `--skip-audio` 用于"仅文本脚本"模式，映射原来的 "Text script only" 选项。

### 3.4 `/image-gen`

```bash
listenhub image create \
  --prompt "{description}" \
  --model "{model}" \
  --aspect-ratio {16:9|9:16|1:1} \
  --size {1K|2K|4K} \
  --reference "{path-or-url}" \   # 可重复，最多 5 个
  --json
```

### 3.5 不迁移的 Skill

| Skill | 原因 |
|-------|------|
| `/asr` | 纯本地（SpeechBrain/Whisper），不调用远端 API |
| `/content-parser` | CLI 暂无 content-extract 命令 |
| `/creator` | 编排层，调用子 skill；子 skill 迁移后自动受益，但 creator 内部使用的 content-parser 仍走 curl |

---

## 四、shared/ 目录变更

### 4.1 新增文件

| 文件 | 内容 |
|------|------|
| `shared/cli-authentication.md` | CLI 安装检查 + `listenhub auth login/status` |
| `shared/cli-patterns.md` | CLI 执行模式：`--json` 输出解析、`--no-wait` 异步、`--timeout` 控制、错误处理 |
| `shared/cli-speakers.md` | `listenhub speakers list --json` 替代 curl speaker API |

### 4.2 保留不变的文件（仍被 content-parser / creator 使用）

| 文件 | 原因 |
|------|------|
| `shared/authentication.md` | content-parser 仍需 API Key |
| `shared/api-content-extract.md` | content-parser 使用 |
| `shared/api-speakers.md` | 保留为参考，但 CLI skill 不再直接引用 |
| `shared/config-pattern.md` | config 管理模式不变（outputMode/language/defaultSpeakers） |
| `shared/output-mode.md` | 输出模式选择不变 |
| `shared/common-patterns.md` | content-parser 的轮询仍需要 |
| `shared/speaker-selection.md` | 交互流程不变，只是底层查询改用 CLI |

### 4.3 保留但不再被 CLI skill 引用的文件

这些 API 文档保留在仓库中作为参考，但迁移后的 SKILL.md 不再引用：

- `shared/api-podcast.md`
- `shared/api-tts.md`
- `shared/api-image.md`
- `shared/api-storybook.md`

---

## 五、`listenhub-cli` 伞型 Skill

新增 `listenhub-cli/SKILL.md`，替代已废弃的 `listenhub/SKILL.md`。

**作用**：当用户触发通用 ListenHub 关键词时，路由到具体的子 skill。

```yaml
---
name: listenhub-cli
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

同时更新已废弃的 `listenhub/SKILL.md`，在路由表中补充 slides 和 music。

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

- `README.md` / `README.zh.md` 中的项目名称升级为 "ListenHub CLI Skills"
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
| 4 | 迁移 `/podcast` SKILL.md | 步骤 1 |
| 5 | 迁移 `/tts` SKILL.md | 步骤 1 |
| 6 | 迁移 `/explainer` SKILL.md | 步骤 1 |
| 7 | 迁移 `/image-gen` SKILL.md | 步骤 1 |
| 8 | 新增 `listenhub-cli/SKILL.md` + 更新 `listenhub/SKILL.md` | 步骤 2-7 |
| 9 | 更新 `shared/speaker-selection.md` 中的查询方式 | 步骤 1 |
| 10 | 更新 README | 步骤 2-8 |
| 11 | 更新 `creator/` 模板中引用（content-parser 不变，其余子 skill 引用更新） | 步骤 4-7 |

步骤 2-7 可并行执行。
