---
name: google-calendar
description: Use the bundled Google Workspace CLI (gws) to read, create, update, and delete Google Calendar events, list calendars, and show agendas. Use when the user asks to connect or operate Google Calendar, or to manage events on their Google Calendar, or says "谷歌日历"、"Google 日历"、"看看我 Google 日历上的安排".
metadata:
  version: 1.0.4
  requires:
    bins: ["gws"]
---

# Google Calendar (gws)

This Skill targets exactly `gws 0.22.5`.

## Locate the executable

Always use the copy bundled with this Skill; never a `gws` that happens to be on `PATH`, which may be an unrelated version. Resolve it once per session:

1. Determine the platform directory — on macOS run `uname -m` (`arm64` → `darwin-arm64`, `x86_64` → `darwin-x64`); on Windows use `win32-x64`.
2. Resolve `scripts/bin/<platform>/gws` against this document's directory — on Windows the file is `gws.exe` — and use that absolute path for every command below.

This package ships macOS and Windows builds only; on any other platform report that Google Calendar is not available there rather than looking for another installation.

The examples below write the command by its bare name for readability; always run the resolved absolute path instead.

If that file is missing, report that Google Calendar is not ready yet — never describe it as an account problem or a broken connector.

## Talk to the user

These rules govern what you SAY to the user. They never change which commands you RUN.

- **Product words are fine.** 配置、授权、连接、账号、日程 — the user should always know which step they are in.
- **Implementation details never reach the user.** Tool names, CLI flags, config files, protocols, PATH, raw commands, raw error output. Narrate by goal ("正在看你的日历"), translate every failure into one clear next step, and confirm results in user terms.

## 使用场景

- 查日程:"看看我明天谷歌日历有哪些安排""这周有没有空的整段下午"
- 建与改:"帮我在周四下午约一个一小时的评审会,拉上 Alice""把周会挪到十点"
- 汇总:"把下周的日程整理成一份议程"

**When the request names no provider.** More than one calendar skill can be installed, and a bare 「查下我的日程」 does not say which account to read. Use this skill without asking only when it is the only calendar connected, or when the conversation already established that Google Calendar is the one in play. Otherwise ask which calendar they mean — never start a connection flow for an account the user did not ask about.

This installation is **calendar-only**. Authorization covers Google Calendar and nothing else: other Google services (`gmail`, `drive`, `sheets`, `docs`, `tasks`, …) will fail with permission errors. Do not attempt them, and do not suggest them as available.

## Configuration directory

`gws` stores OAuth client files and tokens in one config directory:

- If `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` is set and non-empty, **every** `gws` command in this skill must use that directory. Keep it in the environment. Do not unset it, overwrite it, or pass a different `--config` path.
- If it is unset or empty, `gws` uses its own default directory (`~/.config/gws` on Unix; `%USERPROFILE%\.config\gws` on Windows).

Check `printenv GOOGLE_WORKSPACE_CLI_CONFIG_DIR` (Unix) or `$env:GOOGLE_WORKSPACE_CLI_CONFIG_DIR` (PowerShell) once per session and treat that value as the profile for login, status, and calendar commands.

## Authorization

This skill is **calendar-only**. Login must request exactly these scopes (comma-separated, no spaces):

`openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/userinfo.profile,https://www.googleapis.com/auth/calendar.events,https://www.googleapis.com/auth/calendar.calendarlist.readonly`

Never set `GOOGLE_APPLICATION_CREDENTIALS`. Never run a default `gws auth login` without `--scopes` — the default set includes Drive, Gmail, and other services this skill must not request.

1. Run `gws auth status` with the same per-invocation proxy wrap as login when a proxy is present (`references/proxy.md`). If credentials already exist and calendar commands succeed, skip login.
2. If the user asks to connect Google Calendar, or status/calendar calls fail with authorization errors, run:

```bash
gws auth login --scopes 'openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/userinfo.profile,https://www.googleapis.com/auth/calendar.events,https://www.googleapis.com/auth/calendar.calendarlist.readonly'
```

`gws` prints a Google URL. Give that URL to the user, wait until they finish in the browser, then run `gws auth status` and a read-only calendar probe before doing writes. Wrap those the same way as login when a proxy is present.

3. If login says no OAuth client is configured, run `gws auth setup` **without** `--login`, or set `GOOGLE_WORKSPACE_CLI_CLIENT_ID` and `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` for that invocation — these are `gws` native client settings, not extra product config. Do not invent a client id. Setup may ask `Run gws auth login now? [Y/n]`; answer `n`. Never accept that default login: it requests Drive, Gmail, and other services this skill must not grant. After setup, run the scoped `gws auth login --scopes` command in step 2.

4. Do not start a second login while one is waiting for the browser.

## Network and troubleshooting

`gws` takes its route **only** from the environment of each invocation. Operating-system proxy settings are a discovery source, not a route: a proxy configured in macOS or Windows settings but absent from this process is not used, so reading it and then running `gws` unchanged tests the direct route while appearing to test the proxy.

