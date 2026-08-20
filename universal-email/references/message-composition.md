# Compose messages with Himalaya 2

Use Himalaya 2's built-in composer for ordinary text mail.

The commands below route through SMTP or JMAP. An account on the Microsoft Graph backend cannot send with them — check the backend in `account list` first and see `references/outlook.md`, which sends raw MIME through `msgraph message send` instead.

## New message

```bash
himalaya --account <name> message compose \
  --from sender@example.com \
  --to recipient@example.com \
  --cc copy@example.com \
  --subject "Subject" \
  --body "Body" \
  --attach /absolute/path/report.pdf \
  --send
```

Repeat `--to`, `--cc`, `--bcc`, or `--attach` for multiple values. Use `--body-file <path>` for a multiline body.

## Reply and forward

```bash
himalaya --account <name> message reply --mailbox inbox \
  --body-file /absolute/path/reply.txt --send <message-id>

himalaya --account <name> message forward --mailbox inbox \
  --to recipient@example.com --body "Forward note" --send <message-id>
```

Use `--posting-style top` or `--posting-style bottom` when the user has a preference.

## Raw RFC 5322 message

For a prebuilt MIME message, pipe it to `message send`:

```bash
himalaya --account <name> message send <<'EOF'
From: sender@example.com
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
