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

### Step 1 — Output the full text table

Print the complete speaker list as a markdown table, then wait for the user to type their choice.

```
Available voices (N total):

| # | Name        | Gender | ID                  |
|---|-------------|--------|---------------------|
| 1 | Yuanye      | male   | cozy-man-english    |
| 2 | Travel Girl | female | travel-girl-english |
| 3 | Alex        | male   | alex-en             |
| …                                              |

Type a name, number, or ID to select.
```

Adapt the table header language to match the user's language (Chinese users → Chinese headers, English users → English headers).

Do NOT use `AskUserQuestion` for speaker selection — just show the table and wait for free-text input.

### Step 2 — Input matching

| Input | Matching rule |
|---|---|
| Number (e.g. "3") | Match by row index in the table |
| Exact `speakerId` | Exact string match |
| Name text | Case-insensitive substring match on `name` |
| No match | Reply in user's language: "「{input}」not found, please try again" and re-prompt |

If multiple speakers match the name substring, print the matches as a short table and ask again.

## Default Behavior (no user preference)

If the config has `defaultSpeakers.{language}` set:
1. Skip the selection step
2. Show the saved speaker(s) in the confirmation summary
3. User can change from the summary if desired

If no default is saved:
1. Fetch speaker list for the selected language
2. Show the full table and wait for free-text input

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
