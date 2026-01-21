#!/usr/bin/env bash
# Create TTS audio via ListenHub API
# Usage: ./create-tts.sh "text content" [mode]
# Modes: smart (default) | direct

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

TEXT="${1:-}"
MODE="${2:-smart}"

if [ -z "$TEXT" ]; then
  echo "Usage: $0 \"text content\" [mode]" >&2
  echo "Modes: smart | direct" >&2
  exit 1
fi

# Use jq for safe JSON encoding if available
if command -v jq &>/dev/null; then
  TEXT_JSON=$(jq -n --arg t "$TEXT" '$t')
else
  TEXT_JSON="\"${TEXT//\"/\\\"}\""
fi

api_post "flowspeech/episodes" "{
  \"sources\": [{\"type\": \"text\", \"content\": ${TEXT_JSON}}],
  \"speakers\": [{\"speakerId\": \"CN-Man-Beijing-V2\"}],
  \"language\": \"zh\",
  \"mode\": \"${MODE}\"
}"
