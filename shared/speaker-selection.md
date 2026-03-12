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
