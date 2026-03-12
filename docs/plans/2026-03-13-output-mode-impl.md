# Output Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace `autoDownload` with a three-way `outputMode` across tts/podcast/explainer/image-gen, and fix content-parser to save to the current directory.

**Architecture:** Add a new `shared/output-mode.md` reference doc that all four media skills point to. Each skill's SKILL.md gets three targeted edits: config default, Setup Flow question, and Step 6 output branching. `shared/config-pattern.md` also loses its `autoDownload` section. content-parser gets a separate storage-path fix.

**Tech Stack:** Markdown skill definition files only — no code changes.

---

### Task 1: Create `shared/output-mode.md`

**Files:**
- Create: `shared/output-mode.md`

**Step 1: Write the file**

Create `shared/output-mode.md` with this exact content:

````markdown
# Output Mode

Reusable pattern for all skills that produce downloadable artifacts (audio, images).

## Config Field

Each skill stores `outputMode` in its `config.json`:

```json
{ "outputMode": "inline" }
```

Valid values: `"inline"` (default) | `"download"` | `"both"`

## Migration from `autoDownload`

When reading a config that has `autoDownload` but no `outputMode`, migrate silently:

```bash
CONFIG=$(cat "$CONFIG_PATH")
HAS_OUTPUT_MODE=$(echo "$CONFIG" | jq -r 'has("outputMode")')
if [ "$HAS_OUTPUT_MODE" = "false" ]; then
  OLD_DL=$(echo "$CONFIG" | jq -r '.autoDownload // true')
  if [ "$OLD_DL" = "true" ]; then NEW_MODE="download"; else NEW_MODE="inline"; fi
  CONFIG=$(echo "$CONFIG" | jq --arg m "$NEW_MODE" 'del(.autoDownload) + {"outputMode": $m}')
  echo "$CONFIG" > "$CONFIG_PATH"
fi
OUTPUT_MODE=$(echo "$CONFIG" | jq -r '.outputMode // "inline"')
```

## Setup Flow Question

Replace the "自动下载？" question with:

```
Question: "输出方式？"
Options:
  - "对话中展示（推荐）" — outputMode: "inline"
  - "下载到本地目录"     — outputMode: "download"
  - "两者都要"           — outputMode: "both"
```

Config summary display: `输出方式：inline / download / both`

## Save to Config

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq --arg m "$OUTPUT_MODE" '. + {"outputMode": $m}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

## Output Behavior Per Mode

### `inline` (default)

Show the result directly in the conversation. Do NOT save to `.listenhub/`.

- **Sync audio (TTS quick)**: Save to `/tmp/tts-{jobId}.mp3` during the curl call, then use the Read tool on that path. Clients that support audio show it inline; Claude Code terminal shows the file path.
- **Async audio (TTS script, podcast)**: Display the `audioUrl` as a clickable link. No download.
- **Async video (explainer)**: Display video URL + audio URL as clickable links. No download.
- **Image (image-gen)**: Save to `/tmp/image-gen-{jobId}.jpg` after base64 decode, then use the Read tool on that path. Image displays inline in all clients.

### `download`

Save to `.listenhub/{skill}/YYYY-MM-DD-{jobId}/` and show the local file path. This is the previous `autoDownload: true` behavior.

```bash
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/{skill}/${DATE}-{jobId}"
mkdir -p "$JOB_DIR"
curl -sS -o "${JOB_DIR}/{jobId}.mp3" "{audioUrl}"
```

Present:
```
已下载到 .listenhub/{skill}/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```

### `both`

Execute `download` logic **and then** execute `inline` display logic for the same artifact.
````

**Step 2: Verify**

Check that the file was created:
```bash
cat shared/output-mode.md | head -5
```
Expected: `# Output Mode`

**Step 3: Commit**

```bash
git add shared/output-mode.md
git commit -m "feat(shared): add output-mode pattern doc"
```

---

