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

Ask once only when the domain does not make it obvious. Do not invent a Google mail OAuth flow.

## 对用户说（照念）

1. 「把要连接的 Gmail 地址发我。应用专用密码不要发到聊天里。」
2. If they do not yet have an app password:

「应用专用密码不是 Google 登录密码。先打开这个页面完成两步验证：https://myaccount.google.com/signinoptions/two-step-verification 按页面做完。再打开这个页面生成 16 位应用专用密码：https://myaccount.google.com/apppasswords 名称填 Cola。页面上的空格不用管。生成后跟我说一声，不要把密码发过来。」

3. If https://myaccount.google.com/apppasswords shows 「您的账号不支持您正在尝试的设置」:

「这是 Google 的页面，不是 Cola 连不上。个人 Gmail 一般是还没开两步验证：先去 https://myaccount.google.com/signinoptions/two-step-verification 做完，再回应用专用密码页。公司邮箱如果还是打不开，需要管理员开放应用专用密码，这个邮箱技能连不上。」

4. When they have generated the password: use the 弹窗前 / 成功 / 取消 / 超时 lines in `configuration.md`, then run `prompt` in the same turn.

5. After `account check` succeeds: 「Gmail 已经连好了。以后直接说『看看今天的邮件』就行。」

6. If authentication fails after they filled the window: 「这个应用专用密码好像不对。去 https://myaccount.google.com/apppasswords 再生成一串，生成后跟我说，我会再弹出窗口。」

## How to connect

1. Confirm the full address in chat with the lines above.
2. Walk through 2-Step Verification and app password. Official: <https://support.google.com/accounts/answer/185833>.
3. Collect the app password with the bundled helper as described in `configuration.md`. Use `--account universal-email/gmail`, title `Connect Gmail` / `连接 Gmail`, secret label `App password` / `应用专用密码`. Never run the Himalaya wizard. Never open a terminal for the user.
4. Write the Gmail IMAP/SMTP account from `configuration.md`. Then run `himalaya --account gmail --json account check`.

## Validate and troubleshoot

If authentication fails, confirm the address, confirm they entered the new app password in the window (display spaces are stripped), and generate a new one if needed. A Workspace account that cannot create app passwords cannot be connected with this skill.
