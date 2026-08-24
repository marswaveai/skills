# Troubleshooting Himalaya 2

Diagnose in this order:

1. Run `himalaya --version`; require v2.0.0 for this Skill.
2. Run `himalaya --json account list` to catch TOML/schema errors in the active configuration without contacting the provider.
3. Run `himalaya --account <name> --log-level debug --json account check` on the first wrap in `proxy.md`. On timeout, take the next wrap. Do not stop after one attempt.
4. Identify the failing backend and stage: proxy, DNS/connect, TLS, authentication, IMAP, SMTP, or Microsoft Graph. A wrapper timeout with empty output does not identify the backend — continue the chain.
5. Confirm the provider-specific credential type. Never substitute a normal account password for an app password or authorization code.
6. Retry one read-only check after correcting the cause. Do not send a test email unless the user explicitly approves it.

For proxy selection, provider routing, macOS/Windows discovery, and network-error mapping, read `proxy.md`. Do not improvise another proxy flow here.

If reading works but sending fails, preserve the IMAP configuration and diagnose SMTP separately. Before calling it a network or proxy failure, inspect the send command: `message compose|reply|forward` without `--from` still dials IMAP/SMTP, then fails with `No From: header`. A timeout or empty result after that is the missing sender, not a dead route. Add the connected mailbox address and retry that one send.

Report only the stage and safe error category; never expose secrets, credential-helper output, private configuration contents, or full debug logs.
