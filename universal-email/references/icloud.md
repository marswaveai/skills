# iCloud Mail

iCloud Mail uses IMAP/SMTP and an Apple app-specific password.

## What the user needs

- the complete iCloud Mail address;
- an app-specific password generated for this mail client.

Do not ask for the Apple Account password.

## How to connect

1. Confirm the complete iCloud Mail address used to receive mail.
2. Ask the user to enable two-factor authentication for the Apple Account.
3. Open <https://account.apple.com/account/manage>.
4. Under **Sign-In and Security**, generate an app-specific password with a recognizable label such as `Cola`.
5. Store the app-specific password with the bundled helper as described in `configuration.md`. Use `--account universal-email/icloud`, title `Connect iCloud Mail` / `连接 iCloud 邮箱`, secret label `App-specific password` / `应用专用密码`. Never run the Himalaya wizard. Never open a terminal for the user.
6. Write the iCloud IMAP/SMTP account from `configuration.md`. Then run `himalaya --account icloud --json account check`.

This mail flow is separate from iCloud Calendar. Do not send the user to the calendar helper.

## Validate and troubleshoot

If authentication fails, confirm the mailbox address rather than an Apple Account alias, confirm two-factor authentication, and generate a new app-specific password. Apple revokes app-specific passwords after some account password or security changes.

Discover mailboxes before saving a sent copy. Do not assume iCloud exposes `Sent` or `Sent Messages`. If mailbox discovery returns only `Inbox`, send without `--save`; do not create a folder automatically. Delivery and sender-side archiving are separate outcomes.
