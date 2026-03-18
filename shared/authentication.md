# Authentication

## API Key

All ListenHub API calls require a valid API key.

**Environment variable**: `LISTENHUB_API_KEY`

Store in `~/.zshrc` (macOS) or `~/.bashrc` (Linux):

```bash
export LISTENHUB_API_KEY="lh_sk_..."
```

Reload after adding:

```bash
source ~/.zshrc
```

**How to obtain**: Visit https://listenhub.ai/settings/api-keys (Pro plan required).

## Base URLs

| Service | Base URL |
|---------|----------|
| ListenHub API | `https://api.marswave.ai/openapi/v1` |
| Image Generation | `https://api.marswave.ai/openapi/v1` |
| Staging (ListenHub) | `https://staging-api.marswave.ai/openapi/v1` |

## Required Headers

Every request must include:

```
Authorization: Bearer $LISTENHUB_API_KEY
Content-Type: application/json
```

## curl Template

```bash
curl -sS -X POST "https://api.marswave.ai/openapi/v1/{endpoint}" \
  -H "Authorization: Bearer $LISTENHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

For GET requests, omit `-d` and change `-X POST` to `-X GET`.

## Security Notes

- Never log or display full API keys in output
- API keys are transmitted via HTTPS only
- Do not pass sensitive or confidential information as content input — it is sent to external APIs for processing
