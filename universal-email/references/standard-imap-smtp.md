# Standard IMAP/SMTP

Use this path when no provider-specific guide matches.

## What the user needs

Ask the user for the non-secret settings supplied by the mailbox provider or organization administrator:

- full email address;
- IMAP username, host, port, and TLS or STARTTLS mode;
- SMTP username, host, port, and TLS or STARTTLS mode.

The provider also requires a password, app password, or authorization code. Tell the user which kind their provider issues and where to generate it, but never ask them to send it in chat: it is entered only in the helper dialog during setup, and never appears in a command argument.

Do not guess endpoints from the email domain. Do not assume the normal webmail password is accepted. Prefer the provider's official setup documentation and use its credential terminology verbatim.

## How to connect

1. Ask the user for the mailbox provider or organization name.
2. Open that provider's official mail-client setup documentation.
3. Collect the IMAP and SMTP settings exactly as documented.
4. Determine whether the provider requires the normal password, an app password, or an authorization code.
5. Choose a Himalaya account `<name>` that contains only ASCII letters, digits, `-`, and `_`.
6. Store the secret with the bundled helper as described in `configuration.md`. Use `--account universal-email/<name>` and secret labels that match the provider's term. Never run the Himalaya wizard. Never open a terminal for the user.
7. Write the IMAP/SMTP account from `configuration.md`. Then run `himalaya --account <name> --json account check`.

## Validate and troubleshoot

Validate IMAP and SMTP as separate stages. A successful inbox read does not prove sending works, and an SMTP success does not prove mailbox access works.

Discover the provider's real Sent mailbox before using `--save`. Do not infer its name from locale or provider. If none is exposed, send without `--save` and treat delivery separately from sender-side archiving.
