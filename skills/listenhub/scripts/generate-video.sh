#!/usr/bin/env bash
# Generate video file from explainer episode
# Usage: ./generate-video.sh <episode-id>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

EPISODE_ID="${1:-}"

if [ -z "$EPISODE_ID" ]; then
  echo "Usage: $0 <episode-id>" >&2
  exit 1
fi

api_post "storybook/episodes/${EPISODE_ID}/video" "{}"
