# 272 — Seed-Audio-1.0 下游同步（skills）

## 目标

上游 `listenhub-api-server` 上线 Seed-Audio-1.0 端到端音频（3 个对外端点）。在 skills 仓
新建 `/seed-audio` skill 并把两个 router（`/listenhub`、`/listenhub-cli`）的路由表与
AskUserQuestion 选项接上，使 seed-audio 可被发现和调用。

## 契约事实源（只读，已核对）

- `src/openapi-controllers/seed-audio.ts` — 3 个对外端点 + 限流 60s/5 次
- `src/service/seed-audio/request.ts` — generateRequestSchema（Joi 单一事实源）
- `src/service/seed-audio/index.ts` § sanitizeTaskForResponse — 响应脱敏 + 5 态对外映射
- `api-docs/listenhub.yaml` — `/v1/seed-audio/*` paths（10573+）、SeedAudioTask schema（12599）

## 覆盖范围

只覆盖 3 个对外端点：

| 端点 | 用途 |
|------|------|
| POST `/v1/seed-audio/generate` | 异步建任务 → 202 {taskId, status:pending} |
| GET `/v1/seed-audio/tasks` | 列表（page/pageSize/status/keyword） |
| GET `/v1/seed-audio/tasks/{taskId}` | 详情（SeedAudioTask） |

**忽略**（coveragePolicy 不对外）：`/v1/seed-audio/voices`、`/v1/seed-audio/estimate-credits`。
ListenHub 音色代号来源仍指向 `GET /v1/speakers/list`。

## 契约要点（落进 SKILL）

- `text` 必填、trim、≤1400；`@音频N` 多音色台词指派
- `voices` 1–3 项，`{type:speaker,id}` 或 `{type:reference,url}`；多音色每项须 reference-capable，
  豆包 voice_type 仅单音色
- `image`（url|data 二选一，≤10MB jpeg/png/webp）**与 voices 互斥**
- `audioConfig`: speechRate -50..100 / loudnessRate -50..100 / pitchRate -12..12 / format mp3|wav|pcm|ogg_opus(默认 mp3)
- `durationHint` 1..110；`watermark` boolean
- 计费 0.1125 积分/秒按实结算、向上取整、最低 1；限流 60s/5 次
- SeedAudioTask: id/status(5态)/model/params(脱敏)/audioUrl(仅 success)/audioDuration/
  creditCharged/creditRefunded/errorMessage(仅 failed)/createdAt/updatedAt(ms)
- 5 态对外：`pending→generating→uploading→success|failed`（不假设 pending_payment）

## 改动

1. `seed-audio/SKILL.md`（新建）— 仿 video-gen 结构：frontmatter（emoji 🎙️ / requires.bin
   listenhub / 触发词）、When to Use/NOT、Hard Constraints + HARD-GATE、交互流（收 text →
   音色/输入模式分支 → audioConfig → durationHint → cost note → 确认 → submit → poll →
   result）、API Contract（3 端点表）、Error Handling、Composability、Examples。
2. `listenhub/SKILL.md`（编辑）— 路由表 + AskUserQuestion 新增 Seed-Audio 行/选项。
3. `listenhub-cli/SKILL.md`（编辑）— 同步路由表 + 选项，两 router 一致。

## 关键风险与决策

- **CLI 无 seed-audio 子命令**（全仓 grep 零命中）。决策：采用方案 (a) —— 用 OpenAPI HTTP
  契约（curl Bearer lh_sk_...）落地所有示例，并在 Step -1 显式标注 CLI 待补 +
  `SEED_AUDIO_COMMAND_UNAVAILABLE` 闸（CLI 一旦发版即切回 `$CMD_PREFIX` 模式）。
- skills 为纯文档仓：无 package.json / lint / test，verify 只能人审（manual 自检）。
- 不暴露 provider 路由/凭证/内部状态名/DAO/Mongo/回调内部路径（coveragePolicy doNotExpose）。

## 验证（manual，skills 无 build）

- 结构对齐 video-gen（章节齐全）
- 触发词去重（不与 /tts 既有触发词冲突）
- 必填参数核对（与 generateRequestSchema 逐项一致）
- 至少一个可运行示例（method+path+body 与 listenhub.yaml 一致）
- 两 router 路由表与选项块都已新增 `/seed-audio`
