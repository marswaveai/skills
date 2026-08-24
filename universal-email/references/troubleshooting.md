# Troubleshooting Himalaya 2

Diagnose in this order:

1. Run `himalaya --version`; require v2.0.0 for this Skill.
2. Run `himalaya --json account list` to catch TOML/schema errors in the active configuration without contacting the provider.
3. Run the split probes in `proxy.md` (`--backend imap` and `--backend smtp`, proxy then direct, 25s each). Do not use a combined `account check` as the only sample when it timed out or a proxy is present.
4. Identify the failing backend and stage: proxy, DNS/connect, TLS, authentication, IMAP, SMTP, or Microsoft Graph. A wrapper timeout with empty output does not identify the backend.
5. Confirm the provider-specific credential type. Never substitute a normal account password for an app password or authorization code.
6. Retry one read-only check after correcting the cause. Do not send a test email unless the user explicitly approves it.

For proxy selection, provider routing, macOS/Windows discovery, and network-error mapping, read `proxy.md`. Do not improvise another proxy flow here.

If reading works but sending fails, preserve the IMAP configuration and diagnose SMTP separately. Report only the stage and safe error category; never expose secrets, credential-helper output, private configuration contents, or full debug logs.
