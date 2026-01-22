#!/usr/bin/env bash
# Get available speakers list via ListenHub API
# Usage: ./get-speakers.sh [language]
# Languages: zh (default) | en

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

LANGUAGE="${1:-zh}"

if [[ ! "$LANGUAGE" =~ ^(zh|en)$ ]]; then
  echo "Error: Invalid language '$LANGUAGE'. Must be: zh | en" >&2
  exit 1
fi

api_get "speakers/list?language=${LANGUAGE}"