This build reads `https_proxy` / `HTTPS_PROXY`, `http_proxy` / `HTTP_PROXY`, and `all_proxy` / `ALL_PROXY`. Token exchange and Calendar API calls are HTTPS (`oauth2.googleapis.com`, `www.googleapis.com`). Prefer HTTP CONNECT (`https_proxy=http://HOST:PORT`). Mixing SOCKS `all_proxy` with an HTTP proxy often fails token exchange (`Hyper error: client error (Connect)`); when the device has both, use the HTTP proxy on that invocation and clear `all_proxy` / `ALL_PROXY`. If only `http_proxy` is set, copy it onto `https_proxy` for the invocation.

`gws auth status` can refresh a token through `oauth2.googleapis.com` and call user-info; it is not local-only. Wrap it with the same per-invocation proxy as login. A successful status still does not prove the Calendar API route. On many networks the Google HTTPS hosts are unreachable directly even when this chat still works. If an HTTP or HTTPS proxy is already on the device, apply it to the **first** `gws auth status`, `gws auth login`, and calendar command — do not wait for a timeout.

Read `references/proxy.md` before the first `gws auth status`, login, or calendar API call when any of these applies:

- proxy variables or an operating-system HTTP/HTTPS/SOCKS proxy are present
- the current network may block Google HTTPS
- the failure mentions proxy, timeout, connect, TLS, unreachable, or `Hyper error`

That guide is the routing procedure: discover, wrap **that one** `gws` invocation, recover. Do not change the user's global proxy settings. Do not treat a hang after `Using keyring backend: keyring` as an empty calendar or expired authorization. Leave `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` unchanged. Do not dump raw `gws` output.

### Scope boundaries

The granted scopes allow exactly:

- `events` — full read/write on calendar events
- `calendarList` — read-only (`list`, `get`)

Out of scope (will fail; do not call): calendar `acl`, creating/deleting calendars (`calendars insert/delete/clear`), `settings`, `channels`/`watch` subscriptions, and every non-calendar service.

## Helper commands

### Show agenda (read-only)

```bash
gws calendar +agenda --timezone <IANA>
```

| Flag | Description |
|------|-------------|
| `--today` | Show today's events |
| `--tomorrow` | Show tomorrow's events |
| `--week` | Show this week's events |
| `--days <N>` | Number of days ahead to show |
| `--calendar <NAME_OR_ID>` | Filter to a specific calendar |
| `--timezone <IANA>` | Timezone override (e.g. `Asia/Shanghai`). **Always pass it** — see below |

```bash
gws calendar +agenda --today --timezone 'Asia/Shanghai'
gws calendar +agenda --week --format table --timezone 'Asia/Shanghai'
gws calendar +agenda --days 3 --calendar 'Work' --timezone 'Asia/Shanghai'
```

Read-only — never modifies events. Queries all calendars by default.

Always pass `--timezone`. The helper's own default reads the account timezone from `settings`, which this installation's scopes exclude, so it silently falls back to the machine's local timezone — on a machine in a different timezone from the calendar, `--today` and `--week` then query the wrong day boundaries. Ask the user for their timezone, or take it from an event's own timezone, and pass it explicitly.

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
| `--attendee` | — | Attendee email (repeatable). Does **not** notify them — see below |
| `--meet` | — | Add a Google Meet link |

```bash
gws calendar +insert --summary 'Standup' --start '2026-06-17T09:00:00+08:00' --end '2026-06-17T09:30:00+08:00'
gws calendar +insert --summary 'Review' --start ... --end ... --attendee alice@example.com --meet
```

> [!CAUTION]
> This is a **write** command — confirm with the user before executing.

**Attendees are not notified by `+insert`.** The helper does not set the Calendar API's `sendUpdates` parameter, whose default is to send nothing, so the guest is added to the event but receives no invitation. When the user's intent is to invite someone, create the event through the resource-level command with that parameter instead, then tell the user the invitation went out:

```bash
gws calendar events insert \
  --params '{"calendarId":"primary","sendUpdates":"all"}' \
  --json '{"summary":"Review","start":{"dateTime":"2026-06-17T09:00:00+08:00"},"end":{"dateTime":"2026-06-17T10:00:00+08:00"},"attendees":[{"email":"alice@example.com"}]}'
```

`+insert --meet` adds the Meet link automatically, but this resource-level form does not — request the conference explicitly, or the invitation goes out without a way to join:

```bash
gws calendar events insert \
  --params '{"calendarId":"primary","sendUpdates":"all","conferenceDataVersion":1}' \
  --json '{"summary":"Review","start":{"dateTime":"2026-06-17T09:00:00+08:00"},"end":{"dateTime":"2026-06-17T10:00:00+08:00"},"attendees":[{"email":"alice@example.com"}],"conferenceData":{"createRequest":{"requestId":"<unique-string>","conferenceSolutionKey":{"type":"hangoutsMeet"}}}}'
```

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
- `patch` — modify an event; **use this for every edit**. When the event has attendees, add `"sendUpdates":"all"` to `--params` so guests learn about the change — the default notifies nobody, leaving them on the old time
- `update` — full replacement; it drops attendees, recurrence, reminders, location and description when they are absent from the body, so only use it after fetching the complete event and round-tripping every field
- `delete` — delete an event. With attendees, pass `"sendUpdates":"all"` too, or guests keep a meeting the organizer already cancelled

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
