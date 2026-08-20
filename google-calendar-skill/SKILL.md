---
name: google-calendar
description: Use the bundled Google Workspace CLI (gws) to read, create, update, and delete Google Calendar events, list calendars, and show agendas. Use when the user asks to connect or operate Google Calendar, check their schedule, or manage Google Calendar events, or says "谷歌日历"、"Google 日历"、"查下我的日程"、"明天有什么安排".
metadata:
  version: 1.0.1
  requires:
    bins: ["gws"]
---

# Google Calendar (gws)

This Skill targets exactly `gws 0.22.5`.

## Locate the executable

Always use the copy bundled with this Skill; never a `gws` that happens to be on `PATH`, which may be an unrelated version. Resolve it once per session:

1. Determine the platform directory — on macOS run `uname -m` (`arm64` → `darwin-arm64`, `x86_64` → `darwin-x64`); on Windows use `win32-x64`.
2. Resolve `scripts/bin/<platform>/gws` against this document's directory and use that absolute path for every command below.

This package ships macOS and Windows builds only; on any other platform report that Google Calendar is not available there rather than looking for another installation.

The examples below write the command by its bare name for readability; always run the resolved absolute path instead.

If that file is missing, report that Google Calendar is not ready yet — never describe it as an account problem or a broken connector.

## Talk like Cola

These rules govern what you SAY to the user. They never change which commands you RUN.

- **Product words are fine.** 配置、授权、连接、账号、日程、App 专用密码 — the user should always know which step they are in.
- **Implementation details never reach the user.** Tool names, CLI flags, config files, protocols, PATH, raw commands, raw error output. Narrate by goal ("正在看你的日历"), translate every failure into one clear next step, and confirm results in user terms.

## 使用场景

- 查日程:"看看我明天谷歌日历有哪些安排""这周有没有空的整段下午"
- 建与改:"帮我在周四下午约一个一小时的评审会,拉上 Alice""把周会挪到十点"
- 汇总:"把下周的日程整理成一份议程"

This installation is **calendar-only**. Authorization covers Google Calendar and nothing else: other Google services (`gmail`, `drive`, `sheets`, `docs`, `tasks`, …) will fail with permission errors. Do not attempt them, and do not suggest them as available.

## Authorization

OAuth is managed by Cola with calendar-only scopes (`calendar.events` plus read-only calendar list). Credentials are already configured for the `gws` command you invoke.

- **Never run `gws auth login`** or any other interactive auth flow, and never set `GOOGLE_APPLICATION_CREDENTIALS`. Authorization is done by the user in Cola's app center.
- If a command fails with an authorization or permission error, tell the user to open the Google Calendar app in Cola's Skill settings and complete or renew authorization there. Do not retry in a loop.

### Scope boundaries

The granted scopes allow exactly:

- `events` — full read/write on calendar events
- `calendarList` — read-only (`list`, `get`)

Out of scope (will fail; do not call): calendar `acl`, creating/deleting calendars (`calendars insert/delete/clear`), `settings`, `channels`/`watch` subscriptions, and every non-calendar service.

## Helper commands

### Show agenda (read-only)

```bash
gws calendar +agenda
```

| Flag | Description |
|------|-------------|
| `--today` | Show today's events |
| `--tomorrow` | Show tomorrow's events |
| `--week` | Show this week's events |
| `--days <N>` | Number of days ahead to show |
| `--calendar <NAME_OR_ID>` | Filter to a specific calendar |
| `--timezone <IANA>` | Timezone override (e.g. `Asia/Shanghai`); defaults to the Google account timezone |

```bash
gws calendar +agenda --today
gws calendar +agenda --week --format table
gws calendar +agenda --days 3 --calendar 'Work'
```

Read-only — never modifies events. Queries all calendars by default.

### Create an event

```bash
gws calendar +insert --summary <TEXT> --start <TIME> --end <TIME>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--summary` | ✓ | Event title |
| `--start` | ✓ | Start time (RFC 3339, e.g. `2026-06-17T09:00:00+08:00`) |
| `--end` | ✓ | End time (RFC 3339) |
| `--calendar` | — | Calendar ID (default: `primary`) |
| `--location` | — | Event location |
| `--description` | — | Event description/body |
| `--attendee` | — | Attendee email (repeatable) |
| `--meet` | — | Add a Google Meet link |

```bash
gws calendar +insert --summary 'Standup' --start '2026-06-17T09:00:00+08:00' --end '2026-06-17T09:30:00+08:00'
gws calendar +insert --summary 'Review' --start ... --end ... --attendee alice@example.com --meet
```

> [!CAUTION]
> This is a **write** command — confirm with the user before executing.

## API resources (within scope)

```bash
gws calendar <resource> <method> [flags]
```

### events

- `list` — events on a calendar (`--params '{"calendarId":"primary","timeMin":"...","timeMax":"...","singleEvents":true,"orderBy":"startTime"}'`)
- `get` — one event by ID
- `instances` — instances of a recurring event
- `insert` — create an event (prefer `+insert`)
- `quickAdd` — create an event from a text string
- `patch` / `update` — modify an event
- `delete` — delete an event

### calendarList (read-only)

- `list` — calendars on the user's calendar list
- `get` — one calendar-list entry

## Method flags

| Flag | Description |
|------|-------------|
| `--params '{"key": "val"}'` | URL/query parameters |
| `--json '{"key": "val"}'` | Request body (POST/PATCH/PUT) |
| `--format <FMT>` | Output format: `json` (default), `table`, `yaml`, `csv` |
| `--dry-run` | Validate locally without calling the API |
| `--page-all` | Auto-paginate (NDJSON output) |
| `--page-limit <N>` | Max pages with `--page-all` (default: 10) |

Wrap `--params` and `--json` values in single quotes so the shell does not interpret the inner double quotes.

## Discovering commands

```bash
gws calendar --help
gws schema calendar.<resource>.<method>   # required params, types, defaults
```

Use `gws schema` output to build `--params` and `--json`.

## Security rules

- **Never** output secrets (tokens, credential files) directly.
- **Always** confirm with the user before executing write or delete commands.
- Prefer `--dry-run` first for destructive operations.
- Use RFC 3339 times with explicit offsets; respect the user's timezone (`--timezone` on `+agenda`).
