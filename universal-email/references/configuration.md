# Himalaya 2 configuration

This package targets Himalaya `2.0.0` at revision `923414155f4281d681f4ea8631954f406acf51ee`.

## Active configuration

For normal operations, run the executable resolved in `SKILL.md` and pass no `--config`. On macOS and Windows that is always the bundled copy, never a `himalaya` from `PATH`; on platforms this package does not ship a build for, it is the validated `v2.0.0` from `PATH` that `SKILL.md` permits. It may already have an active configuration selected; confirm what it sees with:

```bash
himalaya --json account list
```

Do not choose a configuration by scanning files, and do not replace the active configuration just because another TOML file exists.

When the native executable has not been given an active configuration, Himalaya searches:

1. `$XDG_CONFIG_HOME/himalaya/config.toml`
2. `$HOME/.config/himalaya/config.toml`

On Windows the equivalent location is `%APPDATA%\himalaya\config.toml`. Write configuration only to these paths: a file placed anywhere else looks saved while `account list` keeps reporting no account.

The global `--config <path>` option explicitly selects another profile. Use it only when the user requests a separate profile; do not use it for ordinary account discovery, validation, or mailbox operations.

## Store the mailbox secret

IMAP/SMTP secrets (Gmail app password, QQ authorization code, iCloud app-specific password, or another provider secret) are entered through the bundled helper. The user never uses a terminal.

Never run the bare `himalaya` setup wizard. That wizard needs a real terminal this chat does not have and dumps implementation details to the user.

Resolve `scripts/bin/<platform>/cola-credential-helper` the same way as `himalaya` in `SKILL.md` (Windows: `cola-credential-helper.exe`). Use that absolute path. If the file is missing, the mailbox is not ready — do not fall back to a wizard, chat, or `password.raw`.

1. After the user has generated the provider secret, run:

```bash
cola-credential-helper prompt \
  --account universal-email/<key> \
  --title-en "<title>" \
  --title-zh "<title>" \
  --secret-label-en "<label>" \
  --secret-label-zh "<label>"
```

Keep it running until it returns JSON with `ok` true and `stored` true. The helper tries a system password dialog first (macOS `display dialog`; Windows a small password window), brings it to the front, and waits up to 180 seconds. HTML opens only when that dialog cannot be shown (missing host, no UI session, or timeout with no input). User cancel does not fall through to HTML. After a successful write it shows a system “已保存” dialog — not the OAuth “连上了” page. Storage stays the existing Cola keychain contract: service `com.marswave.cola.app-secrets`, account `universal-email/<key>`, read back only by `cola-credential-helper read`.

**What you SAY, in this order.** Chat only ever collects the email address. Do not invent other wording.

1. Asking for the address: 「把要连接的邮箱地址发我。应用专用密码/授权码不要发到聊天里。」
2. Guiding them to generate the secret (provider links as in the provider guide): 「按这个页面生成。生成后跟我说一声，先别把密码发过来。」
3. The moment you run `prompt` — say this, then start the command in the same turn, do not wait for another chat message: 「屏幕上马上会弹出一个系统窗口。把刚生成的应用专用密码（或授权码）填进去，点保存。不要粘贴到聊天里。」
4. After `prompt` returns `ok`: 「已经收下了，我继续连。」
5. If the system window does not appear and HTML opens: 「窗口没弹出来的话，浏览器会打开一个本机页面，在那里填并点保存。」

Never say only “我会在本机安全输入框中接收它”. Always pair “不要发到聊天” with when the window appears and what they click.

2. Write the Himalaya 2 account into the active configuration using the templates below. Point both IMAP and SMTP `password.command` at the helper `read` and the same `--account`. Use a TOML literal string for a Windows path so `\Users` is not parsed as an escape (`\U`). Forward slashes also work on Windows. Never `password.raw`. Never put the secret in a command argument or in the TOML file.

| Provider | `--account` | Himalaya account name |
| --- | --- | --- |
| Gmail (personal or Workspace) | `universal-email/gmail` | `gmail` |
| QQ Mail | `universal-email/qq` | `qq` |
| iCloud Mail | `universal-email/icloud` | `icloud` |
| Other IMAP/SMTP | `universal-email/<name>` | `<name>` — `name` may contain only ASCII letters, digits, `-`, and `_` |

