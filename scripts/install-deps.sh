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

# Pick Python 3.12 or newer.
PY=""
for candidate in "${PYTHON:-}" python3.14 python3.13 python3.12 python3; do
  [[ -z "$candidate" ]] && continue
  if command -v "$candidate" >/dev/null 2>&1 \
     && "$candidate" -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)" 2>/dev/null; then
    PY="$candidate"
    break
  fi
done

# Fall back to a uv-managed interpreter. Machines with uv installed very often
# have no versioned python3.1x on PATH at all (uv keeps its toolchains under its
# own data dir), so a PATH-only search reports "Python 3.12+ required" on a box
# that has several. uv is not required to use this plugin, only preferred when
# already present.
if [[ -z "$PY" ]] && command -v uv >/dev/null 2>&1; then
  PY="$(uv python find '>=3.12' 2>/dev/null || true)"
  [[ -x "$PY" ]] || PY=""
fi

if [[ -z "$PY" ]]; then
  echo "litmus-mcp plugin: Python 3.12+ required but none was found." >&2
  echo "  Searched PATH for python3.14, python3.13, python3.12, python3." >&2
  command -v uv >/dev/null 2>&1 \
    && echo "  Also tried 'uv python find >=3.12'; install one with: uv python install 3.12" >&2
  echo "  Ubuntu/Debian:  sudo apt install python3.12 python3.12-venv" >&2
  echo "  macOS:          brew install python@3.12" >&2
  echo "  Or set PYTHON=/path/to/python3.12 before launching your plugin host." >&2
  exit 1
fi

# Rebuild the venv from scratch so partial or wrong-version state cannot linger.
rm -rf "$VENV"

# uv creates the venv and resolves deps substantially faster, which matters here
# because this runs on SessionStart. Fall back to stdlib venv + pip when absent.
if command -v uv >/dev/null 2>&1; then
  uv venv --python "$PY" "$VENV" --quiet
  VIRTUAL_ENV="$VENV" uv pip install -r "$REQ_SRC" --quiet
else
  "$PY" -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip --quiet
  "$VENV/bin/pip" install -r "$REQ_SRC" --quiet
fi

cp "$REQ_SRC" "$REQ_CACHE"
