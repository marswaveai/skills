#!/usr/bin/env bash
# Create podcast episode via ListenHub API
# Usage: ./create-podcast.sh <type> "content" [mode]
# Types: query | url
# Modes: quick (default) | deep | debate
#
# Examples:
#   ./create-podcast.sh query "AI 的未来发展" deep
#   ./create-podcast.sh url "https://youtube.com/watch?v=xxx" quick

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

TYPE="${1:-}"
CONTENT="${2:-}"
MODE="${3:-quick}"

if [ -z "$TYPE" ] || [ -z "$CONTENT" ]; then
  cat >&2 <<'EOF'
Usage: ./create-podcast.sh <type> "content" [mode]

Types:
  query  - Topic or search query
  url    - URL to analyze (YouTube, article, etc.)

Modes: quick | deep | debate

Examples:
  ./create-podcast.sh query "AI 的未来发展" deep
  ./create-podcast.sh url "https://youtube.com/watch?v=xxx"
EOF
  exit 1
fi

# Use jq for safe JSON encoding if available
if command -v jq &>/dev/null; then
  CONTENT_JSON=$(jq -n --arg c "$CONTENT" '$c')
else
  CONTENT_JSON="\"${CONTENT//\"/\\\"}\""
fi

# Build request body based on type
case "$TYPE" in
  query)
    BODY="{
      \"query\": ${CONTENT_JSON},
      \"speakers\": [
        {\"speakerId\": \"CN-Man-Beijing-V2\"},
        {\"speakerId\": \"chat-girl-105-cn\"}
      ],
      \"language\": \"zh\",
      \"mode\": \"${MODE}\"
    }"
    ;;
  url)
    BODY="{
      \"sources\": [{\"type\": \"url\", \"content\": ${CONTENT_JSON}}],
      \"speakers\": [
        {\"speakerId\": \"CN-Man-Beijing-V2\"},
        {\"speakerId\": \"chat-girl-105-cn\"}
      ],
      \"language\": \"zh\",
      \"mode\": \"${MODE}\"
    }"
    ;;
  *)
    echo "Error: Invalid type '$TYPE'. Must be: query | url" >&2
    exit 1
    ;;
esac

api_post "podcast/episodes" "$BODY"
