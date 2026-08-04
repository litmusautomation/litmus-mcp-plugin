#!/usr/bin/env bash
# Fails when the vendored src/ tree has drifted from upstream litmus-mcp-server.
#
# This exists because the plugin ships a copy of the server rather than
# depending on it, so drift is otherwise invisible: the plugin keeps starting
# fine while quietly missing tools and bug fixes. It has happened - the
# vendored tree once fell ~2,000 lines behind, which dropped list_nats_topics,
# get_mcp_server_info, and the checksum-verified litmus-cli self-install that
# the litmus_sdk_* tools depend on.
#
# Usage:
#   ./scripts/check-source-drift.sh [path-to-litmus-mcp-server]
#
# Exit codes:
#   0 - in sync
#   1 - drifted (diff printed)
#   2 - cannot check (upstream checkout not available)
#
# This is deliberately NOT run in CI. It needs an upstream checkout, and the
# plugin is a deliberate pin, so being behind upstream is a normal state rather
# than a build failure. Run it by hand when syncing and before tagging a
# release; the README release checklist lists it as the first step.
#
# CI (.github/workflows/audit.yml) covers the offline half instead: that every
# tool name in commands/, skills/, and agents/ exists in the vendored src/, and
# that every documented litmus-cli command exists in the binary.

set -uo pipefail

SOURCE_REPO="${1:-../litmus-mcp-server}"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$SOURCE_REPO/src" ]]; then
  echo "SKIP: no upstream checkout at $SOURCE_REPO." >&2
  echo "      Pass the path as the first arg, or clone litmus-mcp-server next to this repo." >&2
  exit 2
fi

SOURCE_REPO="$(cd "$SOURCE_REPO" && pwd)"

# Keep this exclude list identical to sync-from-server.sh, or the check will
# report drift on files the sync deliberately never copies.
EXCLUDES=(
  --exclude='__pycache__'
  --exclude='*.pyc'
  --exclude='.DS_Store'
  --exclude='web_client.py'
  --exclude='conversation.py'
  --exclude='client_utils.py'
  --exclude='env_config.py'
)

# Compare by content, not metadata. rsync --itemize-changes would be the
# obvious tool here, but -a implies -t, so a fresh git clone (which stamps
# checkout-time mtimes on everything) reports every file as changed and the
# check fails permanently in CI. diff -r only cares about bytes.
CHANGES="$(diff -r --brief "${EXCLUDES[@]}" \
  "$SOURCE_REPO/src/" "$PLUGIN_ROOT/src/" 2>&1 || true)"

PINNED_VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$PLUGIN_ROOT/pyproject.toml" 2>/dev/null | head -1)"
UPSTREAM_VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$SOURCE_REPO/pyproject.toml" | head -1)"

STATUS=0

if [[ -n "$CHANGES" ]]; then
  echo "DRIFT: vendored src/ differs from upstream litmus-mcp-server."
  echo
  echo "$CHANGES"
  echo
  STATUS=1
fi

if [[ "$PINNED_VERSION" != "$UPSTREAM_VERSION" ]]; then
  echo "DRIFT: pinned version ${PINNED_VERSION:-<none>} != upstream $UPSTREAM_VERSION."
  echo
  STATUS=1
fi

# A missing tool is the drift that actually costs users something, so name the
# tools rather than only pointing at file diffs.
tool_names() {
  grep -rhoE '"name": "[a-z_]+"' "$1"/tools/*.py 2>/dev/null |
    sed 's/.*: "//;s/"//' | sort -u
}
MISSING="$(comm -13 <(tool_names "$PLUGIN_ROOT/src") <(tool_names "$SOURCE_REPO/src"))"
EXTRA="$(comm -23 <(tool_names "$PLUGIN_ROOT/src") <(tool_names "$SOURCE_REPO/src"))"

if [[ -n "$MISSING" ]]; then
  echo "Tools present upstream but MISSING from the plugin:"
  echo "$MISSING" | sed 's/^/  - /'
  echo
  STATUS=1
fi

if [[ -n "$EXTRA" ]]; then
  echo "Tools in the plugin that no longer exist upstream:"
  echo "$EXTRA" | sed 's/^/  - /'
  echo
  STATUS=1
fi

if [[ "$STATUS" -ne 0 ]]; then
  echo "Fix with: ./scripts/sync-from-server.sh $SOURCE_REPO"
  echo "Then re-check the prompt-side assets (commands/, skills/, agents/, README)"
  echo "against the new tool surface - they name tools explicitly and go stale too."
  exit 1
fi

echo "In sync with litmus-mcp-server $UPSTREAM_VERSION."
