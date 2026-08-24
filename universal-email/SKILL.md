---
name: universal-email
description: Use the bundled Himalaya 2 CLI to connect IMAP/SMTP or Microsoft Graph mailboxes and list, search, read, compose, reply, forward, move, delete, flag, and download email. Use when the user asks to connect or operate Gmail, QQ Mail, iCloud Mail, Outlook, or another standard mailbox, or says "连接邮箱"、"绑定邮箱"、"看看我的邮件"、"查邮箱"、"发邮件"、"回复邮件".
metadata:
  version: 1.2.12
  requires:
    bins: ["himalaya"]
---

# Email (universal-email)

## Serve the user the Cola way

These rules govern everything you SAY. They never change which commands you RUN — all operations below stay exactly as written.

- **Product words are fine.** 配置、授权、连接、账号、授权码/App 专用密码 — the user should always know which step they are in.
- **Implementation details never reach the user.** `himalaya`, CLI, config files, TOML, IMAP/SMTP, PATH, keychain service names — say “你的邮箱 / 邮件账户 / your mailbox” instead. If the user explicitly asks how it works, then you may explain.
- **Narrate by goal, not by tooling.** “正在连接你的邮箱” “正在看你的收件箱”, never “running himalaya account list”.
- **Ask for the minimum, once.** Ask for the email address. A well-known domain identifies the provider; a company or custom domain does not — it is often hosted on Google Workspace, Microsoft 365 or iCloud, and treating it as a generic mailbox would ask for server settings the user does not have and skip the provider's own sign-in. Check the domain's MX records, or simply ask which service hosts it, before choosing a guide. Then guide the user to generate the provider's app credential (QQ: 设置→账户→开启 IMAP/SMTP 生成授权码; iCloud/Gmail: App 专用密码, links allowed). Do not ask again unless verification actually failed.
- **Credentials never enter the conversation.** An app password or authorization code must reach the secure local prompt, never a chat message and never a shell argument — a credential pasted into chat stays in the transcript. Ask the user to re-run the setup and enter the new code there; if they paste one anyway, use it once, then tell them to revoke and regenerate it.
- **Translate errors into next steps.** Never paste raw command output or stack traces. Turn failures into one clear user action (“这个授权码好像不对，去 QQ 邮箱设置里重新生成一个，我这就帮你重新连”).
- **Confirm in user terms.** Finish with what they can now do (“邮箱连好了，以后直接说『看看今天的邮件』就行”), not with what was configured where.

Use the bundled `himalaya` executable. This Skill targets exactly Himalaya `2.0.0` at revision `923414155f4281d681f4ea8631954f406acf51ee`; do not use Himalaya 1.x configuration fields or command examples.

## Locate the executable

Always use the copy bundled with this Skill; never a `himalaya` that happens to be on `PATH`, which may be an unrelated version. Resolve it once per session:

1. Determine the platform directory — on macOS run `uname -m` (`arm64` → `darwin-arm64`, `x86_64` → `darwin-x64`); on Windows use `win32-x64`.
2. Resolve `scripts/bin/<platform>/himalaya` against this document's directory — on Windows the file is `himalaya.exe` — and use that absolute path for every command below.

This package ships macOS and Windows builds only. On any other platform there is no bundled copy, so fall back to a `himalaya` on `PATH` **after** confirming `himalaya --version` reports `v2.0.0`; a different version there is unusable and should be reported as such.

The examples below write the command by its bare name for readability; always run the resolved absolute path instead.

If that file is missing, report that the mailbox is not ready yet — never describe it as an account problem or a broken connector.

For Outlook / Microsoft 365 Graph mail, also resolve `scripts/bin/<platform>/cola-outlook-mail-auth` the same way (Windows: `cola-outlook-mail-auth.exe`). You run that helper yourself. Never ask the user to run it, and never paste its path into chat. See `references/outlook.md`. Do not use the Himalaya setup wizard for Outlook.

Treat the active configuration of the executable you invoke as the source of truth: do not inspect candidate config files to choose one, or add `--config` merely because a file exists. Use `--config` only when the user explicitly requests a separate profile.

## 使用场景

- 绑定邮箱:"帮我连一下 QQ 邮箱""绑定我的 Gmail"
- 日常收发:"看看今天有什么新邮件""把这封转发给 Alice""回复他说我明天到"
- 整理与查找:"找一下上周报销相关的邮件""把这封标成已读""删掉这封"

## Choose the account

1. Confirm the resolved executable reports `himalaya v2.0.0`.
2. Run `himalaya --json account list`.
3. If the intended account exists, select it with the global `--account <name>` option.
4. If it does not exist, read the matching provider guide before asking the user for anything:
   - Gmail: `references/gmail.md`
   - QQ Mail: `references/qq.md`
   - iCloud Mail: `references/icloud.md`
   - Outlook/Microsoft 365: `references/outlook.md` (Graph OAuth via the bundled helper; never the Himalaya wizard)
   - Other IMAP/SMTP: `references/standard-imap-smtp.md`
5. If configuration is missing, use `references/configuration.md` for the Himalaya 2 TOML format and active-configuration rules.
6. Validate with `himalaya --account <name> --json account check` before any mailbox operation.

Do not ask for a normal account password when the provider requires an app password, authorization code, or OAuth. Never echo a secret, put it in command arguments, or store it as `password.raw`.

## Read operations

Prefer global `--json` for machine-readable output.

