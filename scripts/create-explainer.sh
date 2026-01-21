#!/usr/bin/env bash
# Create explainer video via ListenHub API
# Usage: ./create-explainer.sh "topic or content" [mode]
# Modes: info (default) | story

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

CONTENT="${1:-}"
MODE="${2:-info}"

if [ -z "$CONTENT" ]; then
  echo "Usage: $0 \"topic or content\" [mode]" >&2
  echo "Modes: info | story" >&2
  exit 1
fi

# Use jq for safe JSON encoding if available
if command -v jq &>/dev/null; then
  CONTENT_JSON=$(jq -n --arg c "$CONTENT" '$c')
else
  CONTENT_JSON="\"${CONTENT//\"/\\\"}\""
fi

api_post "storybook/episodes" "{
  \"sources\": [{\"type\": \"text\", \"content\": ${CONTENT_JSON}}],
  \"speakers\": [{\"speakerId\": \"CN-Man-Beijing-V2\"}],
  \"language\": \"zh\",
  \"mode\": \"${MODE}\"
}"
