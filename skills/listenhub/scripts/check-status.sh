#!/usr/bin/env bash
# Check episode status via ListenHub API
# Usage: ./check-status.sh --episode <episode-id> --type podcast|flow-speech|explainer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

EPISODE_ID=""
TYPE="podcast"

usage() {
  echo "Usage: $0 --episode <episode-id> --type podcast|flow-speech|tts|explainer" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --episode)
      EPISODE_ID="${2:-}"
      shift 2
      ;;
    --type)
      TYPE="${2:-podcast}"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$EPISODE_ID" ]; then
  echo "Error: --episode is required" >&2
  usage
  exit 1
fi

case "$TYPE" in
  podcast)
    ENDPOINT="podcast/episodes/${EPISODE_ID}"
    ;;
  explainer)
    ENDPOINT="storybook/episodes/${EPISODE_ID}"
    ;;
  flow-speech|tts)
    ENDPOINT="flow-speech/episodes/${EPISODE_ID}"
    ;;
  *)
    echo "Error: Invalid type '$TYPE'. Must be: podcast | flow-speech | tts | explainer" >&2
    exit 1
    ;;
esac

api_get "$ENDPOINT"
