# Gmail

Gmail through Himalaya uses IMAP/SMTP and a Google app password.

## What the user needs

- the full Gmail address;
- a newly generated 16-character app password.

Do not ask for the normal Google password or any Google OAuth client credential.

## How to obtain it

1. Confirm the full Gmail address.
2. Ask the user to enable two-step verification for that Google Account.
3. Open <https://myaccount.google.com/apppasswords>.
4. Generate an app password with a recognizable label such as `Himalaya`.
5. Run the bare `himalaya` setup wizard in a PTY, or configure the account as described in `configuration.md`. Supply the full address and the displayed 16-character password through the chosen secure credential mechanism. Spaces shown for readability are not part of it.

App passwords may be unavailable for managed Google Workspace accounts, Advanced Protection, or security-key-only two-step verification. In that case, explain that this connection method is unavailable for the account and an OAuth-based integration is required.

## Validate and troubleshoot

If authentication fails, confirm the address, remove display spaces from the 16-character password, check that the app password was not revoked, and generate a new one if needed. A Workspace account that cannot create app passwords requires an OAuth-based integration instead.
