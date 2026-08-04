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

**62 MCP tools** over DeviceHub (11), System and identity (12), NATS topics (3), DataHub/InfluxDB (6), Digital Twins (9), Applications (2), Litmus Edge Manager (16), and the SDK fallback (3).

**19 live doc resources** (`litmus://docs/...`) fetch current pages from docs.litmus.io on demand, so version-specific answers do not come from training data.

### The access stack

The 62 tools are the curated surface, not the ceiling. Four layers, in escalation order:

1. **Dedicated MCP tools** - cached, validated, formatted. Best for single conversational lookups.
2. **MCP SDK fallback** - `litmus_sdk_discover` browses ~550 SDK functions, `litmus_sdk_read` runs read-only ones, `litmus_sdk_write` runs state-changing ones behind a per-call approval gate. Covers what has no dedicated tool: device connection properties, enable/restart, integrations, flows, OPC, Unify, LEM writes.
3. **`litmus-cli`** - the standalone binary, and upstream's preferred interface for agentic tasks. Same catalog as layer 2, plus curated `le`/`lem` command groups, the `le data` plane, connection profiles for multiple edges, and offline commands. Run it from the shell; JSON out, so it pipes to `jq`.
4. **Raw API** - only for what none of the above reach.

Layers 2 and 3 hit the same binary, so they match in reach and differ in ergonomics: one lookup mid-conversation is layer 2, the same operation across forty devices is layer 3. Some capabilities are first-class **only** at layer 3: Node-RED flows, device users, OPC UA config, analytics processors, integration providers, marketplace images.

One caveat worth stating plainly: **the CLI has no approval gate.** The protection around `litmus_sdk_write` is enforced by the MCP server, not the binary. The `litmus-cli` skill carries that discipline explicitly.

### Slash commands

| Command | What it does |
|---|---|
| `/litmus-status` | Edge identity, device liveness, cloud activation |
| `/litmus-health` | Memory, storage, CPU, event severity counts, failing tags |
| `/litmus-devices [driver]` | Devices joined with real connection state |
| `/litmus-drivers` | Protocol driver catalog available for new devices |
| `/litmus-tags [device]` | Tags with runtime state, fully paged |
| `/litmus-topics [pattern]` | Discover NATS topic subjects |
| `/litmus-twins [name]` | Digital Twin models, instances, attributes |
| `/litmus-containers` | Docker containers on the Edge |
| `/litmus-events [N\|severity]` | Recent system events |
| `/litmus-network [iface]` | Interfaces and firewall rules |
| `/litmus-lem-fleet` | LEM fleet overview with alerts |
| `/litmus-lem-licenses [days]` | Expired and expiring licenses |
| `/litmus-sdk [query]` | Search the ~550-function SDK catalog |
| `/litmus-cli-setup [profile]` | Install, authenticate, and verify `litmus-cli` for shell use |
| `/litmus-watch <topic> [n]` | Sample live DataHub values with a bounded wait |
| `/litmus-version [check]` | MCP server, SDK, and litmus-cli versions |

### Skills

Multi-step workflows that carry the judgment the tool schemas alone do not:

- **`litmus-troubleshoot`** - why a device is offline, stale, or reporting wrong values. Works the four layers (device, driver tag, NATS, InfluxDB) bottom-up to localize the fault, then pins when it broke.
- **`litmus-verify-dataflow`** - traces one data point tag to topic to measurement and reports which hop fails. This is the skill for "live value works but history is empty", and vice versa.
- **`litmus-onboard-device`** - add a device and get it actually publishing: driver, create, connection properties, tags, enable, verify. Creating a device is only step two of six, which is why this exists.
- **`litmus-lem-audit`** - fleet-wide LEM audit: alerts, license risk, real version spread, online counts.
- **`litmus-sdk-fallback`** - how to reach uncovered operations safely, including the write approval gate.
- **`litmus-cli`** - driving the CLI from the shell: profiles and multi-edge work, the `le data` plane, bulk `jq` pipelines, and the write discipline the binary does not enforce for you.

### Subagent

**`litmus-expert`** answers Litmus concept, terminology, and API-behavior questions from the live doc resources rather than training data.

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

- Python 3.12 or newer. The bootstrap looks for `python3.14`, `python3.13`, `python3.12`, then `python3` on `PATH`, and falls back to `uv python find` when `uv` is installed. Override with `PYTHON=/path/to/python3.12`.
- Network access from your machine to your Litmus Edge instance
- An OAuth client (ID + secret) created in your Edge admin console

On first launch the wrapper script creates a venv and installs `requirements.txt`. It uses `uv` when present (noticeably faster, since this runs on SessionStart) and stdlib `venv` plus `pip` otherwise. The venv lives at `${*_PLUGIN_DATA}/venv`, or `~/.cache/litmus-mcp/venv` when the host provides no data dir. It re-runs only when `requirements.txt` changes.

### litmus-cli

Two independent copies, for two different jobs.

The `litmus_sdk_*` MCP tools need one, and nothing has to be installed for them: the server resolves `LITMUS_CLI_PATH`, then `PATH`, then downloads the pinned release (checksum-verified) into `~/.cache/litmus-mcp-server/bin/` on first use. `/litmus-version` shows what resolved.