### Task 2: Update `shared/config-pattern.md`

**Files:**
- Modify: `shared/config-pattern.md:106-116`

**Step 1: Replace the `autoDownload Flag` section**

Find the section starting at line 106:
```markdown
## autoDownload Flag

Check before downloading:

```bash
AUTO_DOWNLOAD=$(echo "$CONFIG" | jq -r '.autoDownload // true')
if [ "$AUTO_DOWNLOAD" = "true" ]; then
  # download artifacts
fi
```
```

Replace with:
```markdown
## Output Mode

Read `outputMode` from config, then follow `shared/output-mode.md` for behavior.

```bash
OUTPUT_MODE=$(echo "$CONFIG" | jq -r '.outputMode // "inline"')
```
```

**Step 2: Commit**

```bash
git add shared/config-pattern.md
git commit -m "feat(shared): replace autoDownload flag with outputMode in config-pattern"
```

---

### Task 3: Update `tts/SKILL.md`

Three targeted edits: config default, config display + Setup Flow, Step 6 output.

**Files:**
- Modify: `tts/SKILL.md`

**Step 1: Update config default (line ~73)**

Find:
```
echo '{"outputDir":".listenhub","autoDownload":true,"language":null,"defaultSpeakers":{}}' > ".listenhub/tts/config.json"
```

Replace with:
```
echo '{"outputDir":".listenhub","outputMode":"inline","language":null,"defaultSpeakers":{}}' > ".listenhub/tts/config.json"
```

**Step 2: Update config display summary (lines ~81-86)**

Find:
```
当前配置 (tts)：
  自动下载：{是 / 否}
  语言偏好：{zh / en / 未设置}
  默认主播：{speakerName / 未设置}
```

Replace with:
```
当前配置 (tts)：
  输出方式：{inline / download / both}
  语言偏好：{zh / en / 未设置}
  默认主播：{speakerName / 未设置}
```

**Step 3: Replace Setup Flow question 1 (lines ~91-109)**

Find:
```markdown
1. **autoDownload**: "自动下载生成的音频文件？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`

2. **Language** (optional): "默认语言？"
```

Replace with:
```markdown
1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.

2. **Language** (optional): "默认语言？"
```

**Step 4: Replace save block after Setup Flow (lines ~101-109)**

Find:
```bash
# Always update autoDownload; only update language if user picked one
NEW_CONFIG=$(echo "$CONFIG" | jq --argjson dl {true/false} '. + {"autoDownload": $dl}')
# If language was chosen (not "每次手动选择"):
NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg lang "zh" '. + {"language": $lang}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

Replace with:
```bash
# Save outputMode; only update language if user picked one
# Follow shared/output-mode.md § Save to Config
NEW_CONFIG=$(echo "$CONFIG" | jq --arg m "$OUTPUT_MODE" '. + {"outputMode": $m}')
# If language was chosen (not "每次手动选择"):
NEW_CONFIG=$(echo "$NEW_CONFIG" | jq --arg lang "zh" '. + {"language": $lang}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
CONFIG=$(cat "$CONFIG_PATH")
```

**Step 5: Replace Step 6 for Quick Mode (lines ~155-173)**

Find the entire Step 6 block for Quick Mode:
```markdown
**Step 6: Download and present result**

If `autoDownload` is `true`:
- The TTS endpoint returns audio directly (not async) — save the output during the curl call
- Use a timestamped jobId: `$(date +%s)`
- Create `.listenhub/tts/YYYY-MM-DD-{jobId}/`
- Save as `{jobId}.mp3` via `curl ... --output {dir}/{jobId}.mp3`

Present:
```
Audio generated!

已下载到 .listenhub/tts/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```

If `autoDownload` is `false`, save to `/tmp/tts-{jobId}.mp3` and show that path.
```

