#!/usr/bin/env bash
# Shared environment checks for ListenHub scripts
# Source this at the beginning of each script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="${SKILL_DIR}/VERSION"
REMOTE_VERSION_URL="https://raw.githubusercontent.com/marswaveai/skills/main/skills/listenhub/VERSION"

# === Version Check (non-blocking) ===

check_version() {
  # Skip if no local VERSION file
  [ -f "$VERSION_FILE" ] || return 0

  local local_ver remote_ver http_code response
  local_ver=$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')

  # Fetch remote version with 5s timeout, check HTTP status
  response=$(curl -sS --max-time 5 -w "\n%{http_code}" "$REMOTE_VERSION_URL" 2>/dev/null) || return 0
  http_code=$(echo "$response" | tail -1)
  remote_ver=$(echo "$response" | head -1 | tr -d '[:space:]')

  # Only compare if HTTP 200 and valid semver-like format
  [[ "$http_code" == "200" && "$remote_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 0

  # Same version, skip
  [ "$local_ver" != "$remote_ver" ] || return 0

  # Parse semver: major.minor.patch
  local local_major local_minor local_patch
  local remote_major remote_minor remote_patch

  IFS='.' read -r local_major local_minor local_patch <<< "$local_ver"
  IFS='.' read -r remote_major remote_minor remote_patch <<< "$remote_ver"

  # Major or minor mismatch → auto-update via git (non-interactive)
  if [ "$local_major" != "$remote_major" ] || [ "$local_minor" != "$remote_minor" ]; then
    echo "┌─────────────────────────────────────────────────────┐" >&2
    echo "│  Auto-updating: $local_ver → $remote_ver" >&2
    echo "└─────────────────────────────────────────────────────┘" >&2

    # Check if we're in a git repository
    if git -C "$SKILL_DIR/../.." rev-parse --git-dir >/dev/null 2>&1; then
      # Non-interactive git pull (stash local changes if any)
      (
        cd "$SKILL_DIR/../.." || exit 0
        git stash push -q -m "Auto-stash before skill update" 2>/dev/null || true
        git pull -q origin main 2>/dev/null || git pull -q 2>/dev/null || true
        git stash pop -q 2>/dev/null || true
      ) >/dev/null 2>&1 || {
        echo "│  Auto-update failed. Run manually:                  │" >&2
        echo "│  cd $(dirname "$SKILL_DIR") && git pull            │" >&2
      }
    else
      # Fallback: notify user to update manually
      echo "│  Not a git repo. Run: npx skills add marswaveai/skills │" >&2
    fi
  # Patch mismatch → notify only (optional update)
  elif [ "$local_patch" != "$remote_patch" ]; then
    echo "┌─────────────────────────────────────────────────────┐" >&2
    echo "│  Patch update available: $local_ver → $remote_ver" >&2
    echo "│  Run: cd $(dirname "$SKILL_DIR") && git pull      │" >&2
    echo "└─────────────────────────────────────────────────────┘" >&2
  fi
}

# Run version check (auto-update via git if available)
check_version

# Load API key from shell config (try multiple sources)
# Note: source may fail on zsh-specific syntax, so we use || true
if [ -n "${LISTENHUB_API_KEY:-}" ]; then
  : # Already set, skip loading
elif [ -f ~/.zshrc ]; then
  # Extract just the export line to avoid zsh syntax issues
  eval "$(grep 'export LISTENHUB_API_KEY' ~/.zshrc 2>/dev/null || true)"
elif [ -f ~/.bashrc ]; then
  eval "$(grep 'export LISTENHUB_API_KEY' ~/.bashrc 2>/dev/null || true)"
fi

# === Environment Checks ===

check_curl() {
  if ! command -v curl &>/dev/null; then
    echo "Error: curl not found (should be pre-installed on most systems)" >&2
    exit 127
  fi
}

check_api_key() {
  if [ -z "${LISTENHUB_API_KEY:-}" ]; then
    cat >&2 <<'EOF'
Error: LISTENHUB_API_KEY not set

Setup:
  1. Get API key from https://listenhub.ai/zh/settings/api-keys
  2. Add to ~/.zshrc or ~/.bashrc:
     export LISTENHUB_API_KEY="lh_sk_..."
  3. Run: source ~/.zshrc
EOF
    exit 1
  fi
}

# Run checks
check_curl
check_api_key

# === API Helpers ===

API_BASE="https://api.marswave.ai/openapi/v1"

# Make authenticated POST request with JSON body
# Usage: api_post "endpoint" 'json_body'
api_post() {
  local endpoint="$1"
  local body="$2"

  curl -sS -X POST "${API_BASE}/${endpoint}" \
    -H "Authorization: Bearer ${LISTENHUB_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

# Make authenticated GET request
# Usage: api_get "endpoint"
api_get() {
  local endpoint="$1"

  curl -sS -X GET "${API_BASE}/${endpoint}" \
    -H "Authorization: Bearer ${LISTENHUB_API_KEY}"
}
