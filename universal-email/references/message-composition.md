# Compose messages with Himalaya 2

Use Himalaya 2's built-in composer for ordinary text mail.

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

Add `--save sent` only after `mailbox list` proves the Sent alias resolves. A send can succeed before saving the sender copy fails; never retry automatically after that ambiguous result.

## Safety

- Show recipients, subject, body summary, and attachment names before sending.
- Obtain explicit confirmation immediately before every send, reply, or forward.
- Do not expose Bcc recipients in the visible body.
- Do not retry an ambiguous send without first verifying delivery.
