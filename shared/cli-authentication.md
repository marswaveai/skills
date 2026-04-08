# CLI Authentication

## Prerequisites

- **Node.js >= 20**
- **ListenHub CLI**: `npm install -g @marswave/listenhub-cli`

## Auth Check

Run this before any CLI operation:

```bash
listenhub auth status --json
```

Parse the `.authenticated` field:

```bash
AUTH=$(listenhub auth status --json 2>/dev/null)
AUTHED=$(echo "$AUTH" | jq -r '.authenticated // false')
```

### If CLI not installed

If `listenhub` command is not found, tell the user:

> ListenHub CLI is not installed. Please install it:
> ```
> npm install -g @marswave/listenhub-cli
> ```
> Requires Node.js 20 or later.

### If not logged in

If `.authenticated` is `false`, tell the user:

> You're not logged in. Please run:
> ```
> listenhub auth login
> ```
> This will open your browser for OAuth authentication.

Then wait for the user to complete login and re-check.

## Security

- Credentials are stored at `~/.config/listenhub/credentials.json` (file mode `0600`)
- Tokens refresh automatically -- no manual rotation needed
- Never log or display tokens in output