```bash
himalaya --account <name> --json mailbox list
himalaya --account <name> --json envelope list --mailbox inbox --page 1 --page-size 20
himalaya --account <name> --json envelope search --mailbox inbox from alice@example.com and subject report
himalaya --account <name> --json message read --mailbox inbox <message-id>
himalaya --account <name> --json attachment list --mailbox inbox <message-id>
himalaya --account <name> attachment download --mailbox inbox --dir <directory> <message-id> <attachment-id>
```

IDs are scoped to their mailbox. Re-list after switching mailboxes or after move/delete operations. Do not repeatedly fetch the same message when one `message read --json` result already contains the needed fields.

## Write operations

Show the final recipients, subject, and body to the user and obtain confirmation immediately before sending, replying, forwarding, moving, or deleting.

**Check the backend before writing.** `message compose|reply|forward --send` routes through SMTP or JMAP only, so an account on the Microsoft Graph backend cannot send with it. Read the account's backend from `account list` first; for a Graph account, send through `himalaya msgraph message send` with raw MIME and read `references/outlook.md` before composing.

```bash
himalaya --account <name> message compose \
  --from sender@example.com \
  --to recipient@example.com \
  --subject "Subject" \
  --body "Body" \
  --send

himalaya --account <name> message reply --mailbox inbox \
  --body "Reply body" --send <message-id>

himalaya --account <name> message forward --mailbox inbox \
  --to recipient@example.com --body "Forward note" --send <message-id>
```

For attachments and raw RFC 5322 messages, read `references/message-composition.md`.

Never retry a send automatically after an ambiguous error. SMTP delivery can succeed before saving a copy to the Sent mailbox fails; verify delivery before any retry.

## Organize mail

```bash
himalaya --account <name> message move --from inbox --to archive <message-id>
himalaya --account <name> message copy --from inbox --to important <message-id>
himalaya --account <name> flag add --mailbox inbox --flag seen <message-id>
himalaya --account <name> flag remove --mailbox inbox --flag seen <message-id>
himalaya --account <name> message delete --mailbox inbox <message-id>
```

`message delete` is trash-first, but permanently removes messages already in trash. State this consequence and get explicit confirmation.

## Network and troubleshooting

Himalaya 2 supports SOCKS5 and HTTP CONNECT, and takes its route **only** from the environment of each invocation. Operating-system proxy settings are a discovery source, not a route: a proxy configured in macOS or Windows settings but absent from the process environment is not used, so reading it and then running the command unchanged tests the direct route while appearing to test the proxy. To exercise a discovered setting, pass it explicitly in that invocation's environment, and preserve the protocol exactly as reported — never infer one from a port number.

Himalaya has no proxy configuration field or CLI flag: the route comes only from the environment of each invocation, and this build reads exactly two variables — `all_proxy` first, then `https_proxy`. **`http_proxy` is not consulted at all**, so a proxy supplied only through it is silently ignored and the command runs direct; carry such a value over into `https_proxy` for the invocation. This environment is the one lever for per-command route isolation. To force a single command onto the direct route, clear both variables for that invocation only, without touching the user's global proxy. On macOS use `env -u all_proxy -u https_proxy <himalaya> --account <name> ...`; in PowerShell, `env` does not exist, so scope the change to the process instead:

```powershell
# A child process, so the user's proxy stays intact in this session.
powershell -NoProfile -Command @'
Remove-Item Env:all_proxy -ErrorAction SilentlyContinue
Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
& '<himalaya>' --account <name> ...
'@
```

Never assign `$env:` values directly in the working session: they persist, and every later command would silently run without the user's proxy. Confirm the route actually used from Himalaya's own `dial <host>:<port> ... (source: direct|all_proxy|https_proxy)` debug line rather than assuming it.

Outlook Graph setup (`cola-outlook-mail-auth connect` / `doctor` / `token`) is HTTPS to Microsoft, not IMAP/SMTP. Wrap those helper invocations the same way when a proxy is required; leave `status` and `configure` unwrapped; keep loopback off the proxy so the OAuth callback can return. See `references/outlook.md` (Network). If the Microsoft page says the account does not support this setup, that is almost always missing two-step verification on a personal Microsoft account — follow `references/outlook.md`, do not treat it as a Cola failure.

Read `references/proxy.md` before connecting or diagnosing when any of these conditions applies:

- the provider may require a proxy on the user's current network;
- proxy variables or an operating-system proxy are present;
- the failure mentions proxy, timeout, DNS/connect, TLS, unreachable service, or an incomplete SOCKS handshake;
- IMAP works but SMTP fails, or the reverse;
- changing between direct and proxied routing changes the result.

That guide defines the routing defaults for Gmail, QQ Mail, iCloud Mail, Outlook, and custom IMAP/SMTP; macOS and Windows proxy discovery; per-command route isolation; and error-specific recovery. Do not ask the user to edit global proxy settings.

Use its error mapping as recovery guidance. When an observed error matches a known case, move the diagnosis in the stated direction using the current device's available controls. Do not merely restate the protocol, port, or timeout to the user and stop, and do not assume that every device exposes proxy controls in the same way.

Use the actual CLI path:

```bash
himalaya --account <name> --log-level debug account check
```

Verify the selected route from Himalaya's own debug line before interpreting the result. Do not use `nc`, `telnet`, or a direct socket probe as proof of Himalaya connectivity because those checks bypass its proxy selection. Read `references/troubleshooting.md` for non-network failures and the staged diagnostic flow.

Do not discard the diagnostic stages before interpreting a timeout. Inspect the bounded command output first, then retain and report only safe route and stage information.