Replace with:
```markdown
**Step 6: Present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

Use a timestamped jobId: `$(date +%s)`

**`inline` or `both`** (TTS quick returns a sync audio stream — no `audioUrl`):
```bash
JOB_ID=$(date +%s)
curl -sS -X POST "..." ... --output /tmp/tts-${JOB_ID}.mp3
```
Then use the Read tool on `/tmp/tts-{jobId}.mp3`.

Present:
```
Audio generated!
```

**`download` or `both`**:
```bash
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/tts/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
curl -sS -X POST "..." ... --output "${JOB_DIR}/${JOB_ID}.mp3"
```
Present:
```
Audio generated!

已下载到 .listenhub/tts/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```
```

**Step 6: Replace Step 6 for Script Mode (lines ~244-262)**

Find:
```markdown
**Step 6: Download and present result**

If `autoDownload` is `true`:
- Create `.listenhub/tts/YYYY-MM-DD-{jobId}/`
- `curl -sS -o {dir}/{jobId}.mp3 {audioUrl}`

Present:
```
Audio generated!

在线收听：{audioUrl}
字幕：{subtitlesUrl}
时长：{audioDuration / 1000}s
消耗积分：{credits}

已下载到 .listenhub/tts/{YYYY-MM-DD}-{jobId}/：
  {jobId}.mp3
```
```

Replace with:
```markdown
**Step 6: Present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Display the `audioUrl` and `subtitlesUrl` as clickable links.

Present:
```
Audio generated!

在线收听：{audioUrl}
字幕：{subtitlesUrl}
时长：{audioDuration / 1000}s
消耗积分：{credits}
```

**`download` or `both`**: Also download the file.
```bash
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/tts/${DATE}-{jobId}"
mkdir -p "$JOB_DIR"
curl -sS -o "${JOB_DIR}/{jobId}.mp3" "{audioUrl}"
```
Present the download path in addition to the above summary.
```

**Step 7: Commit**

```bash
git add tts/SKILL.md
git commit -m "feat(tts): replace autoDownload with outputMode"
```

---

### Task 4: Update `podcast/SKILL.md`

Same three-area pattern as TTS. Read the full file first to find exact line numbers.

**Files:**
- Modify: `podcast/SKILL.md`

**Step 1: Read the full file to locate exact sections**

```bash
grep -n "autoDownload\|自动下载\|Step 6\|Download and present" podcast/SKILL.md
```

**Step 2: Update config default**

Find the `echo '{...}' > ".listenhub/podcast/config.json"` line.

Replace `"autoDownload":true` with `"outputMode":"inline"` in the JSON string.

**Step 3: Update config display summary**

Find `自动下载：{是 / 否}` in the config summary block.

Replace with `输出方式：{inline / download / both}`.

**Step 4: Replace Setup Flow question for autoDownload**

Find:
```markdown
1. **autoDownload**: "自动下载生成的播客文件？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`
```

Replace with:
```markdown
1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.
```

**Step 5: Replace Step 6 output block**

Find the `**Step 6: Download and present result**` block (podcast has `audioUrl` from async generation).

Replace with:
```markdown
**Step 6: Present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Display `audioUrl` as a clickable link.

Present:
```
播客已生成！

在线收听：{audioUrl}
字幕：{subtitlesUrl}（如有）
时长：{audioDuration / 1000}s
消耗积分：{credits}
```

