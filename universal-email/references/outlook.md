# Outlook through Microsoft Graph

Outlook uses Microsoft OAuth and the Microsoft Graph backend. The user signs in on Microsoft's page and approves the requested mail permissions. Do not request the Microsoft password, an app password, a client ID, a client secret, or a token in chat.

## What the user needs

- the Microsoft account that owns the Outlook or Microsoft 365 mailbox;
- permission to approve the requested mail access for that account.

Do not copy a password, app password, client ID, client secret, or token into chat.

## How to connect

1. Run the bare `himalaya` setup wizard in a PTY and select the Microsoft Graph backend.
2. Sign in to the intended mailbox account when the browser opens.
3. Review and approve the requested mail permissions.
4. Run `himalaya --account <account-name> account check` after authorization.
5. If Microsoft requires administrator approval, stop and explain that the organization's consent policy blocks personal approval.

## Validate and troubleshoot

After the account is available, validate it with:

```bash
himalaya --account <account-name> --json msgraph profile get
```

List and read messages with the explicit Graph surface:

```bash
himalaya --account <account-name> --json msgraph message list \
  --folder inbox --top 20 --select id,subject,from,receivedDateTime,isRead
himalaya --account <account-name> --json msgraph message get <MESSAGE_ID>
```

Send raw RFC 5322 MIME with `msgraph message send`. Graph saves the message in Sent Items; do not append a second copy.

Himalaya v2.0.0 does not expose Graph-specific reply or forward commands. Read the source message, construct the intended RFC 5322 message with correct recipients and thread headers, show it for confirmation, then send once. Do not claim native Graph reply or forward semantics.

If Microsoft says administrator approval is required, do not tell the user to create a personal Microsoft application or provide a secret.
