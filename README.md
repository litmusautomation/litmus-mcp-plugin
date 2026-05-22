<p align="center">
  <a href="https://litmus.io">
    <picture>
      <source media="(prefers-color-scheme: light)" srcset="./litmus-logo-light.svg" />
      <source media="(prefers-color-scheme: dark)" srcset="./litmus-logo-dark.svg" />
      <img src="./litmus-logo-light.svg" height="60" alt="Litmus logo" />
    </picture>
  </a>
</p>

<p align="center">
  <a href="https://docs.litmus.io">
    <img src="https://img.shields.io/badge/Litmus-Docs-2acfa6?style=flat-square" alt="Documentation" />
  </a>
  <a href="https://www.linkedin.com/company/litmus-automation/" >
    <img src="https://img.shields.io/badge/LinkedIn-Follow-0a66c2?style=flat-square" alt="Follow on LinkedIn" />
  </a>
</p>

# Litmus MCP Plugin

Natural-language access to Litmus Edge industrial IoT, packaged as a plugin for Claude Code and OpenAI Codex.

One repo, two plugin hosts. Same MCP server code under the hood.

## What you get

- **57 MCP tools** covering DeviceHub (devices, drivers, tags), DataHub (NATS topics, InfluxDB queries), Digital Twins (models, instances, attributes, hierarchy), Applications (Docker containers), System (events, network, firewall, packet capture), and Litmus Edge Manager (fleet, licensing, dashboard, bridge mode).
- **12 live doc resources**: MCP Resources fetch current pages from docs.litmus.io on demand, so the LLM never works from stale training data.
- **Slash commands** for the most common one-shot queries:
  - `/litmus-status` -- identity + device count + cloud activation
  - `/litmus-devices` -- device table
  - `/litmus-drivers` -- protocol drivers (active vs stopped)
  - `/litmus-tags <device>` -- tags for a device
  - `/litmus-containers` -- Docker containers on the Edge
  - `/litmus-events [N]` -- recent system events
  - `/litmus-network` -- network interface summary
  - `/litmus-lem-fleet` -- LEM project fleet overview
  - `/litmus-lem-licenses [days]` -- expired and soon-to-expire licenses
- **Skills** for multi-step diagnostic workflows:
  - `litmus-troubleshoot` -- root-cause analysis when a device is offline, stale, or returning bad values
  - `litmus-lem-audit` -- fleet-wide LEM project health audit (alerts, license risk, version spread)
- **`litmus-expert` subagent** for grounded questions about Litmus Edge concepts and API behavior, using live docs rather than training data.

## Install

### Claude Code

```
/plugin marketplace add litmusautomation/litmus-mcp-plugin
/plugin install litmus-mcp@litmus-plugins
```

On install, Claude Code prompts for your Litmus Edge URL, OAuth client ID/secret, and optional NATS/InfluxDB settings. Sensitive values go to the system keychain.

### Codex (CLI)

1. Add the marketplace and install the plugin:

   ```bash
   codex plugin marketplace add litmusautomation/litmus-mcp-plugin
   codex plugin add litmus-mcp@litmus-plugins
   ```

2. Create your credentials file. Codex has no in-app UI for plugin MCP credentials, so the plugin's MCP server loads them from a known path on every launch:

   ```bash
   mkdir -p ~/.config/litmus-mcp
   cp scripts/config.env.example ~/.config/litmus-mcp/env
   chmod 600 ~/.config/litmus-mcp/env
   ${EDITOR:-nano} ~/.config/litmus-mcp/env
   ```

   Fill in at minimum `EDGE_URL`, `EDGE_API_CLIENT_ID`, and `EDGE_API_CLIENT_SECRET`. NATS, InfluxDB, and LEM blocks are optional.

3. Open a new Codex thread. Run `/mcp` to confirm `litmus-edge` is listed with tools populated.

To override the credentials path, set `LITMUS_MCP_ENV_FILE` in your shell before launching Codex.

## Prerequisites

- Python 3.12 or newer on `PATH`
- Network access from your machine to your Litmus Edge instance
- An OAuth client (ID + secret) created in your Edge admin console

On first launch the MCP server's wrapper script creates a venv and installs the Python dependencies listed in `requirements.txt`. The venv lives at `${*_PLUGIN_DATA}/venv` when a plugin data dir is provided by the host, otherwise at `~/.cache/litmus-mcp/venv`. Bootstrapping runs once per `requirements.txt` change, not every session.

## Layout

```
litmus-mcp-plugin/
  .claude-plugin/                Claude Code manifest + marketplace
  mcp/claude.mcp.json            Claude MCP server config
  hooks/claude.hooks.json        Claude SessionStart hook config
  .agents/plugins/               Codex marketplace
  plugins/litmus-mcp/            Codex plugin (symlinks shared dirs back to repo root)
    .codex-plugin/plugin.json    Codex manifest
    .mcp.json                    Codex MCP server config
  scripts/                       install-deps, run-server wrapper, sync-from-server
  skills/                        litmus-troubleshoot workflow
  agents/                        litmus-expert specialist subagent
  commands/                      slash-command shortcuts (/litmus-status, /litmus-devices)
  src/                           MCP server source (synced from litmus-mcp-server)
  requirements.txt               Python deps installed at first launch
```

Both hosts share the same MCP server code; only the manifest shape and config-file naming differ.

## Source sync

The MCP server code in `src/` mirrors [litmus-mcp-server](https://github.com/litmusautomation/litmus-mcp-server) with the web-client files removed. Upstream already supports stdio transport (via `ENABLE_STDIO=true`), so no code patching is required. To refresh:

```bash
./scripts/sync-from-server.sh ../litmus-mcp-server
```

## Releasing

1. Bump `version` in both `.claude-plugin/plugin.json` and `plugins/litmus-mcp/.codex-plugin/plugin.json` (keep them in sync).
2. Update `CHANGELOG.md`.
3. Tag and push: `git tag v0.1.0 && git push --tags`.
4. Users get the update on their next `/plugin marketplace update` (Claude Code) or `codex plugin marketplace upgrade` (Codex).

## Validate before push

```bash
claude plugin validate . --strict
codex plugin marketplace add .
```

## License

Apache-2.0. See `LICENSE`.
