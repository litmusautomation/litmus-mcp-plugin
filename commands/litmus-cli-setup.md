---
description: Install, authenticate, and verify the litmus-cli binary for shell use, seeding a profile from this plugin's configured credentials.
---

Args: `$ARGUMENTS` (optional profile name, default `default`)

Gets `litmus-cli` working in the shell. This is separate from the MCP server's private copy under `~/.cache/litmus-mcp-server/bin/`, which backs the `litmus_sdk_*` tools and is deliberately not on `PATH`.

## 1. Check what is present

```bash
litmus-cli --version && command -v litmus-cli
```

If it is missing or you want the newest release:

```bash
./scripts/install-cli.sh --check   # report installed vs latest
./scripts/install-cli.sh           # download, verify SHA256, install to ~/.local/bin
```

Already installed but old? Prefer its own updater: `litmus-cli update`. Report if `~/.local/bin` is not on `PATH`, since the install succeeds and the command still will not resolve.

## 2. Authenticate

Ask the user which they want, and recommend the first:

- **Browser sign-in** (recommended): `litmus-cli login`, or `litmus-cli login le` for Edge only. For Litmus Edge this mints a dedicated OAuth credential for the CLI and never stores the password. In a container or remote shell add `--bind 0.0.0.0 --port 4005 --no-browser` and hand them the printed URL, because the browser cannot reach the CLI's localhost there.
- **Seed from this plugin's existing config**: if `EDGE_URL`, `EDGE_API_CLIENT_ID`, and `EDGE_API_CLIENT_SECRET` are already set in the environment, write them into a profile so the CLI matches what the MCP server talks to.

For the seeding path, build the `config set` call from environment variables rather than pasting literal secrets, so nothing sensitive lands in the transcript:

```bash
litmus-cli config set --profile "${PROFILE:-default}" \
  --EDGE_URL "$EDGE_URL" \
  --EDGE_API_CLIENT_ID "$EDGE_API_CLIENT_ID" \
  --EDGE_API_CLIENT_SECRET "$EDGE_API_CLIENT_SECRET"
```

Add only the optional blocks that are actually set: `--EDGE_MANAGER_URL` and `--EDGE_API_TOKEN` for LEM, `--NATS_TOKEN` / `--NATS_SOURCE` / `--NATS_PORT` for the broker, `--INFLUX_USERNAME` / `--INFLUX_PASSWORD` / `--INFLUX_HOST` for history. Pass `--EDGE_VALIDATE_CERTIFICATE false` when the Edge uses a self-signed certificate.

The flag names are the uppercase variable names, which is easy to get wrong. `config set` updates only the keys passed and preserves the rest.

If none of those variables are present in the environment, do not invent values. Say so and route the user to `litmus-cli login`.

## 3. Verify

```bash
litmus-cli config show          # secrets masked
litmus-cli le version           # device firmware version and connection mode
litmus-cli le devices | jq 'length'
```

A working `le version` is the real confirmation. If it fails, the error names the missing keys directly, so read it rather than guessing.

For the data plane, note that it authenticates **separately** and Edge credentials alone are not enough. Check only if the user cares:

```bash
litmus-cli le data measurements | jq 'length'
```

Needs an InfluxDB DB user. Live `subscribe` needs a broker access-account API key (`NATS_TOKEN`).

## Output

Report as a short checklist: binary version and path, whether `PATH` is fine, auth method used, profile name written, and the result of `le version`. Then show two or three commands worth trying next, drawn from the `litmus-cli` skill.

Never print secret values, including from `config show`, which masks them for exactly this reason.
