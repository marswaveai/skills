# Compose messages with Himalaya 2

Use Himalaya 2's built-in composer for ordinary text mail.

The commands below route through SMTP or JMAP. An account on the Microsoft Graph backend cannot send with them — check the backend in `account list` first and see `references/outlook.md`, which sends raw MIME through `msgraph message send` instead.

## New message

`--from` is required. Use the connected mailbox address from this conversation. Himalaya 2 does not fill `From:` from the account `email` field; omitting the flag still connects, then fails with `No From: header` (often looking like a send timeout). Do not omit it. This is the sender address, not `message move --from` (a mailbox name).

```bash
himalaya --account <name> message compose \
  --from <connected-mailbox-address> \
  --to recipient@example.com \
  --cc copy@example.com \
  --subject "Subject" \
  --body "Body" \
  --attach /absolute/path/report.pdf \
  --send
```

Repeat `--to`, `--cc`, `--bcc`, or `--attach` for multiple values. Use `--body-file <path>` for a multiline body.

## Reply and forward

Same `--from` rule: required, connected mailbox address, do not omit.

```bash
himalaya --account <name> message reply --mailbox inbox \
  --from <connected-mailbox-address> \
  --body-file /absolute/path/reply.txt --send <message-id>

himalaya --account <name> message forward --mailbox inbox \
  --from <connected-mailbox-address> \
  --to recipient@example.com --body "Forward note" --send <message-id>
```

Use `--posting-style top` or `--posting-style bottom` when the user has a preference.

## Raw RFC 5322 message

For a prebuilt MIME message, pipe it to `message send`:

```bash
himalaya --account <name> message send <<'EOF'
From: <connected-mailbox-address>
To: recipient@example.com
Subject: Subject

Body
EOF
```

To keep a copy in the Sent mailbox, resolve the name first: `--save <mailbox>` is looked up in the account's `[mailbox.alias]` map and otherwise used verbatim, so a literal `sent` silently misses providers whose real mailbox is `Sent Messages` or a localized name. Use `--save sent` only when the account's configuration defines that alias (see `references/configuration.md`); otherwise run `mailbox list` and pass the exact mailbox name. A send can succeed before saving the sender copy fails; never retry automatically after that ambiguous result.

## Safety

- Show recipients, subject, body summary, and attachment names before sending.
- Obtain explicit confirmation immediately before every send, reply, or forward.
- Do not expose Bcc recipients in the visible body.
- Do not retry an ambiguous send without first verifying delivery.