**`download` or `both`**: Also download the file.
```bash
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/podcast/${DATE}-{episodeId}"
mkdir -p "$JOB_DIR"
curl -sS -o "${JOB_DIR}/{episodeId}.mp3" "{audioUrl}"
```
Present the download path in addition to the above summary.
```

**Step 6: Commit**

```bash
git add podcast/SKILL.md
git commit -m "feat(podcast): replace autoDownload with outputMode"
```

---

### Task 5: Update `explainer/SKILL.md`

Same pattern. Explainer produces a video URL + audio URL.

**Files:**
- Modify: `explainer/SKILL.md`

**Step 1: Read the full file to locate exact sections**

```bash
grep -n "autoDownload\|自动下载\|Step 6\|Download and present" explainer/SKILL.md
```

**Step 2: Update config default**

Find the `echo '{...}' > ".listenhub/explainer/config.json"` line.

Replace `"autoDownload":true` with `"outputMode":"inline"` in the JSON string.

**Step 3: Update config display summary**

Replace `自动下载：{是 / 否}` with `输出方式：{inline / download / both}`.

**Step 4: Replace Setup Flow autoDownload question**

Find:
```markdown
1. **autoDownload**: "自动下载生成的文件？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`
```

Replace with:
```markdown
1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.
```

**Step 5: Replace Step 6 output block**

Find the download/present section. Replace with:

```markdown
**Step 6: Present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Display video URL and audio URL as clickable links.

Present:
```
解说视频已生成！

视频链接：{videoUrl}
音频链接：{audioUrl}
时长：{duration}s
消耗积分：{credits}
```

**`download` or `both`**: Also download the audio file.
```bash
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/explainer/${DATE}-{jobId}"
mkdir -p "$JOB_DIR"
curl -sS -o "${JOB_DIR}/{jobId}.mp3" "{audioUrl}"
```
Present the download path in addition to the above summary.
```

**Step 6: Commit**

```bash
git add explainer/SKILL.md
git commit -m "feat(explainer): replace autoDownload with outputMode"
```

---

### Task 6: Update `image-gen/SKILL.md`

Image-gen is special: it returns base64 data (no URL), and the Read tool renders images inline in all clients.

**Files:**
- Modify: `image-gen/SKILL.md`

**Step 1: Update config default (line ~53)**

Find:
```bash
echo '{"outputDir":".listenhub","autoDownload":true}' > ".listenhub/image-gen/config.json"
```

Replace with:
```bash
echo '{"outputDir":".listenhub","outputMode":"inline"}' > ".listenhub/image-gen/config.json"
```

**Step 2: Update config display summary (line ~63)**

Find:
```
当前配置 (image-gen)：
  自动下载：{是 / 否}
```

Replace with:
```
当前配置 (image-gen)：
  输出方式：{inline / download / both}
```

**Step 3: Replace Setup Flow question (lines ~68-70)**

Find:
```markdown
1. **autoDownload**: "自动保存生成的图片到本地？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`
```

Replace with:
```markdown
1. **outputMode**: Follow `shared/output-mode.md` § Setup Flow Question.
```

**Step 4: Replace steps 4-5 in Workflow (lines ~143-161)**

Find the "4. **Save**" and "5. **Present result**" blocks.

Replace with:
```markdown
4. **Decode and present result**

Read `OUTPUT_MODE` from config. Follow `shared/output-mode.md` for behavior.

**`inline` or `both`**: Decode base64 to a temp file, then use the Read tool.

```bash
JOB_ID=$(date +%s)
echo "$BASE64_DATA" | base64 -D > /tmp/image-gen-${JOB_ID}.jpg
```
Then use the Read tool on `/tmp/image-gen-{jobId}.jpg`. The image displays inline in the conversation.

Present:
```
图片已生成！
```

**`download` or `both`**: Save to the artifact directory.

```bash
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

Present:
```
图片已生成！

已保存到 .listenhub/image-gen/{YYYY-MM-DD}-{jobId}/：
  {jobId}.jpg
```
```

**Step 5: Update the Example section (line ~232)**

