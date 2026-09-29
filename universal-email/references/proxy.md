# Proxy routing and diagnosis

Use this guide for connection routing and network failures. Keep credentials, account configuration, and mailbox operations in their provider guides.

## Contents

- [Principles](#principles)
- [Provider guidance](#provider-guidance)
- [Route fallback](#route-fallback)
- [Discover and verify](#discover-and-verify)
- [Error-to-recovery guidance](#error-to-recovery-guidance)
- [User-facing response](#user-facing-response)

## Principles

1. Discover the proxy protocol from the current process, operating system, or proxy application. Never infer SOCKS5 or HTTP CONNECT from a port number.
2. Adapt the diagnosis to the current device. Do not assume that macOS, Windows, shell sessions, and packaged Cola expose proxy settings in the same place.
3. Keep diagnostic changes local to the Himalaya operation. Do not alter the user's global proxy settings.
4. Confirm the route and the last completed network stage from Himalaya's own diagnostics. A generic timeout alone does not identify the failed protocol or backend.
5. When an error matches a known case below, follow its recovery direction before replying. The goal is to help the Agent continue solving the task, not to repeat technical errors to the user.
6. Do not revoke or regenerate an app password because of a timeout, proxy handshake, DNS, connection, or TLS failure.

## Provider guidance

| Provider | First wrap | Then |
| --- | --- | --- |
| Gmail IMAP/SMTP | If the process already has a proxy (Cola injects `ALL_PROXY` / `HTTPS_PROXY` when its proxy is on), start with the [preferred proxy](#which-wrap-to-try-first). If none, start direct. | Follow [Route fallback](#route-fallback). Direct is a first-class next step: a web proxy may connect and then fail to relay raw mail. |
| QQ Mail | Direct (clear proxy variables for that invocation). | If direct fails and a proxy is declared, try the preferred proxy. Do not change QQ credentials. |
| iCloud Mail | Direct. | Same as QQ Mail. |
| Outlook through Microsoft Graph | HTTP CONNECT if declared (same idea as Calendar). | Do not reuse IMAP/SMTP conclusions. |
| Other IMAP/SMTP | The device's normal route (process env as Cola launched it). | Introduce or clear a proxy only when that attempt fails. |

These are directions, not fixed results. Confirm the route actually selected on the current device from Himalaya's `dial` line.

## Route fallback

This is a **chain**, not a matrix. One Himalaya command at a time. Stop at the first wrap that completes the current command. Reuse that wrap for the rest of the session. Do not re-probe on every later mail operation. Do not ask the user to toggle Cola's proxy.

Default validation is still:

```bash
himalaya --account <name> --log-level debug --json account check
```

on the **first wrap**. Tool timeout 25s. If it succeeds, done.

Do not stop after one timeout. Do not repeat the same wrap unchanged. Do not start by splitting IMAP and SMTP.

### Which wrap to try first

Read the current process: `all_proxy`, `ALL_PROXY`, `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY`. Preserve each value's protocol. Himalaya reads `all_proxy` first (either letter case), then `https_proxy`. It does **not** read `http_proxy`; copy an HTTP-only value onto `https_proxy` for that invocation.

**Preferred proxy** when both HTTP CONNECT and SOCKS are present: HTTP CONNECT (`https_proxy=http://HOST:PORT`), and clear `all_proxy` / `ALL_PROXY` so SOCKS does not win. Mixed SOCKS + HTTP often fails the handshake (`failed to fill whole buffer` when SOCKS is aimed at an HTTP port).

Order after the provider's first wrap:

1. Preferred proxy (HTTP CONNECT if available, else SOCKS).
2. The other already-declared protocol (SOCKS ↔ HTTP). Do not invent a host or port.
3. Direct — unset **both** letter cases. Cola writes `ALL_PROXY` / `HTTPS_PROXY`; unsetting only `all_proxy` is not a direct test:

```bash
env -u all_proxy -u ALL_PROXY -u https_proxy -u HTTPS_PROXY -u http_proxy -u HTTP_PROXY \
  himalaya --account <name> --log-level debug --json account check
```

HTTP CONNECT wrap when SOCKS must be cleared (replace the URL with the discovered `http://HOST:PORT`):

```bash
env -u all_proxy -u ALL_PROXY \
  https_proxy='http://HOST:PORT' HTTPS_PROXY='http://HOST:PORT' \
  himalaya --account <name> --log-level debug --json account check
```

PowerShell: each wrap in a child `powershell -NoProfile -Command` so `$env:` does not leak. Direct wrap: `Remove-Item` `all_proxy`, `ALL_PROXY`, `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY`.

### If that attempt fails

Keep `--log-level debug`. Read the last `dial … (source: …)` line and the last completed stage.

| What debug shows | Next wrap |
| --- | --- |
| SOCKS handshake `failed to fill whole buffer` | HTTP CONNECT, if an HTTP URL is already on the device |
| HTTP CONNECT rejected or refused | SOCKS if already declared; else direct |
| Tunnel + TLS, then hang (IMAP greeting / SMTP banner) | Next wrap in the chain (other protocol, then direct) |
| Direct times out before TLS | Declared proxy, if not already tried |
| Combined `account check` empty timeout | Next wrap, still combined, still debug, 25s. If the log shows IMAP finished and SMTP did not (or the reverse), retry **only the failing backend** with `--backend imap` or `--backend smtp` on the next wrap. That is the only time to split. |
| Server rejected the secret after responding | Stop routing. Follow the provider credential guide. |

Never treat an empty wrapper timeout as “both sides failed” or as a wrong password.

### After a wrap succeeds

Prefix every later Himalaya command in this session with that same env. If a later **send** fails while reads still work, retry **that send only** on the next wrap (usually direct). Do not re-run the whole chain, and do not report the mailbox as disconnected.

## Discover and verify

Discover active routing from the environment in which Cola launches Himalaya. If it is incomplete, inspect the current operating system or proxy application's settings with appropriate platform tools. Preserve every endpoint's reported protocol; do not guess or scan common ports.

If several proxy sources exist, determine which one Himalaya actually selected. A higher-priority or stale setting can mask another valid route. Resolve that conflict only for the current Himalaya operation.

Use debug `account check` on the current wrap to establish:

- whether the selected route is direct, SOCKS5, or HTTP CONNECT;
- whether the proxy handshake completed;
- whether TLS completed;
- whether IMAP and SMTP each responded.

Do not discard diagnostic output before interpreting a timeout. Do not use a direct socket probe as proof of Himalaya connectivity because it may bypass the route used by the CLI. Do not expose proxy credentials, mail credentials, configuration contents, or complete debug logs.

## Error-to-recovery guidance

| Observed error or stage | Meaning | Recovery direction |
| --- | --- | --- |
| SOCKS5 handshake ends with `failed to fill whole buffer` | The endpoint did not complete a SOCKS5 handshake. It may actually be an HTTP proxy, or the SOCKS listener may be invalid. | Re-discover the endpoint's declared protocol. If it is HTTP, use it as HTTP CONNECT and clear SOCKS; if it is SOCKS5, check whether that listener is still valid. Do not classify the endpoint from its port. |
| The proxy connection is refused | The local proxy is stopped or the configured endpoint is stale. | Re-read the device's current proxy settings. Do not guess another port or change mail credentials. |
| HTTP CONNECT is rejected | The proxy rejected authentication, the destination, or the mail port. | Try the other already-declared protocol, then direct. Do not treat this as an email-password failure. |
| Gmail completes TLS and `CAPABILITY`, then IMAP authentication stalls | The selected Gmail edge route is not completing IMAP authentication; this can happen with either direct DNS or a proxy route. | Keep the account and password unchanged. Retry with the Gmail preset's `imap.googlemail.com` compatibility endpoint, then the next wrap only if that endpoint also stalls. Do not misreport this as a missing password. |
| Gmail completes the proxy handshake and TLS, but never reaches `CAPABILITY` | The proxy is reachable but is not relaying the mail protocol correctly. | Next wrap in the chain. Do not repeat the same unchanged route. |
| QQ Mail or iCloud Mail becomes unreachable only when proxied | A global proxy is interfering with a provider that normally uses the local route. | Direct wrap for that invocation. Do not disable the user's global proxy or change credentials. |
| IMAP succeeds but SMTP times out or disconnects | Receiving works; the sending route or SMTP mode is failing. | Keep the IMAP wrap. Retry SMTP only (`--backend smtp`) on the next wrap, usually direct. Do not report the whole account as disconnected. Do not regenerate the app password. |
| Combined `account check` times out with empty output | IMAP and SMTP were tested together; the wrapper killed the process before either result printed. This is not evidence that both failed, and not a password error. | Next wrap in the chain, with debug. Split backends only if the log shows they failed at different stages. Do not repeat the same combined check with a longer timeout. |
| SMTP send stalls through a proxy: the SOCKS or HTTP CONNECT tunnel completes but `smtp.<provider>:465`/`:587` never returns a banner or completes TLS | The proxy node accepts the tunnel but does not relay outbound SMTP ports (a common anti-spam egress block). It is not a Gmail, credential, or Himalaya fault, and IMAP over the same proxy can still work. | Retry that one send on the direct wrap; on many networks the SMTP host is reachable directly. If direct also cannot reach the SMTP host, guide the user to a proxy node that permits SMTP ports. Switching SOCKS ↔ HTTP CONNECT does not help when both point at the same node. |
| SMTP succeeds but saving to Sent fails | Delivery and saving a sender-side copy are separate stages. | Do not resend automatically. Check delivery first, then discover the provider's Sent mailbox behavior. |
| Direct connection times out before TLS | The current network cannot reach the target directly, or the host is wrong. | Confirm the provider host. For a provider commonly blocked on the current network, try the declared proxy; otherwise continue local network diagnosis. |
| TLS certificate validation fails | The route may be intercepting TLS, the system clock may be wrong, or the trust store may be invalid. | Use a trusted route and validate the device environment. Never disable certificate verification. |
| Authentication fails after the server responds | The network route worked; the credential or provider authorization is wrong. | Follow the provider credential guide. Do not continue changing proxies unless the error also shows a network-stage failure. |
| Only a generic `service unreachable` is returned | The summary hid the failing backend and stage. | Obtain stage-level diagnostics, distinguish IMAP from SMTP, then follow the matching direction in this table. |
| Only a wrapper timeout is returned | The diagnostic output was insufficient; it does not prove which route or backend failed. | Next wrap, keep `--log-level debug`, 25s. |
| The observed route differs from the intended route | Another routing source took precedence. The current result does not test the intended route. | Reconcile the conflicting sources for this operation, then verify the selected route again. |
| Configuration parsing or version validation fails | Himalaya failed before networking. | Follow `configuration.md`; do not change proxy routing. |

## User-facing response

Before replying, follow any remaining wrap in the chain. Do not expose internal variable names, proxy ports, or `--backend` unless the user is explicitly troubleshooting those details.

Tell the user the matching locked line from the provider guide (Gmail: `gmail.md`).

Recommend credential revocation only when the secret was actually exposed outside secure input or storage.
