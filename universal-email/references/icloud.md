# iCloud Mail

iCloud Mail uses IMAP/SMTP and an Apple app-specific password.

## What the user needs

- the complete iCloud Mail address;
- an app-specific password generated for this mail client.

Do not ask for the Apple Account password.

## 对用户说（照念）

1. 「把用来收信的 iCloud 邮箱地址发我。应用专用密码不要发到聊天里。」
2. 「Apple 账号要先打开双重认证。然后打开 https://account.apple.com/account/manage 登录，在登录与安全里生成 App 专用密码，名称填 Cola。生成后跟我说一声，不要把密码发过来。」
3. When they have generated it: use the 弹窗前 / 成功 / 取消 / 超时 lines in `configuration.md`, then run `prompt` in the same turn.
4. After `account check` succeeds: 「iCloud 邮箱已经连好了。以后直接说『看看今天的邮件』就行。」
5. If authentication fails: 「这个应用专用密码好像不对。去 https://account.apple.com/account/manage 再生成一串，生成后跟我说，我会再弹出窗口。」

This mail flow is separate from iCloud Calendar. Do not send the user to the calendar helper.

## How to connect

1. Confirm the complete iCloud Mail address used to receive mail.
2. Guide two-factor authentication and the app-specific password with the lines above.
3. Collect the app-specific password with the bundled helper as described in `configuration.md`. Use `--account universal-email/icloud`, title `Connect iCloud Mail` / `连接 iCloud 邮箱`, secret label `App-specific password` / `应用专用密码`. Never run the Himalaya wizard. Never open a terminal for the user.
4. Write the iCloud IMAP/SMTP account from `configuration.md`. Then run `himalaya --account icloud --json account check`.

## Validate and troubleshoot

If authentication fails, confirm the mailbox address rather than an Apple Account alias, confirm two-factor authentication, and generate a new app-specific password. Apple revokes app-specific passwords after some account password or security changes.

Discover mailboxes before saving a sent copy. Do not assume iCloud exposes `Sent` or `Sent Messages`. If mailbox discovery returns only `Inbox`, send without `--save`; do not create a folder automatically. Delivery and sender-side archiving are separate outcomes.
