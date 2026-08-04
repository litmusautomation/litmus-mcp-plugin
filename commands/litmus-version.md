---
description: Show Litmus MCP server, SDK, and litmus-cli versions. Pass "check" to compare against latest releases.
---

Args: `$ARGUMENTS`

1. Call `get_mcp_server_info`. Pass `check_updates=true` if `$ARGUMENTS` contains `check`, `update`, or `latest`; that reaches out to GitHub and needs internet from the machine running the server.

This tool needs no Edge connection and always works, which makes it the right first call when the user is unsure whether the plugin is even wired up correctly.

Report as a short list: MCP server version, litmussdk version, litmus-cli version and path, litmus-cli pinned release, Python version, platform.

Note when the running `litmus-cli` version differs from the pinned release. That happens when a copy earlier on `PATH` wins over the pinned one the server would otherwise download, and it is worth surfacing because the `litmus_sdk_*` tools run through whichever binary resolves.

If `check_updates` was requested, add one line per component saying whether an update is available.

Do not pass `upgrade_cli=true` unless the user explicitly asks to upgrade the CLI. It downloads and switches to the newest release for this server process only. The MCP server itself cannot self-upgrade; for that, the plugin needs updating through the plugin host (`/plugin marketplace update` in Claude Code, `codex plugin marketplace upgrade` in Codex).

This tool reports the CLI copy the **MCP server** resolved. That is a different thing from a `litmus-cli` on the user's `PATH` for shell use, and the two can be different versions. When the user cares about the shell one:

```bash
litmus-cli --version          # what the shell resolves
litmus-cli update --check     # what the latest release is
```

`/litmus-cli-setup` covers installing and authenticating that copy.
