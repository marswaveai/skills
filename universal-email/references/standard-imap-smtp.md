# Standard IMAP/SMTP

Use this path when no provider-specific guide matches.

## What the user needs

Ask the user for the non-secret settings supplied by the mailbox provider or organization administrator:

- full email address;
- IMAP username, host, port, and TLS or STARTTLS mode;
- SMTP username, host, port, and TLS or STARTTLS mode.

The provider also requires a password, app password, or authorization code. Tell them which kind and where to generate it. Never ask them to send it in chat.

对用户说：「把邮箱地址发我。密码或授权码不要发到聊天里。我先按官方说明记下服务器设置；生成好之后跟我说一声，屏幕上会弹出窗口，在那里填并点保存。」

Do not guess endpoints from the email domain. Do not assume the normal webmail password is accepted. Prefer the provider's official setup documentation and use its credential terminology verbatim.

## How to connect

1. Ask the user for the mailbox provider or organization name.
2. Open that provider's official mail-client setup documentation.
3. Collect the IMAP and SMTP settings exactly as documented.
4. Determine whether the provider requires the normal password, an app password, or an authorization code.
5. Choose a Himalaya account `<name>` that contains only ASCII letters, digits, `-`, and `_`.
6. Say the system window is about to appear, then immediately store the secret with the bundled helper as described in `configuration.md`. Use `--account universal-email/<name>` and secret labels that match the provider's term. They type it in that window and click 保存. Never run the Himalaya wizard. Never open a terminal for the user.
7. Write the IMAP/SMTP account from `configuration.md`. Then run `himalaya --account <name> --json account check`.

## Validate and troubleshoot

Validate IMAP and SMTP as separate stages. A successful inbox read does not prove sending works, and an SMTP success does not prove mailbox access works.

Discover the provider's real Sent mailbox before using `--save`. Do not infer its name from locale or provider. If none is exposed, send without `--save` and treat delivery separately from sender-side archiving.
