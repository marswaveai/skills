---
name: universal-email
description: Use the bundled Himalaya 2 CLI to connect IMAP/SMTP or Microsoft Graph mailboxes and list, search, read, compose, reply, forward, move, delete, flag, and download email. Use when the user asks to connect or operate Gmail, QQ Mail, iCloud Mail, Outlook, or another standard mailbox.
---

# Himalaya 2 email

Use the bundled `himalaya` executable. This Skill targets exactly Himalaya `2.0.0` at revision `923414155f4281d681f4ea8631954f406acf51ee`; do not use Himalaya 1.x configuration fields or command examples.

Always invoke `himalaya` from `PATH`. Treat that command's active configuration as the source of truth: do not bypass it with the packaged binary's absolute path, inspect candidate config files to choose one, or add `--config` merely because a file exists. Use `--config` only when the user explicitly requests a separate profile.

## Choose the account

1. Run `himalaya --version` and require `himalaya v2.0.0`.
2. Run `himalaya --json account list`.
3. If the intended account exists, select it with the global `--account <name>` option.
4. If it does not exist, read the matching provider guide before asking the user for anything:
   - Gmail: `references/gmail.md`
   - QQ Mail: `references/qq.md`
   - iCloud Mail: `references/icloud.md`
   - Outlook/Microsoft 365: `references/outlook.md`
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

Himalaya 2 can inherit proxy routing from the current process or operating system and supports SOCKS5 and HTTP CONNECT. Discover the device's actual settings and preserve the reported protocol. Never infer a proxy protocol from a port number.

Himalaya has no proxy configuration field or CLI flag: the route comes only from the environment of each invocation (`all_proxy` takes precedence over `http_proxy`/`https_proxy`). This is the one lever for per-command route isolation. To force a single command onto the direct route, clear those variables for that invocation only, for example `env -u all_proxy -u http_proxy -u https_proxy himalaya --account <name> ...`, without touching the user's global proxy. Confirm the route actually used from Himalaya's own `dial <host>:<port> ... (source: direct|all_proxy|http_proxy)` debug line rather than assuming it.

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
