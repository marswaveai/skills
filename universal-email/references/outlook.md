# Outlook through Microsoft Graph

Outlook uses Microsoft OAuth and the Microsoft Graph backend. You run the bundled helper, which opens Microsoft's sign-in page. The user only signs in and approves mail permissions in the browser. Do not ask them to run a terminal, a wizard, or any command. Do not request the Microsoft password, an app password, a client ID, a client secret, or a token in chat.

Never run the bare `himalaya` setup wizard for Outlook. That wizard needs a real TTY this chat does not have, and it would dump implementation details to the user.

## What the user needs

- the Microsoft account that owns the Outlook or Microsoft 365 mailbox;
- permission to approve the requested mail access for that account.

Do not copy a password, app password, client ID, client secret, or token into chat.

## Locate the helper

Resolve `scripts/bin/<platform>/cola-outlook-mail-auth` the same way as `himalaya` in `SKILL.md` (Windows: `cola-outlook-mail-auth.exe`). Use that absolute path for every helper command below. If the file is missing, tell the user Outlook mail is not ready yet — never ask them to install or run a client.

The examples write the helper by its bare name; always run the resolved absolute path.

## How to connect

You run every step. Narrate in product words only: “正在连接你的 Outlook 邮箱，浏览器会打开微软登录页”.

1. Run `cola-outlook-mail-auth status`.
2. If it is not configured, read the Microsoft public client ID (never show it to the user):
   - `MICROSOFT_GRAPH_CLIENT_ID` if set;
   - otherwise `$COLA_INTEGRATIONS_DIR/credentials/microsoft-graph-oauth.json` field `clientId`.
   Then run `cola-outlook-mail-auth configure --client-id <id>`.
   If neither source exists, say Outlook mail is not ready in this Cola build and stop. Do not ask the user for a client ID.
3. Run `cola-outlook-mail-auth connect`. It opens the Microsoft sign-in page. Keep that command running until it returns JSON. The only user action is to finish login and consent in the browser.
4. After connect succeeds, run `cola-outlook-mail-auth doctor` and read `accountLabel`.
5. Write the Himalaya 2 account into the active configuration (create the file if needed). Use the helper's absolute path in `token.command`. Do not use `token.raw`. Example:

```toml
[accounts.outlook]
email = "user@outlook.com"
display-name = "Outlook"
default = true
msgraph.auth.token.command = ["<absolute-path-to-cola-outlook-mail-auth>", "token"]
```

Replace the email with `accountLabel` from doctor. Then run `himalaya --account outlook --json account check` and `himalaya --account outlook --json msgraph profile get`.

6. If Microsoft requires administrator approval, stop and explain that the organization's consent policy blocks personal approval. Do not tell the user to create a personal Microsoft application or provide a secret.

If connect cannot wait in this environment, run `cola-outlook-mail-auth connect --emit-start true --no-open true`, open the returned `authorizationUrl` with the platform URL opener, then poll `status` until `connected` is true. Still never ask the user to run the helper.

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
