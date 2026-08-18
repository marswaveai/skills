# Sources and versions

- Himalaya CLI: `pimalaya/himalaya` v2 development line, pinned revision `923414155f4281d681f4ea8631954f406acf51ee`.
- Build provenance: official Pimalaya `Releases` workflow run `31480344899`, artifacts `9097270481`, `9097544395`, and `9097225227`.
- IMAP client: `io-imap` v0.4.0 at revision `2024c46cea7acd7c88a7b1e0eaf6f137955f5d3a`. This version removes the blanket five-second read timeout present in v0.3.1.
- Network stream: `pimalaya/stream`. Its default `Proxy::System` resolves proxy environment variables for IMAP and SMTP.
- Proxy handshakes: `pimalaya/io-proxy`, providing SOCKS5 and HTTP `CONNECT` clients.
- Community Skill reference: `NousResearch/hermes-agent`, `skills/email/himalaya`, main branch.
- Community Skill reference: `openclaw/openclaw`, `skills/himalaya/SKILL.md`, main branch.

The community Skills target older Himalaya command shapes. `SKILL.md` and `references/configuration.md` in this package target the pinned v2 binary and are checked against its executable help and configuration parser. Binary hashes are recorded in `SHA256SUMS`; each final ZIP hash is recorded in its sibling `.zip.sha256` file.
