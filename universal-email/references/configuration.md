# Himalaya 2 configuration

This package targets Himalaya `2.0.0` at revision `923414155f4281d681f4ea8631954f406acf51ee`.

## Active configuration

For normal operations, run the bundled executable resolved in `SKILL.md` — never a `himalaya` from `PATH` — and pass no `--config`. It may already have an active configuration selected; confirm what it sees with:

```bash
himalaya --json account list
```

Do not choose a configuration by scanning files, and do not replace the active configuration just because another TOML file exists.

When the native executable has not been given an active configuration, Himalaya searches:

1. `$XDG_CONFIG_HOME/himalaya/config.toml`
2. `$HOME/.config/himalaya/config.toml`

On Windows the equivalent location is `%APPDATA%\himalaya\config.toml`. The v1-era `~/.himalayarc` is not read by this build — a configuration written there looks saved while `account list` keeps reporting no account.

The global `--config <path>` option explicitly selects another profile. Use it only when the user requests a separate profile; do not use it for ordinary account discovery, validation, or mailbox operations.

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
imap.sasl.plain.password.command = ["credential-helper", "get", "personal"]

smtp.server = "smtps://smtp.example.com:465"
smtp.sasl.plain.username = "user@example.com"
smtp.sasl.plain.password.command = ["credential-helper", "get", "personal"]
```

For STARTTLS, use the cleartext scheme and opt in explicitly:

```toml
smtp.server = "smtp://smtp.example.com:587"
smtp.starttls = true
```

Use `imap://...` plus `imap.starttls = true` for IMAP STARTTLS. Do not combine an implicit-TLS scheme such as `imaps://` or `smtps://` with `starttls = true`.

`credential-helper` is a placeholder for a secure command that prints the secret to stdout. Store secrets in the operating-system credential store. Do not use `password.raw` in production and do not put the secret directly in command-line arguments.

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
imap.sasl.plain.password.command = ["credential-helper", "get", "gmail"]

smtp.server = "smtps://smtp.gmail.com:465"
smtp.sasl.plain.username = "you@gmail.com"
smtp.sasl.plain.password.command = ["credential-helper", "get", "gmail"]
```

Use a Google app password, not the normal account password. Remove visual whitespace from the 16-character app password before secure storage.

## iCloud IMAP/SMTP

```toml
[accounts.icloud]
email = "you@icloud.com"
display-name = "Your Name"

mailbox.alias.inbox = "INBOX"

imap.server = "imaps://imap.mail.me.com:993"
imap.sasl.plain.username = "you@icloud.com"
imap.sasl.plain.password.command = ["credential-helper", "get", "icloud"]

smtp.server = "smtp://smtp.mail.me.com:587"
smtp.starttls = true
smtp.sasl.plain.username = "you@icloud.com"
smtp.sasl.plain.password.command = ["credential-helper", "get", "icloud"]
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
