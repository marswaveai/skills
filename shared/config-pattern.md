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