Provider guides supply the title and secret-label values. Do not show `--account`, the helper path, or keychain names to the user.

If `prompt` does not return `ok`, do not write TOML. Tell the user the input did not finish and that they can try again. If they paste a secret in chat anyway, do not store it: tell them to revoke it, generate a new one, and enter the new one in the dialog.

## Minimal IMAP and SMTP account

```toml
[accounts.personal]
email = "user@example.com"
display-name = "User"
default = true

mailbox.alias.inbox = "INBOX"
mailbox.alias.sent = "Sent"
mailbox.alias.drafts = "Drafts"
mailbox.alias.trash = "Trash"

imap.server = "imaps://imap.example.com:993"
imap.sasl.plain.username = "user@example.com"
imap.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/personal']

smtp.server = "smtps://smtp.example.com:465"
smtp.sasl.plain.username = "user@example.com"
smtp.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/personal']
```

For STARTTLS, use the cleartext scheme and opt in explicitly:

```toml
smtp.server = "smtp://smtp.example.com:587"
smtp.starttls = true
```

Use `imap://...` plus `imap.starttls = true` for IMAP STARTTLS. Do not combine an implicit-TLS scheme such as `imaps://` or `smtps://` with `starttls = true`.

`password.command` must be the bundled helper `read`. Himalaya prints that command's stdout as the secret; `read` writes only the secret.

## Gmail IMAP/SMTP

```toml
[accounts.gmail]
email = "you@gmail.com"
display-name = "Your Name"
default = true

mailbox.alias.inbox = "INBOX"
mailbox.alias.sent = "[Gmail]/Sent Mail"
mailbox.alias.drafts = "[Gmail]/Drafts"
mailbox.alias.trash = "[Gmail]/Trash"
mailbox.alias.archive = "[Gmail]/All Mail"

imap.server = "imaps://imap.googlemail.com:993"
imap.sasl.plain.username = "you@gmail.com"
imap.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/gmail']

smtp.server = "smtps://smtp.gmail.com:465"
smtp.sasl.plain.username = "you@gmail.com"
smtp.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/gmail']
```

Use a Google app password, not the normal account password. The helper strips display spaces from the 16-character app password.

## QQ Mail IMAP/SMTP

```toml
[accounts.qq]
email = "you@qq.com"
display-name = "Your Name"
default = true

mailbox.alias.inbox = "INBOX"

imap.server = "imaps://imap.qq.com:993"
imap.sasl.plain.username = "you@qq.com"
imap.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/qq']
imap.id.auto = true

smtp.server = "smtps://smtp.qq.com:465"
smtp.sasl.plain.username = "you@qq.com"
smtp.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/qq']
```

QQ requires `imap.id.auto = true`. Use the client authorization code, not the QQ login password.

## iCloud IMAP/SMTP

```toml
[accounts.icloud]
email = "you@icloud.com"
display-name = "Your Name"

mailbox.alias.inbox = "INBOX"

imap.server = "imaps://imap.mail.me.com:993"
imap.sasl.plain.username = "you@icloud.com"
imap.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/icloud']

smtp.server = "smtp://smtp.mail.me.com:587"
smtp.starttls = true
smtp.sasl.plain.username = "you@icloud.com"
smtp.sasl.plain.password.command = ['<absolute-path-to-cola-credential-helper>', 'read', '--account', 'universal-email/icloud']
```

Discover the actual mailbox names with `mailbox list` before adding Sent, Drafts, or Trash aliases.

## Provider compatibility options

Some providers require extra IMAP behavior:

```toml
# Coremail providers that reject SASL initial response
imap.sasl-ir = false

# Providers that require an RFC 2971 ID exchange
imap.id.auto = true
```

Only enable these when the provider guide requires them.

## Validate

Configuration-only parse check using the active configuration:

```bash
himalaya --json account list
```

Connection and authentication check:

```bash
himalaya --account <name> --json account check
```

The first command proves only that the TOML matches Himalaya 2. The second exercises configured backends and can contact external services.
