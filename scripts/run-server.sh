#!/usr/bin/env bash
# Wrapper the plugin host invokes as the MCP server "command".
#
# Resolves the plugin's root and data dirs, bootstraps the Python venv on
# first launch (idempotent), then exec's server.py through the venv python.
#
# Env vars set by the host:
#   CLAUDE_PLUGIN_ROOT / CLAUDE_PLUGIN_DATA  (Claude Code)
#   PLUGIN_ROOT / PLUGIN_DATA                (Codex; also Claude-compat aliases)
# If neither is set, falls back to a script-relative root and XDG cache for data.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}}"
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/litmus-mcp}}"

# Load credentials from the user's config file if present. Codex has no UI for
# entering plugin MCP credentials; this file is the single source of truth.
# Claude users get an in-app config UI via userConfig (defined in plugin.json),
# so this file is optional for them.
LITMUS_ENV_FILE="${LITMUS_MCP_ENV_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/litmus-mcp/env}"
if [[ -f "$LITMUS_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$LITMUS_ENV_FILE"
  set +a
fi

"$SCRIPT_DIR/install-deps.sh" "$PLUGIN_ROOT" "$PLUGIN_DATA" >&2

export ENABLE_STDIO=true
exec "$PLUGIN_DATA/venv/bin/python" "$PLUGIN_ROOT/src/server.py" "$@"
