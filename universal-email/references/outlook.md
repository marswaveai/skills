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

## 对用户说（照念）

1. 「接下来浏览器会打开微软登录页。在那个页面登录并同意邮件权限。微软密码不要发到聊天里。登录完成后回到这里就行。」
2. After connect succeeds: 「Outlook 已经连好了。以后直接说『看看今天的邮件』就行。」
3. If the organization requires admin consent: 「这个公司账号需要管理员同意，你这边点不了。让管理员允许这个应用之后再跟我说。」
4. If Outlook mail is not ready in this Cola build: 「这台 Cola 还不能连 Outlook 邮箱，不是你的账号问题。」

## How to connect

You run every step. Use the lines above. Do not ask them to run a command.

1. Run `cola-outlook-mail-auth status`.
2. If it is not configured, read the Microsoft public client ID (never show it to the user):
   - `MICROSOFT_GRAPH_CLIENT_ID` if set;
   - otherwise `$COLA_INTEGRATIONS_DIR/credentials/microsoft-graph-oauth.json` field `clientId`.
   Then run `cola-outlook-mail-auth configure --client-id <id>`.
   If neither source exists, say Outlook mail is not ready in this Cola build and stop. Do not ask the user for a client ID.
3. Run `cola-outlook-mail-auth connect`. It opens the Microsoft sign-in page. Keep that command running until it returns JSON. The only user action is to finish login and consent in the browser. If Microsoft Graph is only reachable through a device proxy, wrap **this** invocation (and `doctor` / later `token` refreshes) as in [Network](#network); do not wrap `status` or `configure`. Keep loopback (`localhost`, `127.0.0.1`) off the proxy so the helper can receive the OAuth callback.
4. After connect succeeds, run `cola-outlook-mail-auth doctor` and read `accountLabel`. Apply the same per-invocation proxy wrap as `connect` when a proxy is required.
5. Write the Himalaya 2 account into the active configuration (create the file if needed). Use the helper's absolute path in `token.command`. Do not use `token.raw`. Example:

```toml
[accounts.outlook]
email = "user@outlook.com"
display-name = "Outlook"
default = true
# Use a TOML literal string so Windows backslashes are not parsed as escapes
# (`\Users` in a basic string is `\U`). Forward slashes also work on Windows.
msgraph.auth.token.command = ['<absolute-path-to-cola-outlook-mail-auth>', 'token']
```

Replace the email with `accountLabel` from doctor. Then run `himalaya --account outlook --json account check` and `himalaya --account outlook --json msgraph profile get`.

6. If Microsoft requires administrator approval, stop and explain that the organization's consent policy blocks personal approval. Do not tell the user to create a personal Microsoft application or provide a secret.

If connect cannot wait in this environment, run `cola-outlook-mail-auth connect --emit-start true --no-open true`, open the returned `authorizationUrl` with the platform URL opener, then poll `status` until `connected` is true. Still never ask the user to run the helper.

## Network

`connect`, `doctor`, and `token` talk to Microsoft over HTTPS (`login.microsoftonline.com`, `graph.microsoft.com`). `status` and `configure` are local. The helper takes its route only from each invocation's environment (`HTTPS_PROXY` / `HTTP_PROXY` / `ALL_PROXY`). Operating-system proxy settings are a discovery source, not a route.

If an HTTP or HTTPS proxy is already on the device, apply it to the **first** `connect` (and to `doctor` / `token`) — do not wait for a timeout. Prefer HTTP CONNECT (`https_proxy=http://HOST:PORT`). Keep `NO_PROXY` / `no_proxy` including `localhost,127.0.0.1,::1` so the loopback OAuth callback is not proxied.

Discovery, wrapping one invocation, and recovery live in `proxy.md` (Outlook through Microsoft Graph is HTTPS, not IMAP/SMTP). Replace `HOST:PORT` with the discovered endpoint; assign it once before expanding:

```bash
proxy='http://HOST:PORT/'
env -u ALL_PROXY -u all_proxy \
  HTTPS_PROXY="$proxy" \
  HTTP_PROXY="$proxy" \
  https_proxy="$proxy" \
  http_proxy="$proxy" \
  NO_PROXY='localhost,127.0.0.1,::1' \
  no_proxy='localhost,127.0.0.1,::1' \
  <cola-outlook-mail-auth> connect
```

Do not change the user's global proxy settings. Do not dump helper output.

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
