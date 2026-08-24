# Gmail

Gmail uses IMAP/SMTP and a Google app password. Personal Gmail and Google Workspace Gmail use the same connection method. They differ only in whether Google will issue an app password.

## What the user needs

- the full Gmail or Workspace address;
- a newly generated 16-character app password.

Do not ask for the normal Google password or any Google OAuth client credential.

## Personal Gmail vs Google Workspace

| Account | How to tell | What changes |
| --- | --- | --- |
| Personal Gmail | `@gmail.com` or `@googlemail.com` | The user turns on 2-Step Verification, then creates an app password. |
| Google Workspace | Company or school domain hosted by Google | Same IMAP/SMTP hosts and the same app password, **if** the organization allows app passwords. If the admin disabled them, or the account uses Advanced Protection or security-key-only 2-Step Verification, this skill cannot connect. |

Ask once only when the domain does not make it obvious. Handle that distinction in chat. Do not add a separate form or a Google mail OAuth flow — this skill has none.

## App passwords require 2-Step Verification

Google issues app passwords only when 2-Step Verification is on. Official: <https://support.google.com/accounts/answer/185833>.

If <https://myaccount.google.com/apppasswords> shows **「您的账号不支持您正在尝试的设置」** (or English **“Your account doesn't support the setup you're trying”**), that is Google's app-passwords page, not a Cola or mailbox-server failure, and not a Microsoft page. Do not retry IMAP connect in a loop. Do not ask for the normal Google password.

For **personal Gmail** this almost always means 2-Step Verification is off (or is security-key-only). Tell the user in product words:

- Gmail 要先打开两步验证，才能生成应用专用密码。不是邮箱密码错了，也不是 Cola 连不上。
- Open [Google 两步验证](https://myaccount.google.com/signinoptions/two-step-verification) and finish Google's setup.
- Then open [应用专用密码](https://myaccount.google.com/apppasswords), generate a 16-character password, and come back. Spaces on screen are not part of it.
- You will then open the local page so they can enter it.

Wait until they confirm 2-Step Verification is on and they have an app password, then continue connect.

For **Workspace / work / school**, Google also hides app passwords when the organization disabled them, the account is on Advanced Protection, or 2-Step Verification is security-key-only. Stop. Explain that this mailbox skill cannot connect until the organization allows app passwords. Do not walk them through creating a Google Cloud OAuth client.

If 2-Step Verification is already on and App passwords is still missing, the same Google reasons apply. Do not invent another setup path.

## How to connect

1. Confirm the full address.
2. Walk through 2-Step Verification and app password as above. Use a recognizable label such as `Cola`.
3. Store the app password with the bundled helper as described in `configuration.md`. Use `--account universal-email/gmail`, title `Connect Gmail` / `连接 Gmail`, secret label `App password` / `应用专用密码`. Never run the Himalaya wizard. Never open a terminal for the user.
4. Write the Gmail IMAP/SMTP account from `configuration.md`. Then run `himalaya --account gmail --json account check`.

## Validate and troubleshoot

If authentication fails, confirm the address, confirm the app password was entered on the local page (display spaces are stripped), check that it was not revoked, and generate a new one if needed. A Workspace account that cannot create app passwords cannot be connected with this skill.
