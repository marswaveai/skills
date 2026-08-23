# Proxy routing and diagnosis

Use this guide for Google Calendar network routing. Keep authorization scopes, config directory, and calendar commands in `SKILL.md`.

## Contents

- [Principles](#principles)
- [Routing direction](#routing-direction)
- [Discover](#discover)
- [Apply to one invocation](#apply-to-one-invocation)
- [Error-to-recovery guidance](#error-to-recovery-guidance)
- [User-facing response](#user-facing-response)

## Principles

1. Discover the proxy protocol from the current process, then the operating system or proxy application. Never infer SOCKS5 or HTTP CONNECT from a port number.
2. Adapt the diagnosis to the current device. Do not assume that macOS, Windows, and every host shell expose proxy settings in the same place, or that the host injected proxy variables into this process.
3. Keep routing changes local to **that one** `gws` invocation. Do not alter the user's global proxy settings. Do not assign persistent `$env:` values in a PowerShell session.
4. Leave `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` unchanged on every wrapped invocation.
5. `gws auth status` succeeding only proves local credentials. It is not evidence that Calendar API or token exchange can reach Google.
6. A hang that prints only `Using keyring backend: keyring` is an unfinished HTTPS call, not an empty agenda and not expired authorization. Do not repeat the same unwrapped command.
7. Do not use `nc`, `telnet`, or a direct socket probe as proof of `gws` connectivity: those checks bypass its proxy selection.
8. Do not dump raw `gws` output, proxy credentials, or config-directory contents.

## Routing direction

Google Calendar traffic is HTTPS to `oauth2.googleapis.com` (token refresh / login) and `www.googleapis.com` (Calendar API). Treat this as web HTTPS, not mail.

If the device already has an HTTP or HTTPS proxy, use it on the first `gws auth login` and the first calendar command (`+agenda`, `calendarList`, `events`, …). Do not wait for a timeout to discover that the direct route is blocked.

Prefer HTTP CONNECT (`https_proxy=http://HOST:PORT`) over SOCKS (`all_proxy=socks5://...`). When HTTP/HTTPS and SOCKS are both configured, use HTTP CONNECT and clear `all_proxy` / `ALL_PROXY` for that invocation — mixed SOCKS + HTTP often fails token exchange with `Hyper error: client error (Connect)`.

## Discover

1. Read the current process environment: `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY`, `all_proxy`, `ALL_PROXY`. Preserve the protocol each variable already states.
2. If those variables are missing or incomplete, read the device proxy settings:
   - macOS: `scutil --proxy` — use `HTTPEnable` / `HTTPSEnable` with `HTTPProxy`+`HTTPPort` or `HTTPSProxy`+`HTTPSPort` when enabled. `SOCKSEnable` is SOCKS, not HTTP, even when the port looks like an HTTP port.
   - Windows: user Internet Settings / `reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` (`ProxyEnable`, `ProxyServer`).
3. If several sources exist, pick one compatible HTTP CONNECT endpoint for `gws` and apply it only to this invocation. Do not guess or scan common ports.

`gws` reads `https_proxy` / `HTTPS_PROXY`, `http_proxy` / `HTTP_PROXY`, and `all_proxy` / `ALL_PROXY`. Calendar calls are HTTPS, so an HTTP proxy supplied only as `http_proxy` must also be copied onto `https_proxy` for that invocation.

## Apply to one invocation

Replace `<gws>` with the resolved bundled absolute path from `SKILL.md`. Replace the proxy URL with the discovered HTTP CONNECT URL.

Unix:

```bash
env -u ALL_PROXY -u all_proxy \
  HTTPS_PROXY='http://HOST:PORT/' \
  HTTP_PROXY="$HTTPS_PROXY" \
  https_proxy="$HTTPS_PROXY" \
  http_proxy="$HTTPS_PROXY" \
  NO_PROXY='localhost,127.0.0.1,::1' \
  no_proxy="$NO_PROXY" \
  <gws> calendar +agenda --today --timezone 'Asia/Shanghai'
```

PowerShell has no `env -u`. Scope the change to a child process so the user's proxy stays intact in this session:

```powershell
powershell -NoProfile -Command @'
Remove-Item Env:ALL_PROXY,Env:all_proxy -ErrorAction SilentlyContinue
$proxy = 'http://HOST:PORT/'
$env:HTTPS_PROXY = $proxy
$env:HTTP_PROXY = $proxy
$env:https_proxy = $proxy
$env:http_proxy = $proxy
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
$env:no_proxy = $env:NO_PROXY
& '<gws>' calendar +agenda --today --timezone 'Asia/Shanghai'
'@
```

Use the same wrap for `gws auth login` and every calendar API command. `gws auth status` may stay unwrapped.

To force a single command onto the direct route (only when diagnosing a proxy that is interfering), clear the proxy variables for that invocation only — the same `env -u` / child-process pattern — without touching the user's global proxy.

## Error-to-recovery guidance

| Observed error or stage | Meaning | Recovery direction |
| --- | --- | --- |
| Hang after `Using keyring backend: keyring`, or wrapper timeout, with no calendar payload | The HTTPS call never completed. Direct to Google is a common cause when a proxy exists but was not passed into this invocation. | Discover the device HTTP/HTTPS proxy and retry **that one** command with the wrap above. Do not rerun the unwrapped command. Do not report “no events today” or expired authorization. |
| `Hyper error: client error (Connect)` during login or token exchange | Mixed SOCKS `all_proxy` with HTTP, or the SOCKS endpoint is not usable as HTTP CONNECT. | Re-discover the declared protocol. Retry with HTTP CONNECT only, `all_proxy` / `ALL_PROXY` cleared. Do not infer the protocol from the port. |
| Proxy connection refused | The local proxy is stopped or the configured endpoint is stale. | Re-read the device's current proxy settings. Do not guess another port or start a new login. |
| HTTP CONNECT rejected | The proxy refused authentication, the destination, or HTTPS. | Check the configured proxy, or use another already declared HTTP route on the device. Do not treat this as an account problem. |
| Direct connection times out; no proxy is configured on the device | The current network cannot reach Google HTTPS. | Say the calendar service could not be reached and what the user can enable locally. Do not invent events. |
| TLS certificate validation fails | The route may be intercepting TLS, the system clock may be wrong, or the trust store may be invalid. | Use a trusted route and validate the device environment. Never disable certificate verification. |
| Authorization or permission error after the server responded | The network route worked; credentials or scopes are the problem. | Follow Authorization in `SKILL.md`. Do not keep changing proxies unless the error also shows a network-stage failure. |
| `auth status` is valid but calendar commands hang | Local credentials are fine; the API route is not. | Apply the HTTP CONNECT wrap to the calendar command. Status success is not a route check. |

## User-facing response

Before replying, follow any safe recovery direction that is still available. Do not expose internal variable names, proxy ports, or protocol jargon unless the user is explicitly troubleshooting those details.

Tell the user only:

- whether authorization is still valid, separately from whether the calendar could be read
- which stage remains blocked in plain language
- what was already tried
- the next action they must take, if any
