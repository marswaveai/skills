#!/usr/bin/env bash
# Create podcast episode via ListenHub API
# Usage: ./create-podcast.sh "query" [mode] [source_url]
# Modes: quick (default) | deep | debate
#
# Examples:
#   ./create-podcast.sh "AI 的未来发展" deep
#   ./create-podcast.sh "分析这篇文章的核心观点" deep "https://blog.example.com/article"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUERY="${1:-}"
MODE="${2:-quick}"
SOURCE_URL="${3:-}"

if [ -z "$QUERY" ]; then
  cat >&2 <<'EOF'
Usage: ./create-podcast.sh "query" [mode] [source_url]

Modes: quick | deep | debate

Examples:
  ./create-podcast.sh "AI 的未来发展" deep
  ./create-podcast.sh "讨论远程工作的利弊" debate
  ./create-podcast.sh "分析这篇文章" deep "https://blog.example.com/article"
EOF
  exit 1
fi

# Use jq for safe JSON encoding if available
if command -v jq &>/dev/null; then
  QUERY_JSON=$(jq -n --arg q "$QUERY" '$q')
  if [ -n "$SOURCE_URL" ]; then
    SOURCE_JSON=$(jq -n --arg s "$SOURCE_URL" '[{"type": "url", "content": $s}]')
  fi
else
  QUERY_JSON="\"${QUERY//\"/\\\"}\""
  if [ -n "$SOURCE_URL" ]; then
    SOURCE_JSON="[{\"type\": \"url\", \"content\": \"${SOURCE_URL//\"/\\\"}\"}]"
  fi
fi

# Build request body
if [ -n "$SOURCE_URL" ]; then
  BODY="{
  \"query\": ${QUERY_JSON},
  \"sources\": ${SOURCE_JSON},
  \"speakers\": [
    {\"speakerId\": \"CN-Man-Beijing-V2\"},
    {\"speakerId\": \"chat-girl-105-cn\"}
  ],
  \"language\": \"zh\",
  \"mode\": \"${MODE}\"
}"
else
  BODY="{
  \"query\": ${QUERY_JSON},
  \"speakers\": [
    {\"speakerId\": \"CN-Man-Beijing-V2\"},
    {\"speakerId\": \"chat-girl-105-cn\"}
  ],
  \"language\": \"zh\",
  \"mode\": \"${MODE}\"
}"
fi

api_post "podcast/episodes" "$BODY"
