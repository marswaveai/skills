#!/usr/bin/env bash
# Shared environment checks for ListenHub scripts
# Source this at the beginning of each script

set -euo pipefail

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
