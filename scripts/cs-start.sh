#!/usr/bin/env bash
set -euo pipefail

# Convenience launcher for Claude Science + API Bridge (Volcengine GLM-5.2) on WSL
# Usage: ~/claude-science-api-bridge/cs-start.sh

BRIDGE_DIR="$(cd "$(dirname "$0")" && pwd)"
CS_BIN="$HOME/.local/bin/claude-science"
PROXY_PORT=9876
PROXY_HTTPS_PORT=9877
CS_PORT=8765
VENV_PY="$BRIDGE_DIR/.venv/bin/python"

echo "==> [1/4] Starting API Bridge (systemd user service)..."
systemctl --user start claude-science-api-bridge.service 2>/dev/null || true
sleep 1
if curl -fsS --max-time 5 "http://127.0.0.1:$PROXY_PORT/health" >/dev/null 2>&1; then
  echo "    Bridge healthy on port $PROXY_PORT (GLM-5.2, anthropic native)"
else
  echo "    WARNING: bridge not healthy. Check: journalctl --user -u claude-science-api-bridge.service"
fi

echo "==> [2/4] Ensuring OAuth auth patch on claude-science binary..."
# Re-apply patch if the binary no longer contains patched URLs (e.g. after an update)
if ! strings "$CS_BIN" 2>/dev/null | grep -q "http://127.1:$PROXY_PORT"; then
  echo "    Patch missing (binary may have updated). Re-applying..."
  PYTHON="$VENV_PY" PROXY_PORT="$PROXY_PORT" PROXY_HTTPS_PORT="$PROXY_HTTPS_PORT" \
    bash "$BRIDGE_DIR/scripts/patch-daemon-auth.sh" "$CS_BIN" || true
else
  echo "    Patch already present."
fi

echo "==> [3/4] Refreshing fake OAuth token..."
[ -f "$HOME/.claude-science/encryption.key" ] && "$VENV_PY" "$BRIDGE_DIR/setup-token.py" >/dev/null 2>&1 && echo "    Token refreshed." || echo "    Skipped (no encryption.key yet)."

echo "==> [4/4] Starting Claude Science..."
export ANTHROPIC_BASE_URL="http://127.0.0.1:$PROXY_PORT"
# --dangerously-no-sandbox: Ubuntu 20.04 bubblewrap 0.4.0 is too old (needs 0.8+).
#   Upgrade to Ubuntu 24.04+ or build bubblewrap 0.8+ to drop this flag.
if "$CS_BIN" status 2>/dev/null | grep -q '"running": true'; then
  echo "    Claude Science already running."
else
  "$CS_BIN" serve --port "$CS_PORT" --no-browser --no-auto-update --dangerously-no-sandbox --detached
  sleep 5
fi

echo
echo "============================================================"
echo "  Claude Science is running. Open this URL in your browser:"
echo
URL="$("$CS_BIN" url)"
echo "  $URL"
echo
echo "  Click 'Sign in' once (one-time nonce). Backend: GLM-5.2 via Volcengine."
echo "  Stop: $CS_BIN stop"
echo "============================================================"
