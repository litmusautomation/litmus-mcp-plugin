#!/usr/bin/env bash
# Installs Python dependencies for the Litmus MCP plugin into the
# persistent ${*_PLUGIN_DATA} directory. Re-runs only when requirements.txt
# changes, so SessionStart latency is near-zero on warm starts.
#
# Args:
#   $1 - plugin root (where requirements.txt lives)
#   $2 - plugin data dir (where the venv is created, persists across updates)

set -euo pipefail

PLUGIN_ROOT="${1:?plugin root required}"
PLUGIN_DATA="${2:?plugin data dir required}"

REQ_SRC="$PLUGIN_ROOT/requirements.txt"
REQ_CACHE="$PLUGIN_DATA/requirements.txt"
VENV="$PLUGIN_DATA/venv"

mkdir -p "$PLUGIN_DATA"

# Skip if the venv exists and requirements haven't changed
if [[ -x "$VENV/bin/python" ]] && diff -q "$REQ_SRC" "$REQ_CACHE" >/dev/null 2>&1; then
  exit 0
fi

# Pick Python 3.12 or newer
PY=""
for candidate in "${PYTHON:-}" python3.13 python3.12 python3; do
  [[ -z "$candidate" ]] && continue
  if command -v "$candidate" >/dev/null 2>&1 \
     && "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" 2>/dev/null; then
    PY="$candidate"
    break
  fi
done

if [[ -z "$PY" ]]; then
  echo "litmus-mcp plugin: Python 3.12+ required but not found on PATH." >&2
  echo "  Ubuntu/Debian:  sudo apt install python3.12 python3.12-venv" >&2
  echo "  macOS:          brew install python@3.12" >&2
  echo "  Or set PYTHON=/path/to/python3.12 before launching Claude Code." >&2
  exit 1
fi

# Rebuild venv from scratch so partial / wrong-version state can't linger
rm -rf "$VENV"
"$PY" -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip --quiet
"$VENV/bin/pip" install -r "$REQ_SRC" --quiet

cp "$REQ_SRC" "$REQ_CACHE"
