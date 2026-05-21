# src/

MCP server code that gets launched as a stdio subprocess by Claude Code and Codex. Mirrors the `src/` tree from [litmus-mcp-server](https://github.com/litmusautomation/litmus-mcp-server) with one small local patch.

## Local patch

`server.py` here differs from upstream in one place: `StdioRequestContext.__init__` populates the LEM-related env vars and the certificate-validation flag in addition to direct-Edge + NATS + InfluxDB credentials. This is required because LEM auth (`get_litmus_connection` LEM-bridge path, `get_lem_connection`) reads `EDGE_MANAGER_URL`, `EDGE_API_TOKEN`, `EDGE_MANAGER_PROJECT_ID`, `EDGE_MANAGER_DEVICE_ID`, `EDGE_MANAGER_ADMIN_URL`, `VALIDATE_CERTIFICATE`, and `NATS_TOKEN` - none of which the upstream `StdioRequestContext` exposes.

The plugin's `mcp/claude.mcp.json` substitutes all of these from `userConfig` so users only fill the ones their workflow needs (Edge-only users leave the LEM fields blank).

Once this patch is merged upstream, drop the `--exclude='server.py'` line in `scripts/sync-from-server.sh` and let normal syncs handle it.

## Sync

```bash
./scripts/sync-from-server.sh ../litmus-mcp-server
```

Syncs everything except web-client files (`web_client.py`, `client_utils.py`, etc.) and `server.py` (kept locally for the patch above).

## Auth flow in stdio mode

1. Claude Code / Codex launches `python src/server.py` with `ENABLE_STDIO=true` and the credential env vars populated from `userConfig`.
2. `server.py.__main__` reads `ENABLE_STDIO` and calls `run_stdio_server()`.
3. `StdioRequestContext()` snapshots env vars into a case-insensitive `HeaderDict` and is set into `current_request` (the same `ContextVar` the SSE transport uses).
4. Every tool call retrieves `current_request.get()` as `request` and reads creds via `request.headers.get("EDGE_URL")` etc.
5. `utils/auth.py` validates and constructs SDK connections from those values.

Direct-Edge, LEM, LEM-bridge, NATS, and InfluxDB auth paths all work via this same mechanism.
