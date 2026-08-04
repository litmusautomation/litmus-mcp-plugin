#!/usr/bin/env bash
# Vendors the MCP server source from the upstream litmus-mcp-server repo into
# this plugin's src/ directory, then records which upstream version was taken.
#
# Usage:
#   ./scripts/sync-from-server.sh [path-to-litmus-mcp-server]
#
# Defaults to ../litmus-mcp-server if no path is given.
#
# What is copied: src/ (server.py, config.py, tools/, utils/) plus static/icon.png.
#
# What is excluded, and why:
#   web_client.py, conversation.py  - the web UI. Claude Code / Codex replace it.
#   client_utils.py, env_config.py  - support code for that web UI only. Nothing
#                                     under tools/, utils/, config.py or
#                                     server.py imports them.
#
# server.py IS synced. It used to be excluded because the plugin carried a local
# patch extending StdioRequestContext with the LEM and certificate-validation
# env vars; that patch is now upstream, so there is no local fork left to
# protect. Do not re-add an exclude without also updating
# scripts/check-source-drift.sh, which asserts these two trees match.

set -euo pipefail

SOURCE_REPO="${1:-../litmus-mcp-server}"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$SOURCE_REPO/src" ]]; then
  echo "Source repo not found at $SOURCE_REPO. Pass the path as the first arg." >&2
  exit 1
fi

SOURCE_REPO="$(cd "$SOURCE_REPO" && pwd)"

rsync -a --delete \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='.DS_Store' \
  --exclude='web_client.py' \
  --exclude='conversation.py' \
  --exclude='client_utils.py' \
  --exclude='env_config.py' \
  "$SOURCE_REPO/src/" "$PLUGIN_ROOT/src/"

# server.py advertises a brand icon read from ../static/icon.png relative to
# src/. Without it the initialize response just omits icons, so this is cosmetic
# but cheap to keep correct.
mkdir -p "$PLUGIN_ROOT/static"
cp "$SOURCE_REPO/static/icon.png" "$PLUGIN_ROOT/static/icon.png"

# Record the upstream version. config.py's server_version() reads
# ../pyproject.toml relative to src/, which is why this file exists at the
# plugin root at all - it is the pin record, not a build definition.
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$SOURCE_REPO/pyproject.toml" | head -1)"
REF="$(git -C "$SOURCE_REPO" describe --tags --always 2>/dev/null || echo unknown)"
COMMIT="$(git -C "$SOURCE_REPO" rev-parse HEAD 2>/dev/null || echo unknown)"

cat > "$PLUGIN_ROOT/pyproject.toml" <<EOF
# Pin record for the MCP server source vendored into src/. Written by
# scripts/sync-from-server.sh - edit that script, not this file.
#
# This is NOT a build definition and this repo is not an installable package.
# Runtime dependencies live in requirements.txt and are installed into the
# plugin data dir by scripts/install-deps.sh. Do not "pip install ." here.
#
# It exists because src/config.py's server_version() resolves
# <src>/../pyproject.toml to report the running server version, which
# get_mcp_server_info surfaces for support and triage. That function reads
# [project].version specifically, which is why the table shape is what it is.
#
# Side effect of that shape: uv sees a [project] table and treats this
# directory as a uv project, so "uv run" here will create .venv/ and uv.lock.
# Both are gitignored. requires-python is set so uv does not warn.

[project]
name = "litmus-mcp-plugin"
version = "$VERSION"
requires-python = ">=3.12"

[tool.litmus-mcp-plugin.source]
repository = "https://github.com/litmusautomation/litmus-mcp-server"
ref = "$REF"
commit = "$COMMIT"
EOF

echo "Synced litmus-mcp-server $VERSION ($REF) into src/."
echo "Verify with: ./scripts/check-source-drift.sh $SOURCE_REPO"
