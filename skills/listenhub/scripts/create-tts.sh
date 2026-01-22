#!/usr/bin/env bash
# Create FlowSpeech audio via ListenHub API
# Usage: ./create-tts.sh <type> "content" [mode]
# Types: text | url
# Modes: smart (default) | direct
#
# Examples:
#   ./create-tts.sh text "欢迎使用 ListenHub 音频生成服务" smart
#   ./create-tts.sh url "https://example.com/article.html" smart

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

TYPE="${1:-}"
CONTENT="${2:-}"
MODE="${3:-smart}"

if [ -z "$TYPE" ] || [ -z "$CONTENT" ]; then
  cat >&2 <<'EOF'
Usage: ./create-tts.sh <type> "content" [mode]

Types:
  text  - Direct text content (minimum 10 characters)
  url   - URL to read from

Modes: smart | direct

Examples:
  ./create-tts.sh text "欢迎使用 ListenHub 音频生成服务" smart
  ./create-tts.sh url "https://example.com/article.html" smart
EOF
  exit 1
fi

# Validate type
if [[ ! "$TYPE" =~ ^(text|url)$ ]]; then
  echo "Error: Invalid type '$TYPE'. Must be: text | url" >&2
  exit 1
fi

# Use jq for safe JSON encoding if available
if command -v jq &>/dev/null; then
  CONTENT_JSON=$(jq -n --arg c "$CONTENT" '$c')
else
  CONTENT_JSON="\"${CONTENT//\"/\\\"}\""
fi

api_post "flow-speech/episodes" "{
  \"sources\": [{\"type\": \"${TYPE}\", \"content\": ${CONTENT_JSON}}],
  \"speakers\": [{\"speakerId\": \"CN-Man-Beijing-V2\"}],
  \"language\": \"zh\",
  \"mode\": \"${MODE}\"
}"
