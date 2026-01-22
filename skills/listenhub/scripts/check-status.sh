#!/usr/bin/env bash
# Check episode status via ListenHub API
# Usage: ./check-status.sh <episode-id> <type>
# Types: podcast | explainer | tts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

EPISODE_ID="${1:-}"
TYPE="${2:-podcast}"

if [ -z "$EPISODE_ID" ]; then
  echo "Usage: $0 <episode-id> <type>" >&2
  echo "Types: podcast | explainer | tts" >&2
  exit 1
fi

case "$TYPE" in
  podcast)
    ENDPOINT="podcast/episodes/${EPISODE_ID}"
    ;;
  explainer)
    ENDPOINT="storybook/episodes/${EPISODE_ID}"
    ;;
  tts)
    ENDPOINT="flow-speech/episodes/${EPISODE_ID}"
    ;;
  *)
    echo "Error: Invalid type '$TYPE'. Must be: podcast | explainer | tts" >&2
    exit 1
    ;;
esac

api_get "$ENDPOINT"