Using the CLI **yourself** in a shell needs it on `PATH`, which that private copy deliberately is not:

```bash
./scripts/install-cli.sh --check   # installed vs latest
./scripts/install-cli.sh           # download, verify SHA256, install to ~/.local/bin
litmus-cli login                   # browser sign-in, writes ~/.litmus/default.json
litmus-cli le version              # confirm
litmus-cli update                  # self-update thereafter
```

Or run `/litmus-cli-setup`, which does the same and can seed a profile from the credentials the plugin is already configured with. `install-cli.sh` downloads the release asset and verifies it against the release `SHA256SUMS` rather than piping a remote script into a shell; upstream's `install.sh` one-liner is an equivalent alternative.

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
  commands/                      slash commands (see table above)
  skills/                        multi-step workflows
  agents/                        litmus-expert specialist subagent
  scripts/                       install-deps, run-server, install-cli,
                                 sync-from-server, check-source-drift
  src/                           MCP server source, vendored from litmus-mcp-server
  static/icon.png                brand icon the server advertises on initialize
  pyproject.toml                 pin record for the vendored source (not a build file)
  requirements.txt               Python deps installed at first launch
```

### What each host actually loads

Both hosts run the same MCP server from `src/`, so the 62 tools and 19 resources are identical. The prompt-side surfaces are not.

| Surface | Claude Code | Codex |
|---|---|---|
| MCP server (62 tools, 19 resources) | yes | yes |
| Skills (6) | yes | yes |
| Slash commands (16) | yes | **no** |
| `litmus-expert` agent | yes | **no** |
| Dependency bootstrap | `SessionStart` hook | `run-server.sh` on launch |

The Codex plugin manifest schema documents `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `skills`, `mcpServers`, `apps`, `hooks`, and `interface`. There is no `commands` or `agents` field, so those directories cannot be declared and are not loaded. See [Package your plugin](https://developers.openai.com/plugins/build/plugins).

`plugins/litmus-mcp/` still symlinks `commands` and `agents` back to the repo root. They are inert on Codex today, kept so the layout stays uniform and works immediately if Codex adds those surfaces. Do not add `commands` or `agents` keys to the Codex manifest: they are undocumented fields and strict validation may reject them.

Practical effect for Codex users: ask for the workflow in plain language instead of a slash command. The skills carry the same sequences, and skill descriptions are written to trigger on the same phrasing.

## Source sync

`src/` is vendored from [litmus-mcp-server](https://github.com/litmusautomation/litmus-mcp-server), minus the web UI (`web_client.py`, `conversation.py`, `client_utils.py`, `env_config.py`, none of which are imported by `tools/`, `utils/`, `config.py`, or `server.py`). Upstream supports stdio via `ENABLE_STDIO=true`, so no patching is needed.

```bash
./scripts/sync-from-server.sh ../litmus-mcp-server   # refresh + rewrite the pin
./scripts/check-source-drift.sh ../litmus-mcp-server # verify; exits 1 on drift
```

Vendoring means drift is silent: the plugin keeps launching while quietly missing tools and fixes. It has already happened once, when the tree fell ~2,000 lines behind and lost `list_nats_topics`, `get_mcp_server_info`, and the litmus-cli self-install the `litmus_sdk_*` tools depend on. `check-source-drift.sh` compares file contents, compares the pinned version, and diffs the actual tool-name lists.

**Run it by hand, not in CI.** The vendored tree is a deliberate pin, so sitting behind upstream is the normal state between syncs, not a build failure. A CI job that went red every time upstream merged anything would just train everyone to ignore it. Instead it is the first step of the release checklist, and the thing you run when you actually intend to sync.

CI (`.github/workflows/audit.yml`) covers the offline half, which is where the real risk is and which needs no upstream checkout or secrets:

- every tool name in `commands/`, `skills/`, and `agents/` exists in the vendored `src/`
- both plugin manifests are valid JSON and their versions match
- every documented `litmus-cli` command exists in the binary (soft-gated, since it fetches one)

After any sync, re-check `commands/`, `skills/`, `agents/`, and this README against the new tool surface. They name tools explicitly and go stale the same way; the CI tool-name audit catches every backticked name that no longer exists.

## Releasing

1. Check source drift, since CI does not: `./scripts/check-source-drift.sh ../litmus-mcp-server`. Either it is in sync, or sync and re-check the prompt-side assets before continuing.
2. Bump `version` in both `.claude-plugin/plugin.json` and `plugins/litmus-mcp/.codex-plugin/plugin.json` (keep them in sync). This is the plugin version, independent of the vendored server version pinned in `pyproject.toml`.
3. Update `CHANGELOG.md`.
4. Tag and push: `git tag v0.2.0 && git push --tags`.
5. Users get the update on their next `/plugin marketplace update` (Claude Code) or `codex plugin marketplace upgrade` (Codex).

## Validate before push

```bash
./scripts/check-source-drift.sh ../litmus-mcp-server   # not covered by CI
claude plugin validate . --strict
codex plugin marketplace add .
```

## License

Apache-2.0. See `LICENSE`.
