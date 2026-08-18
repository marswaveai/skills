# iCloud Mail

iCloud Mail through Himalaya uses IMAP/SMTP and an Apple app-specific password.

## What the user needs

- the complete iCloud Mail address;
- an app-specific password generated for this mail client.

Do not ask for the Apple Account password.

## How to obtain it

1. Confirm the complete iCloud Mail address used to receive mail.
2. Ask the user to enable two-factor authentication for the Apple Account.
3. Open <https://account.apple.com/account/manage>.
4. Under **Sign-In and Security**, generate an app-specific password with a recognizable label such as `Himalaya`.
5. Run the bare `himalaya` setup wizard in a PTY, or configure the account as described in `configuration.md`. Supply the complete address and generated password through the chosen secure credential mechanism.

## Validate and troubleshoot

If authentication fails, confirm the mailbox address rather than an Apple Account alias, confirm two-factor authentication, and generate a new app-specific password. Apple revokes app-specific passwords after some account password or security changes.

Discover mailboxes before saving a sent copy. Do not assume iCloud exposes `Sent` or `Sent Messages`. If mailbox discovery returns only `Inbox`, send without `--save`; do not create a folder automatically. Delivery and sender-side archiving are separate outcomes.
