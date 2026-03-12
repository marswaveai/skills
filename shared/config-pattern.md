# Config Pattern

Reusable pattern for per-skill config lookup, creation, and update.

## Config Location

Each skill stores config at:

```
.listenhub/{skill}/config.json
```

## Step 0: Config Setup

Run before any interaction in every skill. Three possible states:

### State A — File Doesn't Exist (first run)

Use `AskUserQuestion`:
```
Question: "ListenHub 配置文件存在哪里？"
Options:
  - "当前目录" — {CWD}/.listenhub/{skill}/config.json（仅此项目）
  - "全局" — ~/.listenhub/{skill}/config.json（所有项目共用）
```

Then create the directory and write the skill's initial defaults **immediately**:

```bash
# 当前目录:
mkdir -p ".listenhub/{skill}"
echo '{...skill initial defaults...}' > ".listenhub/{skill}/config.json"
CONFIG_PATH=".listenhub/{skill}/config.json"

# 全局:
mkdir -p "$HOME/.listenhub/{skill}"
echo '{...skill initial defaults...}' > "$HOME/.listenhub/{skill}/config.json"
CONFIG_PATH="$HOME/.listenhub/{skill}/config.json"
```

Then run the skill's **Setup Flow** to collect preferences and save them.

### State B — File Exists

Read the config:
```bash
CONFIG_PATH=".listenhub/{skill}/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/{skill}/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

Display the current settings in a readable summary (skill-specific format), then ask:

```
Question: "使用已保存的配置？"
Options:
  - "确认，直接继续" — use saved config as-is, skip Setup Flow
  - "重新配置" — run Setup Flow again and overwrite saved values
```

## Setup Flow

Each skill defines its own Setup Flow — questions to collect preferences on first run or reconfigure. After answers are collected, **save immediately** using the merge pattern:

```bash
NEW_CONFIG=$(echo "$CONFIG" | jq '. + {"key": "value"}')
echo "$NEW_CONFIG" > "$CONFIG_PATH"
```

Never overwrite keys you didn't change — always use `jq '. + {...}'` merge.

## Reading Config Fields

```bash
CONFIG=$(cat "$CONFIG_PATH" 2>/dev/null || echo "{}")
OUTPUT_MODE=$(echo "$CONFIG" | jq -r '.outputMode // "inline"')
LANGUAGE=$(echo "$CONFIG" | jq -r '.language // empty')
```

## Writing Config

Merge pattern for updating individual fields after a session:

```bash
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

## Output Mode

Read `outputMode` from config, then follow `shared/output-mode.md` for behavior.

```bash
OUTPUT_MODE=$(echo "$CONFIG" | jq -r '.outputMode // "inline"')
```
