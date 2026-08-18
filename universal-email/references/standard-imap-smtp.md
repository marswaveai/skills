# Standard IMAP/SMTP

Use this path when no provider-specific guide matches.

## What the user needs

Ask for the values supplied by the mailbox provider or organization administrator:

- full email address;
- IMAP username, host, port, and TLS or STARTTLS mode;
- SMTP username, host, port, and TLS or STARTTLS mode;
- password, app password, or authorization code required by that provider.

Do not guess endpoints from the email domain. Do not assume the normal webmail password is accepted. Prefer the provider's official setup documentation and use its credential terminology verbatim.

## How to obtain it

1. Ask the user for the mailbox provider or organization name.
2. Open that provider's official mail-client setup documentation.
3. Collect the IMAP and SMTP settings exactly as documented.
4. Determine whether the provider requires the normal password, an app password, or an authorization code.
5. Run the bare `himalaya` setup wizard in a PTY, or configure the account as described in `configuration.md`. Supply credentials through the chosen secure credential mechanism.

## Validate and troubleshoot

Validate IMAP and SMTP as separate stages. A successful inbox read does not prove sending works, and an SMTP success does not prove mailbox access works.

Discover the provider's real Sent mailbox before using `--save`. Do not infer its name from locale or provider. If none is exposed, send without `--save` and treat delivery separately from sender-side archiving.
