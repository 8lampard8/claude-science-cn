#!/usr/bin/env bash
set -euo pipefail

# Convenience launcher for Claude Science + API Bridge (any provider).
# Auto-detects sandbox capability: uses real sandbox if bwrap ≥0.8 + socat are
# available, falls back to --dangerously-no-sandbox otherwise.
# Usage: ~/claude-science-api-bridge/cs-start.sh

BRIDGE_DIR="$(cd "$(dirname "$0")" && pwd)"
CS_BIN="$HOME/.local/bin/claude-science"
PROXY_PORT=9876
PROXY_HTTPS_PORT=9877
CS_PORT=8765
VENV_PY="$BRIDGE_DIR/.venv/bin/python"

echo "==> [1/5] Starting API Bridge (systemd user service)..."
systemctl --user start claude-science-api-bridge.service 2>/dev/null || true
sleep 1
if curl -fsS --max-time 5 "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
  echo "    Bridge healthy on port $PROXY_PORT"
else
  echo "    WARNING: bridge not healthy. Check: journalctl --user -u claude-science-api-bridge.service"
fi

echo "==> [2/5] Ensuring OAuth auth patch on claude-science binary..."
if ! strings "$CS_BIN" 2>/dev/null | grep -q "http://127.1:$PROXY_PORT"; then
  echo "    Patch missing (binary may have updated). Re-applying..."
  PYTHON="$VENV_PY" PROXY_PORT="$PROXY_PORT" PROXY_HTTPS_PORT="$PROXY_HTTPS_PORT" \
    bash "$BRIDGE_DIR/scripts/patch-daemon-auth.sh" "$CS_BIN" || true
else
  echo "    Patch already present."
fi

echo "==> [3/5] Refreshing fake OAuth token..."
[ -f "$HOME/.claude-science/encryption.key" ] && "$VENV_PY" "$BRIDGE_DIR/setup-token.py" >/dev/null 2>&1 && echo "    Token refreshed." || echo "    Skipped (no encryption.key yet)."

echo "==> [4/5] Detecting sandbox capability..."
# Claude Science needs bwrap ≥0.8 (for --disable-userns) + socat.
# Install both without sudo: conda install -c conda-forge bubblewrap socat
if bwrap --unshare-user --disable-userns --dev-bind / / -- true >/dev/null 2>&1 && command -v socat >/dev/null 2>&1; then
  SANDBOX_FLAG=""
  echo "    Sandbox: ENABLED (bwrap $(bwrap --version 2>&1), socat $(command -v socat))"
else
  SANDBOX_FLAG="--dangerously-no-sandbox"
  echo "    Sandbox: DISABLED — bwrap<0.8 or socat missing."
  echo "    Fix (no sudo): conda install -c conda-forge bubblewrap socat -y"
fi

echo "==> [5/5] Starting Claude Science..."
export ANTHROPIC_BASE_URL="http://127.0.0.1:$PROXY_PORT"
if "$CS_BIN" status 2>/dev/null | grep -q '"running": true'; then
  echo "    Claude Science already running."
else
  "$CS_BIN" serve --port "$CS_PORT" --no-browser --no-auto-update $SANDBOX_FLAG --detached
  sleep 5
fi

echo
echo "============================================================"
echo "  Claude Science is running. Open this URL in your browser:"
echo
URL="$("$CS_BIN" url)"
echo "  $URL"
echo
echo "  Click 'Sign in' once (one-time nonce)."
[ -z "$SANDBOX_FLAG" ] && echo "  Sandbox: ON (code runs isolated)" || echo "  Sandbox: OFF (code has full \$HOME access)"
echo "  Stop: $CS_BIN stop"
echo "============================================================"
