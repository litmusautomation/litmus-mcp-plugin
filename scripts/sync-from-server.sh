#!/usr/bin/env bash
# Copies the MCP server source from the upstream litmus-mcp-server repo
# into this plugin's src/ directory. Run from the plugin repo root.
#
# Usage:
#   ./scripts/sync-from-server.sh [path-to-litmus-mcp-server]
#
# Defaults to ../litmus-mcp-server if no path is given.
#
# What gets copied: src/ only. The web client (web_client.py, templates/,
# static/, conversation.py) is intentionally excluded - Claude Code replaces it.

set -euo pipefail

SOURCE_REPO="${1:-../litmus-mcp-server}"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$SOURCE_REPO/src" ]]; then
  echo "Source repo not found at $SOURCE_REPO. Pass the path as the first arg." >&2
  exit 1
fi

rsync -av --delete \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='web_client.py' \
  --exclude='conversation.py' \
  --exclude='client_utils.py' \
  --exclude='web_utils.py' \
  --exclude='env_config.py' \
  --exclude='server.py' \
  "$SOURCE_REPO/src/" "$PLUGIN_ROOT/src/"

# server.py is excluded from sync because the plugin carries a small local
# patch: StdioRequestContext is extended to populate LEM and certificate-
# validation env vars (EDGE_MANAGER_*, EDGE_API_TOKEN, VALIDATE_CERTIFICATE,
# NATS_TOKEN). Once that change is merged upstream, drop the exclude.
echo "Synced. server.py is intentionally not overwritten — see src/README.md."
