# Config Pattern

Reusable pattern for per-skill config lookup, creation, and update.

## API Key Check

Run this **before Step 0** in every skill that requires `LISTENHUB_API_KEY`.

```bash
[ -z "$LISTENHUB_API_KEY" ] && echo "MISSING" || echo "OK"
```

**If `OK`**: proceed to Step 0 silently. Do NOT display or confirm the key.

**If `MISSING`**: run the interactive setup below. Do NOT stop — guide the user through configuration and then continue.

### Interactive Key Setup

1. Tell the user:
   > `LISTENHUB_API_KEY` 未配置。请前往 https://listenhub.ai/settings/api-keys 获取 API Key（需要 Pro 订阅）。

2. Use `AskUserQuestion` to collect the key:
   > 请粘贴你的 API Key（以 `lh_sk_` 开头）：

3. Validate format — must start with `lh_sk_`. If not, re-prompt.

4. Write to shell profile and source:
   ```bash
   echo '' >> ~/.zshrc
   echo 'export LISTENHUB_API_KEY="lh_sk_..."' >> ~/.zshrc
   source ~/.zshrc
   ```
   On Linux, use `~/.bashrc` instead.

5. Confirm to the user:
   > API Key 已保存到 `~/.zshrc`，后续会话无需重复配置。

6. **Continue** — proceed to Step 0 and the skill's Interaction Flow. Do NOT ask the user to re-run.

## Config Location

Each skill stores config at:

```
.listenhub/{skill}/config.json
```

## Step 0: Config Setup (Zero-Question Boot)

Run before any interaction in every skill. The goal is **zero questions on first run** — create config silently with sensible defaults and proceed directly to the task.

### State A — File Doesn't Exist (first run)

**Do NOT ask any questions.** Silently create the config in the current directory with the skill's default values:

```bash
mkdir -p ".listenhub/{skill}"
echo '{...skill initial defaults...}' > ".listenhub/{skill}/config.json"
CONFIG_PATH=".listenhub/{skill}/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

Then proceed directly to the skill's **Interaction Flow** (skip Setup Flow entirely).

### State B — File Exists

Read the config silently and proceed:

```bash
CONFIG_PATH=".listenhub/{skill}/config.json"
[ ! -f "$CONFIG_PATH" ] && CONFIG_PATH="$HOME/.listenhub/{skill}/config.json"
CONFIG=$(cat "$CONFIG_PATH")
```

**Do NOT display config summary or ask for confirmation.** Proceed directly to the skill's Interaction Flow.

### Reconfigure (user-initiated only)

If the user explicitly asks to reconfigure (e.g., "reconfigure", "change settings", "重新配置"), then:

1. Display the current settings in a readable summary (skill-specific format)
2. Run the skill's **Setup Flow** to collect new preferences
3. Save updated values

This is the **only** time Setup Flow questions are asked.

## Setup Flow

Each skill defines its own Setup Flow — questions to collect preferences when the user explicitly requests reconfiguration. After answers are collected, **save immediately** using the merge pattern:

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
