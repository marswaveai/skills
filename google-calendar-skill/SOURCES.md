# Sources and versions

- Google Workspace CLI (`gws`): `googleworkspace/cli` v0.22.5, official GitHub release binaries.
  - `darwin-arm64`: `google-workspace-cli-aarch64-apple-darwin.tar.gz`, archive sha256 `1d2a9ffd5bc9b2c2c4b48630daf082fad13d9e57d741988a2c248eed562f7dac`
  - `darwin-x64`: `google-workspace-cli-x86_64-apple-darwin.tar.gz`, archive sha256 `51f9bd731404d4bba26c36e2e30dd68c56dccd1f834c01252cb0b14d6a6544b2`
  - `win32-x64`: `google-workspace-cli-x86_64-pc-windows-msvc.zip`, archive sha256 `407705d695dc83d48b1c5f50d71b5aa64095bf6f17d5b439b2e9a373bbe67ec2`
- Skill reference: `googleworkspace/cli` tag `v0.22.5`, `skills/gws-calendar`, `skills/gws-calendar-agenda`, `skills/gws-calendar-insert`, and `skills/gws-shared`.

`SKILL.md` is a calendar-only rewrite of the upstream skills:

- Only the calendar command surface is kept; every other Google service and all upstream non-calendar skills, examples, and repository-interaction guidance are removed.
- Login uses `gws auth login` with calendar-only scopes (`https://www.googleapis.com/auth/calendar.events`, `https://www.googleapis.com/auth/calendar.calendarlist.readonly` plus OpenID identity). Config directory follows `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` when set.
- Resources outside the granted scopes (`acl`, calendar create/delete, `settings`, `watch`/`channels`) are documented as unavailable instead of listed as commands.

Binary hashes are recorded in `SHA256SUMS`; the final ZIP hash is recorded in the sibling `.zip.sha256` file.