Find:
```bash
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```
The line just before:
```bash
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

And the final present line:
```
Present `.listenhub/image-gen/2026-03-12-{jobId}/{jobId}.jpg` to the user.
```

Replace that last line with:
```
Decode the base64 data per `outputMode` (see `shared/output-mode.md`).
```

**Step 6: Commit**

```bash
git add image-gen/SKILL.md
git commit -m "feat(image-gen): replace autoDownload with outputMode, inline via Read tool"
```

---

### Task 7: Update `content-parser/SKILL.md`

content-parser does NOT use `outputMode`. Instead, fix its save location from `.listenhub/content-parser/` to the current directory.

**Files:**
- Modify: `content-parser/SKILL.md`

**Step 1: Update config default (line ~52)**

Find:
```bash
echo '{"outputDir":".listenhub","autoDownload":true}' > ".listenhub/content-parser/config.json"
```

Replace with:
```bash
echo '{"autoDownload":true}' > ".listenhub/content-parser/config.json"
```

(Remove `outputDir` — output goes to current dir, not configurable.)

**Step 2: Update the autoDownload Setup Flow question (lines ~67-69)**

Find:
```markdown
1. **autoDownload**: "自动保存提取的内容到本地？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`
```

Replace with:
```markdown
1. **autoDownload**: "自动保存提取的内容到当前目录？"
   - "是（推荐）" → `autoDownload: true`
   - "否" → `autoDownload: false`
```

**Step 3: Replace the download/present block in Workflow (lines ~156-174)**

Find:
```markdown
   If `autoDownload` is `true`:
   - Create `.listenhub/content-parser/YYYY-MM-DD-{taskId}/`
   - Write `{taskId}.md` — full extracted content in markdown
   - Write `{taskId}.json` — full raw API response data

   Present:
   ```
   内容提取完成！

   来源：{url}
   标题：{metadata.title}
   长度：~{character count} 字符
   消耗积分：{credits}

   已保存到 .listenhub/content-parser/{YYYY-MM-DD}-{taskId}/：
     {taskId}.md
     {taskId}.json
   ```
```

Replace with:
```markdown
   If `autoDownload` is `true`:
   - Write `{taskId}-extracted.md` to the **current directory** — full extracted content in markdown
   - Write `{taskId}-extracted.json` to the **current directory** — full raw API response data

   ```bash
   echo "$CONTENT_MD" > "${TASK_ID}-extracted.md"
   echo "$RESULT" > "${TASK_ID}-extracted.json"
   ```

   Present:
   ```
   内容提取完成！

   来源：{url}
   标题：{metadata.title}
   长度：~{character count} 字符
   消耗积分：{credits}

   已保存到当前目录：
     {taskId}-extracted.md
     {taskId}-extracted.json
   ```
```

**Step 4: Remove the Hard Constraint about `.listenhub/`**

Find:
```
- Never save files to `~/Downloads/` — use `.listenhub/content-parser/`
```

Replace with:
```
- Never save files to `~/Downloads/` or `.listenhub/` — save to the current working directory
```

**Step 5: Commit**

```bash
git add content-parser/SKILL.md
git commit -m "feat(content-parser): save extractions to current directory, not .listenhub"
```

---

### Task 8: Final verification

**Step 1: Check all `autoDownload` references are gone from media skill files**

```bash
grep -n "autoDownload" tts/SKILL.md podcast/SKILL.md explainer/SKILL.md image-gen/SKILL.md shared/config-pattern.md
```

Expected: no output (zero matches).

**Step 2: Check content-parser still has `autoDownload` (it keeps it)**

```bash
grep -n "autoDownload" content-parser/SKILL.md
```

Expected: 3-4 matches (the config field, setup question, workflow check).

**Step 3: Check `outputMode` appears in all four media skills**

```bash
grep -c "outputMode" tts/SKILL.md podcast/SKILL.md explainer/SKILL.md image-gen/SKILL.md
```

Expected: each file has at least 3 matches.

**Step 4: Check output-mode.md is referenced by all four media skills**

```bash
grep -l "output-mode.md" tts/SKILL.md podcast/SKILL.md explainer/SKILL.md image-gen/SKILL.md
```

Expected: all four files listed.

**Step 5: Final commit if any cleanup needed**

```bash
git add -A
git status  # verify only expected files changed
git commit -m "chore: final cleanup for output-mode feature"
```
