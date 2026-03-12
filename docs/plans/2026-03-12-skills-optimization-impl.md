# Skills Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add unified artifact storage (`.listenhub/`), per-skill config, and paginated speaker selection across all ListenHub skills.

**Architecture:** Two shared docs establish reusable patterns (config lookup, speaker pagination); each skill's `SKILL.md` is updated to follow them. Skills are updated in dependency order: shared → podcast → tts → content-parser → image-gen.

**Tech Stack:** Markdown skill instruction files. No code — changes are to agent-facing `.md` files that Claude reads at runtime.

---

## Task 1: Create `shared/config-pattern.md`

**Files:**
- Create: `shared/config-pattern.md`

The config lookup pattern is used by every skill. Centralising it avoids repeating the rules in each `SKILL.md`.

**Step 1: Write the file**

```markdown
# Config Pattern

Reusable pattern for per-skill config lookup, creation, and update.

## Config Location

Each skill stores config at:

```
.listenhub/{skill}/config.json
```

## Lookup Order

Check in this order, stop at first match:

1. `{CWD}/.listenhub/{skill}/config.json` — project-level
2. `~/.listenhub/{skill}/config.json` — global

## First-Run Prompt

If neither file exists, use `AskUserQuestion` — never assume a default:

```
Question: "ListenHub 配置文件存在哪里？"
Options:
  - "当前目录" — 创建 {CWD}/.listenhub/{skill}/config.json，仅此项目使用
  - "全局"     — 创建 ~/.listenhub/podcast/config.json，所有项目共用
