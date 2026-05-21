<p align="center">
  <a href="https://litmus.io">
    <picture>
      <source media="(prefers-color-scheme: light)" srcset="static/litmus-logo-light.svg" />
      <source media="(prefers-color-scheme: dark)" srcset="static/litmus-logo-dark.svg" />
      <img src="static/litmus-logo-light.svg" height="60" alt="Litmus logo" />
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

- **Devices and tags**: list devices, read tag values, manage drivers
- **Live telemetry**: subscribe to single or multiple NATS topics
- **Historical data**: query InfluxDB time series
- **Digital Twins**: models, instances, attributes, hierarchy
- **Marketplace**: list and run Docker containers on the Edge
- **Live docs**: MCP Resources fetch current pages from docs.litmus.io on demand
- **Skills + agents**: troubleshoot workflows and a `litmus-expert` subagent that knows the docs

## Install

### Claude Code

```
/plugin marketplace add litmusautomation/litmus-mcp-plugin
/plugin install litmus-mcp@litmus-plugins
```

On install, Claude Code prompts for your Litmus Edge URL, OAuth client ID/secret, and optional NATS/InfluxDB settings. Sensitive values go to the system keychain.

### Codex (CLI)

```
codex plugin marketplace add litmusautomation/litmus-mcp-plugin
```

Then enable `litmus-mcp@litmus-plugins` from the Codex Plugins UI. Codex doesn't yet support inline credential prompts, so set these in your shell (or in `~/.codex/config.toml`) before launching Codex:

```bash
export EDGE_URL=https://edge.example.com
export EDGE_API_CLIENT_ID=...
export EDGE_API_CLIENT_SECRET=...
# optional:
export NATS_SOURCE=localhost
export INFLUX_HOST=localhost
```

## Prerequisites

- Python 3.12 or newer on `PATH`
- Network access from your machine to your Litmus Edge instance
- An OAuth client (ID + secret) created in your Edge admin console

On first session the plugin's `SessionStart` hook creates a venv at `${*_PLUGIN_DATA}/venv` and installs the Python dependencies listed in `requirements.txt`. This runs once per `requirements.txt` change, not every session.

## Layout

```
litmus-mcp-plugin/
  .claude-plugin/       Claude Code manifest + marketplace
  .codex-plugin/        Codex manifest
  .agents/plugins/      Codex marketplace
  mcp/                  MCP server config (one per host)
  hooks/                SessionStart hook config (one per host)
  scripts/              install-deps and sync-from-server helpers
  skills/               litmus-troubleshoot workflow
  agents/               litmus-expert specialist subagent
  commands/             slash-command shortcuts (/litmus-status, /litmus-devices)
  src/                  MCP server source (synced from litmus-mcp-server)
  requirements.txt      Python deps installed at first SessionStart
```

The two manifests intentionally point at different MCP and hook files because Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` while Codex uses `${PLUGIN_ROOT}`. Same scripts, two thin wrappers.

## Source sync

The MCP server code in `src/` mirrors [litmus-mcp-server](https://github.com/litmusautomation/litmus-mcp-server) with the web-client files removed. Upstream already supports stdio transport (via `ENABLE_STDIO=true`), so no code patching is required. To refresh:

```bash
./scripts/sync-from-server.sh ../litmus-mcp-server
```

## Releasing

1. Bump `version` in both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (keep them in sync).
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
