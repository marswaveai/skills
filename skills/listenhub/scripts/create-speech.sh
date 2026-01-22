#!/usr/bin/env bash
# Create multi-speaker audio from scripts via ListenHub API
# Usage: ./create-speech.sh <scripts_json_file>
#
# Example:
#   ./create-speech.sh scripts.json
#
# scripts.json format:
# {
#   "scripts": [
#     {"content": "Hello everyone", "speakerId": "cozy-man-english"},
#     {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
#   ]
# }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

SCRIPTS_FILE="${1:-}"

if [ -z "$SCRIPTS_FILE" ]; then
  cat >&2 <<'EOF'
Usage: ./create-speech.sh <scripts_json_file>

Example:
  ./create-speech.sh scripts.json

scripts.json format:
{
  "scripts": [
    {"content": "Hello everyone", "speakerId": "cozy-man-english"},
    {"content": "Welcome to the show", "speakerId": "travel-girl-english"}
  ]
}

Or use inline JSON:
  echo '{"scripts":[{"content":"Hello","speakerId":"cozy-man-english"}]}' | ./create-speech.sh -
EOF
  exit 1
fi

# Read scripts from file or stdin
if [ "$SCRIPTS_FILE" = "-" ]; then
  BODY=$(cat)
else
  if [ ! -f "$SCRIPTS_FILE" ]; then
    echo "Error: File not found: $SCRIPTS_FILE" >&2
    exit 1
  fi
  BODY=$(cat "$SCRIPTS_FILE")
fi

# Validate JSON format
if command -v jq &>/dev/null; then
  if ! echo "$BODY" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON format" >&2
    exit 1
  fi
fi

api_post "speech" "$BODY"
