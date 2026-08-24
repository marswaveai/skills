# Proxy routing and diagnosis

Use this guide for connection routing and network failures. Keep credentials, account configuration, and mailbox operations in their provider guides.

## Contents

- [Principles](#principles)
- [Provider guidance](#provider-guidance)
- [Split IMAP and SMTP](#split-imap-and-smtp)
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

| Provider | Routing direction |
| --- | --- |
| Gmail IMAP/SMTP | Receiving and sending are two routes. Do not assume both need a proxy, and do not assume both need direct. A web proxy (including Cola's) may carry IMAP and block SMTP, or the reverse; the working pair also changes when the user switches nodes. Probe IMAP and SMTP as separate invocations (see [Split IMAP and SMTP](#split-imap-and-smtp)). Keep whichever route completes each backend. Never treat one combined `account check` timeout as “the mailbox is down” or “the password is wrong”. |
| QQ Mail | Prefer the normal local route. If a global proxy intended for another provider interferes, diagnose a provider-specific bypass rather than changing QQ credentials. |
| iCloud Mail | Prefer the normal local route. If a global proxy causes timeouts or unreachable errors, diagnose a provider-specific bypass before changing credentials. |
| Outlook through Microsoft Graph | Treat this as HTTPS traffic. Do not reuse conclusions drawn from IMAP or SMTP ports. |
| Other IMAP/SMTP | Start from the provider's documented hosts and the device's normal route. Introduce a proxy only when network reachability requires it. |

These are directions, not fixed results. Confirm the route actually selected on the current device.

## Split IMAP and SMTP

Himalaya's default `account check` uses **one environment for every backend**. If IMAP and SMTP need different routes, that command hangs until the tool timeout (45–60s) and prints nothing — so the Agent cannot tell which side failed. Cola injects `ALL_PROXY` / `HTTPS_PROXY` into the process that runs these commands; a bare `himalaya` therefore uses Cola's proxy for both receiving and sending.

Do not use default `account check` as the only Gmail verdict when any of these is true: proxy variables are set; Cola proxy is on; a previous check timed out; IMAP works but SMTP does not, or the reverse.

Probe **four times at most**, each with a 25-second tool timeout. Stop a hanging probe and move on. Success is JSON `"ok": true` for that backend.

**IMAP, current environment** (Cola proxy if present — leave the process env unchanged):

```bash
himalaya --account gmail --backend imap --log-level debug --json account check
```

**IMAP, direct** (this invocation only; do not change the user's proxy settings). Unset **both** letter cases — Cola writes `ALL_PROXY` / `HTTPS_PROXY`, shells often write `all_proxy` / `https_proxy`. Leaving `ALL_PROXY` set means this is not a direct test:

```bash
env -u all_proxy -u ALL_PROXY -u https_proxy -u HTTPS_PROXY -u http_proxy -u HTTP_PROXY \
  himalaya --account gmail --backend imap --log-level debug --json account check
```

**SMTP, current environment:**

```bash
himalaya --account gmail --backend smtp --log-level debug --json account check
```

**SMTP, direct** — same `env -u` list as IMAP direct:

```bash
env -u all_proxy -u ALL_PROXY -u https_proxy -u HTTPS_PROXY -u http_proxy -u HTTP_PROXY \
  himalaya --account gmail --backend smtp --log-level debug --json account check
```

Skip a probe whose answer is already known. Confirm each selected route from the `dial … (source: direct|all_proxy|https_proxy)` line. Himalaya reads `all_proxy` first (either letter case), then `https_proxy`. If both SOCKS `all_proxy` and HTTP `https_proxy` are set, the SOCKS value wins; to test Cola's HTTP proxy, clear `all_proxy` / `ALL_PROXY` for that invocation and set `https_proxy` to the HTTP URL.

Keep the winning wrap for the rest of the session: IMAP wraps on envelope/mailbox/message **read** commands; SMTP wraps on compose/reply/forward **send**. Do not ask the user to toggle Cola's proxy for this.

PowerShell: the same four probes, each in a child `powershell -NoProfile -Command` so `$env:` changes do not leak. For a direct probe, `Remove-Item` `all_proxy`, `ALL_PROXY`, `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY` before invoking Himalaya.

Same split applies to QQ Mail, iCloud Mail, and other IMAP+SMTP accounts when a combined check times out or a proxy is present.

## Discover and verify

Discover active routing from the environment in which Cola launches Himalaya. If it is incomplete, inspect the current operating system or proxy application's settings with appropriate platform tools. Preserve every endpoint's reported protocol; do not guess or scan common ports.

If several proxy sources exist, determine which one Himalaya actually selected. A higher-priority or stale setting can mask another valid route. Resolve that conflict only for the current Himalaya operation.

Use the split IMAP / SMTP debug checks above, not a combined `account check`, to establish:

- whether the selected route is direct, SOCKS5, or HTTP CONNECT;
- whether the proxy handshake completed;
- whether TLS completed;
- whether IMAP and SMTP each responded, **on their own route**.

Do not discard diagnostic output before interpreting a timeout. Do not use a direct socket probe as proof of Himalaya connectivity because it may bypass the route used by the CLI. Do not expose proxy credentials, mail credentials, configuration contents, or complete debug logs.

## Error-to-recovery guidance

| Observed error or stage | Meaning | Recovery direction |
| --- | --- | --- |
| SOCKS5 handshake ends with `failed to fill whole buffer` | The endpoint did not complete a SOCKS5 handshake. It may actually be an HTTP proxy, or the SOCKS listener may be invalid. | Re-discover the endpoint's declared protocol. If it is HTTP, use it as HTTP CONNECT; if it is SOCKS5, check whether that configured listener is still valid. Do not classify the endpoint from its port. |
| The proxy connection is refused | The local proxy is stopped or the configured endpoint is stale. | Re-read the device's current proxy settings. Do not guess another port or change mail credentials. |
| HTTP CONNECT is rejected | The proxy rejected authentication, the destination, or the mail port. | Check the configured proxy or choose another already available route that permits the target traffic. Do not treat this as an email-password failure. |
| Gmail completes TLS and `CAPABILITY`, then IMAP authentication stalls | The selected Gmail edge route is not completing IMAP authentication; this can happen with either direct DNS or a proxy route. | Keep the account and password unchanged. Retry with the Gmail preset's `imap.googlemail.com` compatibility endpoint, then try another available route only if that endpoint also stalls. Do not misreport this as a missing password. |
| Gmail completes the proxy handshake and TLS, but never reaches `CAPABILITY` | The proxy is reachable but is not relaying the mail protocol correctly. | Look for another correctly declared route already available on the device, or guide the user to choose a proxy node that supports the affected raw TCP mail traffic. Do not repeat the same unchanged route. |
| QQ Mail or iCloud Mail becomes unreachable only when proxied | A global proxy is interfering with a provider that normally uses the local route. | Diagnose a provider-specific direct route or bypass using the controls available on the device. Do not disable the user's global proxy or change credentials. |
| IMAP succeeds but SMTP times out or disconnects | Receiving works; the sending route or SMTP mode is failing. | Preserve the working IMAP wrap. Probe SMTP on the other route (`--backend smtp`). Do not report the whole account as disconnected. Do not regenerate the app password. |
| Combined `account check` times out with empty output | IMAP and SMTP were tested together; the wrapper killed the process before either result printed. This is not evidence that both failed, and not a password error. | Immediately run the [split probes](#split-imap-and-smtp). Do not repeat the same combined check with a longer timeout. |
| SMTP send stalls through a proxy: the SOCKS or HTTP CONNECT tunnel completes but `smtp.<provider>:465`/`:587` never returns a banner or completes TLS | The proxy node accepts the tunnel but does not relay outbound SMTP ports (a common anti-spam egress block). It is not a Gmail, credential, or Himalaya fault, and IMAP over the same proxy can still work. | First retry that one send on the direct route by clearing the proxy variables for that invocation only (see SKILL.md); on many networks the SMTP host is reachable directly. If direct also cannot reach the SMTP host, guide the user to a proxy node that permits SMTP ports. Switching the tunnel type between SOCKS and HTTP CONNECT does not help when both point at the same node. |
| SMTP succeeds but saving to Sent fails | Delivery and saving a sender-side copy are separate stages. | Do not resend automatically. Check delivery first, then discover the provider's Sent mailbox behavior. |
| Direct connection times out before TLS | The current network cannot reach the target directly, or the host is wrong. | Confirm the provider host. For a provider commonly blocked on the current network, discover an available compatible proxy; otherwise continue local network diagnosis. |
| TLS certificate validation fails | The route may be intercepting TLS, the system clock may be wrong, or the trust store may be invalid. | Use a trusted route and validate the device environment. Never disable certificate verification. |
| Authentication fails after the server responds | The network route worked; the credential or provider authorization is wrong. | Follow the provider credential guide. Do not continue changing proxies unless the error also shows a network-stage failure. |
| Only a generic `service unreachable` is returned | The summary hid the failing backend and stage. | Obtain stage-level diagnostics, distinguish IMAP from SMTP, then follow the matching direction in this table. |
| Only a wrapper timeout is returned | The diagnostic output was insufficient; it does not prove which route or backend failed. | Split IMAP from SMTP, keep `--log-level debug`, 25s per probe, then follow the matching direction. |
| The observed route differs from the intended route | Another routing source took precedence. The current result does not test the intended route. | Reconcile the conflicting sources for this operation using the controls available on the current device, then verify the selected route again. |
| Configuration parsing or version validation fails | Himalaya failed before networking. | Follow `configuration.md`; do not change proxy routing. |

## User-facing response

Before replying, follow any safe recovery direction that is still available. Do not expose internal variable names, proxy ports, or protocol jargon unless the user is explicitly troubleshooting those details.

Tell the user only the matching locked line from the provider guide (Gmail: `gmail.md`). Do not expose internal variable names, proxy ports, or `--backend` unless the user is explicitly troubleshooting those details.

Recommend credential revocation only when the secret was actually exposed outside secure input or storage.