```

After the user answers, create the directory and write the initial config with defaults.
This prompt fires **once per skill per location** — never again once the file exists.

## Reading Config

```bash
CONFIG_PATH=".listenhub/{skill}/config.json"
# Fall back to global if not found locally
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/{skill}/config.json"
CONFIG=$(cat "$CONFIG_PATH" 2>/dev/null || echo "{}")
```

Use `jq` to read individual fields:

```bash
AUTO_DOWNLOAD=$(echo "$CONFIG" | jq -r '.autoDownload // true')
LANGUAGE=$(echo "$CONFIG" | jq -r '.language // empty')
```

## Writing Config

Always merge — never overwrite keys you didn't change:

```bash
# Merge a single key into existing config
NEW_CONFIG=$(echo "$CONFIG" | jq '. + {"language": "zh", "defaultMode": "deep"}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

## Artifact Directory

After a job completes, create a dated subfolder and download artifacts:

```bash
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/{skill}/${DATE}-{jobId}"
mkdir -p "$JOB_DIR"

# Download each artifact
curl -sS -o "${JOB_DIR}/{jobId}.mp3" "{audioUrl}"
curl -sS -o "${JOB_DIR}/{jobId}.md"  "{transcriptUrl}"  # if applicable
```

File naming: `{jobId}.{ext}` inside `YYYY-MM-DD-{jobId}/`.
Draft files (two-step mode): `{jobId}-draft.md`, `{jobId}-draft.json`.

## autoDownload Flag

Check before downloading:

```bash
AUTO_DOWNLOAD=$(echo "$CONFIG" | jq -r '.autoDownload // true')
if [ "$AUTO_DOWNLOAD" = "true" ]; then
  # download artifacts
fi
```
```

**Step 2: Verify the file reads cleanly**

Read `shared/config-pattern.md` and confirm:
- Lookup order is 1. CWD → 2. global → 3. prompt
- First-run uses `AskUserQuestion` (not plain text)
- Merge pattern uses `jq . +` (not overwrite)
- `autoDownload` defaults to `true`

**Step 3: Commit**

```bash
git add shared/config-pattern.md
git commit -m "feat(shared): add config-pattern.md — lookup, first-run prompt, artifact dir"
```

---

## Task 2: Rewrite `shared/speaker-selection.md`

**Files:**
- Modify: `shared/speaker-selection.md`

Replaces the current "present top N speakers as AskUserQuestion options" with the full pagination + text-table fallback pattern.

**Step 1: Read the current file**

Read `shared/speaker-selection.md` to understand what's being replaced.

**Step 2: Rewrite the file**

Replace the entire content with:

```markdown
# Speaker Selection Guide

## Fetching Speakers

Always call the speakers API before presenting options:

```
GET /speakers/list?language={language}
```

Never hardcode speaker IDs — the available list may change.

## Speaker Properties

Each speaker has:
- **name**: Display name (e.g., "Yuanye")
- **speakerId**: Technical ID to pass to API (e.g., "cozy-man-english")
- **gender**: `male` or `female`
- **language**: `zh` or `en`
- **demoAudioUrl**: Preview audio URL

## Presenting Options

### Step 1 — Always output the full text table first

Before calling `AskUserQuestion`, print the complete speaker list as a markdown table.
This ensures users in IM environments (Slack, WeChat) can read all options even if the
interactive picker doesn't render.

```
可用音色（共 N 个）：

| # | 名称        | 性别 | ID                  |
|---|-------------|------|---------------------|
| 1 | Yuanye      | 男   | cozy-man-english    |
| 2 | Travel Girl | 女   | travel-girl-english |
| 3 | Alex        | 男   | alex-en             |
| …                                            |

也可以直接输入音色名称或 ID
```

### Step 2 — AskUserQuestion with pagination

Immediately after the table, call `AskUserQuestion`:

- **Page size**: 3 speakers per page
- **4th option**: navigation
  - Any page except last: `下一页 → ({current}/{total_pages})`
  - Last page only: `← 上一页`
- **`Other`** (built-in): always available for free-text input

Example — page 1 of 3:
```
Question: "选择音色"
Options:
  - "Yuanye"         — 男, English
  - "Travel Girl"    — 女, English
  - "Alex"           — 男, English
  - "下一页 → (1/3)"
```

Example — last page:
```
Question: "选择音色"
Options:
  - "Brian"   — 男, English
  - "Sophie"  — 女, English
  - "← 上一页"
```

Navigation options trigger the next/previous `AskUserQuestion` call.
Track page state in the skill's interaction loop.

### Step 3 — Input matching

| Input source | Matching rule |
|---|---|
| AskUserQuestion option selected | Use `speakerId` directly |
| Free text — exact `speakerId` | Exact string match |
| Free text — name | Case-insensitive substring match on `name` |
| Free text — no match | Reply "未找到「{input}」，请重新输入" and re-prompt |

If multiple speakers match the name substring, present the matches as a new `AskUserQuestion`.

## Default Behavior (no user preference)

If the config has `defaultSpeakers.{language}` set:
1. Skip the selection step
2. Show the saved speaker(s) in the confirmation summary
3. User can change from the summary if desired

If no default is saved:
1. Fetch speaker list for the selected language
2. Run the full paginated selection flow above

## After Selection — Persist to Config

After the user confirms, update `defaultSpeakers.{language}` in the skill's config:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "en" \
  --argjson ids '["cozy-man-english"]' \
  '.defaultSpeakers[$lang] = $ids')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

For 2-speaker mode: array holds two IDs. If only one is saved, ask for the second.

## Environment Notes

| Environment | Picker rendered | User action |
|---|---|---|
| Claude Code / Cursor | Yes — interactive picker | Select from paginated list |
| IM (Slack, WeChat) | No — text only | Read table, reply via `Other` free-text |

No config flag or environment detection required.
```

**Step 3: Verify the file**

Read `shared/speaker-selection.md` and confirm:
- Text table is printed BEFORE `AskUserQuestion` (not after)
- Page size is 3 (not 4)
- Navigation: "下一页 →" on non-last pages, "← 上一页" on last page
- Matching table covers 4 cases including "no match → re-prompt"
- Config persist section uses `jq` merge (not overwrite)

**Step 4: Commit**

```bash
git add shared/speaker-selection.md
git commit -m "feat(shared): rewrite speaker-selection — pagination, text table, IM fallback"
```

---

## Task 3: Update `podcast/SKILL.md`

**Files:**
- Modify: `podcast/SKILL.md`

Four changes: (A) add Step 0 config read, (B) use config defaults for mode/language/speakers, (C) update two-step draft path, (D) update one-step completion to download artifacts.

**Step 1: Read the current file**

Read `podcast/SKILL.md` to note exact line positions of each section being changed.

**Step 2: Add Step 0 — Read config**

Insert before "## Interaction Flow":

```markdown
## Step 0: Read Config

Before any interaction, load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/podcast/config.json`, then `~/.listenhub/podcast/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it
3. Note saved values: `language`, `defaultMode`, `defaultSpeakers`, `autoDownload`

Saved values pre-fill steps 2–5. User can still override any of them during the interaction.
```

**Step 3: Update Step 2 (Mode)**

Replace the current Step 2 block with:

```markdown
### Step 2: Mode

If `config.defaultMode` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "What podcast generation mode?"
Options:
  - "Quick" — Short, concise overview (~5 min)
  - "Deep" — Thorough analysis with more detail (~10-15 min)
  - "Debate" — Two speakers with opposing views (requires 2 speakers)
```
```

**Step 4: Update Step 3 (Language)**

Replace the current Step 3 block with:

```markdown
### Step 3: Language

If `config.language` is set, pre-fill and show in summary — skip this question.
Otherwise ask:

```
Question: "What language?"
Options:
  - "Chinese (zh)" — Content in Mandarin Chinese
  - "English (en)" — Content in English
```
```

**Step 5: Update Step 5 (Speaker Selection)**

Replace the current Step 5 block with:

```markdown
### Step 5: Speaker Selection

Follow `shared/speaker-selection.md` for the full selection flow, including:
- Default from `config.defaultSpeakers.{language}` (skip step if set)
- Text table + paginated AskUserQuestion
- Input matching and re-prompt on no match

For 2-speaker mode (dialogue/debate): run selection twice (or until both are chosen).
```

**Step 6: Update One-Step completion block**

Replace the current "present result" block under `### One-Step Generation` with:

```markdown
4. When notified of completion, **download and present result**:

   a. Read `autoDownload` from config (default: `true`)
   b. If `autoDownload` is `true`:
      - Create `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
      - `curl -sS -o {dir}/{episodeId}.mp3 {audioUrl}`
      - Write `{episodeId}.md` from `scripts` array (one line per speaker turn: `**{speakerName}**: {content}`)
      - Write `{episodeId}.json` with raw `scripts` array

   c. Present:

   ```
   播客已生成！

   「{title}」

   在线收听：https://listenhub.ai/app/episode/{episodeId}
   MP3 直链： {audioUrl}

   已下载到 .listenhub/podcast/{YYYY-MM-DD}-{episodeId}/：
     {episodeId}.mp3
     {episodeId}.md
     {episodeId}.json
   ```

   (If `autoDownload` is `false`, omit the download section and only show the links.)
```

**Step 7: Update Two-Step draft path**

In `### Two-Step Generation`, replace step 3:

```markdown
3. When notified, **save draft to config output dir**:
   - Create `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
   - Write `{episodeId}-draft.md` (human-readable: `**{speakerName}**: {content}` per line)
   - Write `{episodeId}-draft.json` (raw `scripts` array)
   - Present the draft location and content preview
```

And replace step 7 (audio completion):

```markdown
7. When notified, **download audio to same folder**:
   - `curl -sS -o .listenhub/podcast/{dir}/{episodeId}.mp3 {audioUrl}`
   - Present final result (same format as one-step, folder now has draft + final files)
```

**Step 8: Add config update after generation**

Append to the end of `## Workflow`:

```markdown
### After Successful Generation

Update config with the choices made this session:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq \
  --arg lang "{language}" \
  --arg mode "{mode}" \
  --argjson speakers '{"{language}": ["{speakerId}"]}' \
  '. + {"language": $lang, "defaultMode": $mode, "defaultSpeakers": ($speakers + .defaultSpeakers)}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```
```

**Step 9: Update Hard Constraints**

Add to the `## Hard Constraints` list:

```markdown
- Always read config following `shared/config-pattern.md` before any interaction
- Always follow `shared/speaker-selection.md` for speaker selection (text table + pagination)
- Never save files to `~/Downloads/` — use `.listenhub/podcast/` from config
```

**Step 10: Update API Reference section**

Add:

```markdown
- Config pattern: `shared/config-pattern.md`
```

**Step 11: Verify the updated file**

Read `podcast/SKILL.md` and confirm:
- Step 0 appears before Step 1
- Step 2/3 mention config pre-fill
- Step 5 references `shared/speaker-selection.md`
- One-step workflow creates `.listenhub/podcast/YYYY-MM-DD-{episodeId}/`
- Two-step draft path is `.listenhub/podcast/...` not `~/Downloads/`
- Config update block is present after Workflow section
- `~/Downloads/` does not appear anywhere in the file

**Step 12: Commit**

```bash
git add podcast/SKILL.md
git commit -m "feat(podcast): add config lookup, artifact download, paginated speaker selection"
```

---

## Task 4: Update `tts/SKILL.md` and migrate config

**Files:**
- Modify: `tts/SKILL.md`
- Delete: `tts/user-config.json`

TTS currently reads `tts/user-config.json` directly. Migrate to the unified `.listenhub/tts/config.json` schema.

**Step 1: Read current `tts/SKILL.md` and `tts/user-config.json`**

Note the old config schema: `{ quickVoice, scriptVoices, language }`.

Mapping to new schema:
- `quickVoice` → `defaultSpeakers.{language}[0]` (single-speaker default)
- `scriptVoices` → `defaultSpeakers` (per-language array)
- `language` → `language`
- Add: `autoDownload: true`

**Step 2: Update Step 0 in `tts/SKILL.md`**

Replace:

```markdown
### Step 0: Read config

Before doing anything, read `tts/user-config.json`. Note the values for `quickVoice`, `scriptVoices`, and `language`. These will be used to skip asking the user where preferences are already saved.
```

With:

```markdown
### Step 0: Read config

Before doing anything, load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/tts/config.json`, then `~/.listenhub/tts/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it

Initial default config for tts:
```json
{
  "outputDir": ".listenhub",
  "autoDownload": true,
  "language": null,
  "defaultSpeakers": {}
}
```

Note saved values for `language`, `defaultSpeakers`, `autoDownload`.
```

**Step 3: Update Quick Mode — Step 2 (voice selection)**

Replace:

```markdown
- If `user-config.json.quickVoice` is set → use it silently (skip to Step 4)
- Otherwise: `GET /speakers/list?language={detected-language}`, then ask:
```

With:

```markdown
- If `config.defaultSpeakers.{language}[0]` is set → use it silently (skip to Step 4)
- Otherwise: `GET /speakers/list?language={detected-language}`, then follow `shared/speaker-selection.md` (text table + paginated AskUserQuestion)
```

**Step 4: Update Quick Mode — Step 3 (save preference)**

Replace:

```markdown
Question: "Save {voice name} as your default quick voice?"
Options:
  - "Yes" — update user-config.json
  - "No" — use for this session only
```

With:

```markdown
Question: "Save {voice name} as your default voice for {language}?"
Options:
  - "Yes" — update .listenhub/tts/config.json
  - "No" — use for this session only
```

**Step 5: Update Quick Mode — Step 6 (present result)**

Replace:

```markdown
**Step 6: Present result**

```
Audio generated!

  File: /tmp/tts-output.mp3
  Tip: Open the file to listen, or move it to your preferred location.
```
```

With:

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

**Step 6: Update Script Mode — Step 2 (voice assignment)**

Replace:

```markdown
- If `user-config.json.scriptVoices` has a saved voice → auto-assign silently
- Otherwise: fetch `GET /speakers/list?language={detected-language}` and ask:

```
Question: "Which voice for {character name}?"
Options: [one per speaker — label: name, description: gender]
```
```

With:

```markdown
- If `config.defaultSpeakers.{language}` has saved voices → auto-assign silently (one per character in order)
- Otherwise: fetch `GET /speakers/list?language={detected-language}` and follow `shared/speaker-selection.md` for each character
```

**Step 7: Update Script Mode — Step 3 (save preferences)**

Replace `update scriptVoices in user-config.json` with `update defaultSpeakers in .listenhub/tts/config.json`.

**Step 8: Update Script Mode — Step 6 (present result)**

Replace:

```markdown
**Step 6: Present result**

```
Audio generated!

  Listen: {audioUrl}
  Subtitles: {subtitlesUrl}
  Duration: {audioDuration / 1000}s
  Credits used: {credits}
```
```

With:

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

**Step 9: Update `## Updating user-config.json` section**

Replace the entire section with:

```markdown
## Updating Config

When saving preferences, merge into `.listenhub/tts/config.json` — do not overwrite unchanged keys.
Follow the merge pattern in `shared/config-pattern.md`.

- Quick voice: set `defaultSpeakers.{language}[0]` to the selected `speakerId`
- Script voices: set `defaultSpeakers.{language}` to the full array assigned this session
- Language: set `language` if the user explicitly specifies it
```

**Step 10: Update Hard Constraints**

Replace:

```markdown
- Always read `tts/user-config.json` before asking the user about voice preferences
```

With:

```markdown
- Always read config following `shared/config-pattern.md` before any interaction
- Always follow `shared/speaker-selection.md` for speaker selection (text table + pagination)
- Never save files to `~/Downloads/` or `/tmp/` as primary output — use `.listenhub/tts/`
```

**Step 11: Delete `tts/user-config.json`**

```bash
git rm tts/user-config.json
```

**Step 12: Verify**

Read `tts/SKILL.md` and confirm:
- `user-config.json` does not appear anywhere
- `.listenhub/tts/config.json` is the config path
- `shared/speaker-selection.md` is referenced for voice selection
- Output paths use `.listenhub/tts/`

**Step 13: Commit**

```bash
git add tts/SKILL.md
git commit -m "feat(tts): migrate to .listenhub config, paginated speaker selection, artifact download"
```

---

## Task 5: Update `content-parser/SKILL.md`

**Files:**
- Modify: `content-parser/SKILL.md`

Add config lookup (Step 0) and download the extracted content to `.listenhub/content-parser/`.

**Step 1: Read current file**

Read `content-parser/SKILL.md` to note current Step structure.

**Step 2: Add Step 0 — Read config**

Insert before `## Interaction Flow`:

```markdown
## Step 0: Read Config

Load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/content-parser/config.json`, then `~/.listenhub/content-parser/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it

Initial default config for content-parser:
```json
{
  "outputDir": ".listenhub",
  "autoDownload": true
}
```
```

**Step 3: Update Workflow step 6 (present result)**

Replace:

```markdown
6. When notified, **present result**:
   ```
   Content extracted!

   Source: {url}
   Title: {metadata.title}
   Length: ~{character count} characters
   Credits: {credits}
   ```
7. Show a preview of the extracted content (first ~500 chars)
8. Offer to save full content to file or use it in another skill
```

With:

```markdown
6. When notified, **download and present result**:

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

7. Show a preview of the extracted content (first ~500 chars)
8. Offer to use content in another skill (e.g. `/podcast`, `/tts`)
```

**Step 4: Add to Hard Constraints**

```markdown
- Always read config following `shared/config-pattern.md` before any interaction
- Never save files to `~/Downloads/` — use `.listenhub/content-parser/`
```

**Step 5: Add to API Reference**

```markdown
- Config pattern: `shared/config-pattern.md`
```

**Step 6: Verify**

Read `content-parser/SKILL.md` and confirm:
- Step 0 exists before Interaction Flow
- Workflow saves to `.listenhub/content-parser/YYYY-MM-DD-{taskId}/`
- Both `.md` and `.json` are saved

**Step 7: Commit**

```bash
git add content-parser/SKILL.md
git commit -m "feat(content-parser): add config lookup and artifact download to .listenhub"
```

---

## Task 6: Update `image-gen/SKILL.md`

**Files:**
- Modify: `image-gen/SKILL.md`

Replace `$LISTENHUB_OUTPUT_DIR` / `~/Downloads/` with `.listenhub/image-gen/`. Image-gen is synchronous (no API-returned jobId), so use a timestamp as the folder name.

**Step 1: Read current file**

Read `image-gen/SKILL.md` and note: output currently goes to `$LISTENHUB_OUTPUT_DIR` (default `~/Downloads`), filename `listenhub-YYYYMMDD-HHMMSS-XXXX.jpg`.

**Step 2: Add Step 0 — Read config**

Insert before `## Interaction Flow`:

```markdown
## Step 0: Read Config

Load config following `shared/config-pattern.md`:

1. Look for `{CWD}/.listenhub/image-gen/config.json`, then `~/.listenhub/image-gen/config.json`
2. If neither exists, use `AskUserQuestion` to ask global vs current directory, then create it

Initial default config for image-gen:
```json
{
  "outputDir": ".listenhub",
  "autoDownload": true
}
```
```

**Step 3: Update Workflow steps 4–5**

Replace:

```markdown
4. **Save**: Decode base64 and save to `$LISTENHUB_OUTPUT_DIR/listenhub-YYYYMMDD-HHMMSS-XXXX.jpg`
5. **Present result**:
   ```
   Image generated!

   ~/Downloads/listenhub-20260304-143145-0001.jpg
   ```
```

With:

```markdown
4. **Save**: Generate a timestamp-based jobId (`$(date +%s)`), then:
   - Create `.listenhub/image-gen/YYYY-MM-DD-{jobId}/`
   - Decode base64 and save as `{jobId}.jpg`

   ```bash
   JOB_ID=$(date +%s)
   DATE=$(date +%Y-%m-%d)
   JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
   mkdir -p "$JOB_DIR"
   echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
   ```

5. **Present result**:
   ```
   图片已生成！

   已保存到 .listenhub/image-gen/{YYYY-MM-DD}-{jobId}/：
     {jobId}.jpg
   ```
```

**Step 4: Update Hard Constraints**

Remove:

```markdown
- Output saved to `$LISTENHUB_OUTPUT_DIR` (default: `~/Downloads`)
- Filename format: `listenhub-YYYYMMDD-HHMMSS-XXXX.jpg`
```

Add:

```markdown
- Always read config following `shared/config-pattern.md` before any interaction
- Output saved to `.listenhub/image-gen/YYYY-MM-DD-{jobId}/` — never `~/Downloads/`
```

**Step 5: Update the example at the bottom**

In the `## Example` section, replace the save command:

```bash
echo "$BASE64_DATA" | base64 -D > ~/Downloads/listenhub-20260304-143145-0001.jpg
```

With:

```bash
JOB_ID=$(date +%s)
DATE=$(date +%Y-%m-%d)
JOB_DIR=".listenhub/image-gen/${DATE}-${JOB_ID}"
mkdir -p "$JOB_DIR"
echo "$BASE64_DATA" | base64 -D > "${JOB_DIR}/${JOB_ID}.jpg"
```

And replace the presented path `~/Downloads/listenhub-20260304-143145-0001.jpg` with `.listenhub/image-gen/2026-03-12-{jobId}/{jobId}.jpg`.

**Step 6: Verify**

Read `image-gen/SKILL.md` and confirm:
- `~/Downloads` does not appear anywhere
- `$LISTENHUB_OUTPUT_DIR` does not appear anywhere
- Output path uses `.listenhub/image-gen/YYYY-MM-DD-{jobId}/`
- Timestamp-based jobId is used (`date +%s`)

**Step 7: Commit**

```bash
git add image-gen/SKILL.md
git commit -m "feat(image-gen): migrate output to .listenhub, add config lookup"
```

---

## Done

All six tasks complete. Final state:

| File | Change |
|---|---|
| `shared/config-pattern.md` | New — config lookup, first-run prompt, artifact dir, autoDownload |
| `shared/speaker-selection.md` | Rewritten — text table + paginated AskUserQuestion + IM fallback |
| `podcast/SKILL.md` | Config step, pre-fills, paginated speakers, download to `.listenhub/podcast/` |
| `tts/SKILL.md` | Config migrated from `user-config.json`, paginated speakers, download to `.listenhub/tts/` |
| `tts/user-config.json` | Deleted |
| `content-parser/SKILL.md` | Config step, download to `.listenhub/content-parser/` |
| `image-gen/SKILL.md` | Config step, output to `.listenhub/image-gen/` |
