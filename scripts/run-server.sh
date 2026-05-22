#!/usr/bin/env bash
# Wrapper that the MCP launcher invokes as the server "command".
#
# The MCP server spawns in parallel with SessionStart hooks, so we can't
# rely on install-deps.sh having created the venv before this script runs.
# We ensure the venv exists here (idempotent and near-zero cost on warm
# starts), then exec into the venv python so the MCP stdio handshake
# proceeds against the right interpreter.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${PLUGIN_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}}"
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/litmus-mcp}}"

"$PLUGIN_ROOT/scripts/install-deps.sh" "$PLUGIN_ROOT" "$PLUGIN_DATA" >&2

exec "$PLUGIN_DATA/venv/bin/python" "$@"
