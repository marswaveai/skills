#!/usr/bin/env bash
# Generate audio from podcast text content (Stage 2 of two-stage generation)
# Usage: ./create-podcast-audio.sh <episode-id> [scripts_json_file]
#
# Examples:
#   # Use original scripts
#   ./create-podcast-audio.sh "68d699ebc4b373bd1ae50dde"
#
#   # Use modified scripts
#   ./create-podcast-audio.sh "68d699ebc4b373bd1ae50dde" modified-scripts.json
#
# modified-scripts.json format:
# {
#   "scripts": [
#     {"content": "Hello everyone", "speakerId": "CN-Man-Beijing-V2"},
#     {"content": "Welcome", "speakerId": "chat-girl-105-cn"}
#   ]
# }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

EPISODE_ID="${1:-}"
SCRIPTS_FILE="${2:-}"

if [ -z "$EPISODE_ID" ]; then
  cat >&2 <<'EOF'
Usage: ./create-podcast-audio.sh <episode-id> [scripts_json_file]

Examples:
  # Use original scripts
  ./create-podcast-audio.sh "68d699ebc4b373bd1ae50dde"

  # Use modified scripts
  ./create-podcast-audio.sh "68d699ebc4b373bd1ae50dde" modified-scripts.json

modified-scripts.json format:
{
  "scripts": [
    {"content": "Hello everyone", "speakerId": "CN-Man-Beijing-V2"},
    {"content": "Welcome", "speakerId": "chat-girl-105-cn"}
  ]
}
EOF
  exit 1
fi

# Build request body
if [ -n "$SCRIPTS_FILE" ]; then
  if [ ! -f "$SCRIPTS_FILE" ]; then
    echo "Error: File not found: $SCRIPTS_FILE" >&2
    exit 1
  fi

  BODY=$(cat "$SCRIPTS_FILE")

  # Validate JSON format
  if command -v jq &>/dev/null; then
    if ! echo "$BODY" | jq empty 2>/dev/null; then
      echo "Error: Invalid JSON format" >&2
      exit 1
    fi
  fi
else
  BODY="{}"
fi

curl -sS -X POST "${API_BASE}/podcast/episodes/${EPISODE_ID}/audio" \
  -H "Authorization: Bearer ${LISTENHUB_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY"
