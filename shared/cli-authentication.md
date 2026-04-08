# CLI Authentication

## Prerequisites

- **Node.js >= 20**
- **ListenHub CLI** (auto-installed if missing)

## Auth Check

Run this before any CLI operation. The check handles both installation and login automatically — never ask the user to run install commands manually.

```bash
# 1. Auto-install if missing
if ! command -v listenhub &>/dev/null; then
  npm install -g @marswave/listenhub-cli
fi

# 2. Verify install succeeded
if ! command -v listenhub &>/dev/null; then
  echo "INSTALL_FAILED"
  # Stop here — tell user their Node.js/npm setup needs attention
fi

# 3. Check for updates (skip if just installed)
CURRENT_V=$(listenhub --version 2>/dev/null)
LATEST_V=$(npm view @marswave/listenhub-cli version 2>/dev/null)
if [ -n "$CURRENT_V" ] && [ -n "$LATEST_V" ] && [ "$CURRENT_V" != "$LATEST_V" ]; then
  npm install -g @marswave/listenhub-cli
fi

# 4. Check auth
AUTH=$(listenhub auth status --json 2>/dev/null)
AUTHED=$(echo "$AUTH" | jq -r '.authenticated // false')
```

### If install fails

If `npm install -g` fails (e.g., permission issues, Node.js not available), tell the user:

> ListenHub CLI auto-install failed. Please check your Node.js (>= 20) and npm setup, then retry.

Do **not** ask them to run `npm install -g @marswave/listenhub-cli` manually — diagnose the issue first (permissions, PATH, Node version).

### If not logged in

If `.authenticated` is `false`, run `listenhub auth login` directly — this opens the browser for OAuth. Wait for completion, then re-check auth status.

```bash
if [ "$AUTHED" != "true" ]; then
  listenhub auth login
  # Re-verify after login
  AUTH=$(listenhub auth status --json 2>/dev/null)
  AUTHED=$(echo "$AUTH" | jq -r '.authenticated // false')
fi
```

### If update check is slow

The `npm view` call is typically fast (< 2s). If it fails (network issues, npm registry down), silently skip the update and proceed with the installed version. Never block the user on a version check failure.

## Security

- Credentials are stored at `~/.config/listenhub/credentials.json` (file mode `0600`)
- Tokens refresh automatically — no manual rotation needed
- Never log or display tokens in output
