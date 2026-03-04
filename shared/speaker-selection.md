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

## Selection Guidelines

### Single Speaker (Solo/Monologue)

Pick based on:
1. Language match (must match episode language)
2. User gender preference if stated
3. Default: first speaker in the list matching the language

### Two Speakers (Dialogue/Debate)

Recommend contrasting voices for better listening experience:
- Male + Female pairing (most common)
- If both same gender, pick different voice styles

### Presenting Options

Use the **AskUserQuestion tool** to present speakers as interactive options (not plain text):
- Label: speaker name
- Description: gender + language

Example:
```
Question: "Which speaker?"
Options:
  - "Yuanye" — Male, English
  - "Travel Girl" — Female, English
```

## Default Behavior

If user doesn't specify a speaker preference:
1. Fetch speaker list for the selected language
2. Pick the first matching speaker as default
3. For 2-speaker mode, pick the first two matching speakers
