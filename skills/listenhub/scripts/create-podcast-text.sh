#!/usr/bin/env bash
# Create podcast text content (Stage 1 of two-stage generation)
# Usage: ./create-podcast-text.sh --query <text> --language zh|en --mode quick|deep|debate --speakers <id1,id2> [--source-url <url>] [--source-text <text>]
#
# Examples:
#   ./create-podcast-text.sh --query "AI 的未来发展" --language zh --mode deep --speakers cozy-man-english
#   ./create-podcast-text.sh --query "分析这篇文章" --language en --mode deep --speakers cozy-man-english --source-url "https://blog.example.com/article"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUERY=""
LANGUAGE=""
MODE="quick"
SPEAKERS=""
SOURCE_URLS=()
SOURCE_TEXTS=()

usage() {
  cat >&2 <<'EOF'
Usage: ./create-podcast-text.sh --query <text> --language zh|en --mode quick|deep|debate --speakers <id1,id2> [--source-url <url>] [--source-text <text>]

Examples:
  ./create-podcast-text.sh --query "AI 的未来发展" --language zh --mode deep --speakers cozy-man-english
  ./create-podcast-text.sh --query "分析这篇文章" --language en --mode deep --speakers cozy-man-english --source-url "https://blog.example.com/article"

Note: This only generates text content. Use create-podcast-audio.sh to generate audio.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --query)
      QUERY="${2:-}"
      shift 2
      ;;
    --language|--lang)
      LANGUAGE="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-quick}"
      shift 2
      ;;
    --speakers)
      SPEAKERS="${2:-}"
      shift 2
      ;;
    --source-url)
      SOURCE_URLS+=("${2:-}")
      shift 2
      ;;
    --source-text)
      SOURCE_TEXTS+=("${2:-}")
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

if [ -z "$QUERY" ] || [ -z "$LANGUAGE" ] || [ -z "$SPEAKERS" ]; then
  echo "Error: --query, --language, and --speakers are required" >&2
  usage
  exit 1
fi

if [[ ! "$LANGUAGE" =~ ^(zh|en)$ ]]; then
  echo "Error: language must be zh or en" >&2
  exit 1
fi

if [[ ! "$MODE" =~ ^(quick|deep|debate)$ ]]; then
  echo "Error: mode must be quick, deep, or debate" >&2
  exit 1
fi

SPEAKER_IDS=()
IFS=',' read -r -a SPEAKER_ITEMS <<< "$SPEAKERS"
for speaker_item in "${SPEAKER_ITEMS[@]}"; do
  speaker_item=$(trim_ws "$speaker_item")
  if [ -n "$speaker_item" ]; then
    SPEAKER_IDS+=("$speaker_item")
  fi
done
if [ ${#SPEAKER_IDS[@]} -lt 1 ] || [ ${#SPEAKER_IDS[@]} -gt 2 ]; then
  echo "Error: speakers must contain 1-2 items" >&2
  exit 1
fi

if [ "$MODE" = "debate" ] && [ ${#SPEAKER_IDS[@]} -ne 2 ]; then
  echo "Error: debate mode requires 2 speakers" >&2
  exit 1
fi

SOURCE_URLS_CLEAN=()
for url in "${SOURCE_URLS[@]}"; do
  url=$(trim_ws "$url")
  if [ -n "$url" ]; then
    SOURCE_URLS_CLEAN+=("$url")
  fi
done
SOURCE_TEXTS_CLEAN=()
for text in "${SOURCE_TEXTS[@]}"; do
  text=$(trim_ws "$text")
  if [ -n "$text" ]; then
    SOURCE_TEXTS_CLEAN+=("$text")
  fi
done

if command -v jq &>/dev/null; then
  QUERY_JSON=$(jq -n --arg q "$QUERY" '$q')
  SPEAKERS_JSON=$(printf '%s\n' "${SPEAKER_IDS[@]}" | jq -R '{speakerId: .}' | jq -s '.')
  SOURCES_JSON="[]"
  if [ ${#SOURCE_URLS_CLEAN[@]} -gt 0 ] || [ ${#SOURCE_TEXTS_CLEAN[@]} -gt 0 ]; then
    SOURCES_JSON=$(
      {
        printf '%s\n' "${SOURCE_URLS_CLEAN[@]}" | jq -R '{type: "url", content: .}'
        printf '%s\n' "${SOURCE_TEXTS_CLEAN[@]}" | jq -R '{type: "text", content: .}'
      } | jq -s '.'
    )
  fi

  if [ "$(echo "$SOURCES_JSON" | jq 'length')" -gt 0 ]; then
    BODY=$(jq -n \
      --argjson query "$QUERY_JSON" \
      --argjson speakers "$SPEAKERS_JSON" \
      --arg lang "$LANGUAGE" \
      --arg mode "$MODE" \
      --argjson sources "$SOURCES_JSON" \
      '{query: $query, speakers: $speakers, language: $lang, mode: $mode, sources: $sources}')
  else
    BODY=$(jq -n \
      --argjson query "$QUERY_JSON" \
      --argjson speakers "$SPEAKERS_JSON" \
      --arg lang "$LANGUAGE" \
      --arg mode "$MODE" \
      '{query: $query, speakers: $speakers, language: $lang, mode: $mode}')
  fi
else
  QUERY_ESCAPED=$(json_escape "$QUERY")
  SPEAKERS_JSON=""
  for speaker_id in "${SPEAKER_IDS[@]}"; do
    speaker_escaped=$(json_escape "$speaker_id")
    if [ -n "$SPEAKERS_JSON" ]; then
      SPEAKERS_JSON="${SPEAKERS_JSON},"
    fi
    SPEAKERS_JSON="${SPEAKERS_JSON}{\"speakerId\":\"${speaker_escaped}\"}"
  done
  SPEAKERS_JSON="[${SPEAKERS_JSON}]"

  SOURCES_JSON=""
  for url in "${SOURCE_URLS_CLEAN[@]}"; do
    url_escaped=$(json_escape "$url")
    if [ -n "$SOURCES_JSON" ]; then
      SOURCES_JSON="${SOURCES_JSON},"
    fi
    SOURCES_JSON="${SOURCES_JSON}{\"type\":\"url\",\"content\":\"${url_escaped}\"}"
  done
  for text in "${SOURCE_TEXTS_CLEAN[@]}"; do
    text_escaped=$(json_escape "$text")
    if [ -n "$SOURCES_JSON" ]; then
      SOURCES_JSON="${SOURCES_JSON},"
    fi
    SOURCES_JSON="${SOURCES_JSON}{\"type\":\"text\",\"content\":\"${text_escaped}\"}"
  done

  if [ -n "$SOURCES_JSON" ]; then
    BODY="{\"query\":\"${QUERY_ESCAPED}\",\"sources\":[${SOURCES_JSON}],\"speakers\":${SPEAKERS_JSON},\"language\":\"${LANGUAGE}\",\"mode\":\"${MODE}\"}"
  else
    BODY="{\"query\":\"${QUERY_ESCAPED}\",\"speakers\":${SPEAKERS_JSON},\"language\":\"${LANGUAGE}\",\"mode\":\"${MODE}\"}"
  fi
fi

api_post "podcast/episodes/text-content" "$BODY"
