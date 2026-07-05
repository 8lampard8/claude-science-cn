---
name: claude-science-byok
description: "Use when installing Anthropic's Claude Science on a geo-blocked machine (e.g. China) or running it without a Claude account. Downloads the binary from the unblocked downloads.claude.ai CDN, sets up the claude-science-api-bridge local proxy to route requests to ANY OpenAI- or Anthropic-compatible API (Volcengine, DeepSeek, Kimi, Zhipu, OpenAI, local Ollama/vLLM), and applies a no-login patch so no Claude Pro/Max subscription is required."
version: 1.0.0
author: 8lampard8
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [claude-science, byok, api-bridge, geo-block, wsl, volcengine, deepseek]
    related_skills: [hermes-agent, mcp-server-installation]
---

# Claude Science — Bring Your Own Key (no login, any API provider)

## Overview

Claude Science is Anthropic's local AI workbench for scientific research. Two obstacles block users in mainland China (and anyone without a paid Claude plan):

1. **Install blocked:** the official `curl -fsSL https://claude.ai/install-claude-science.sh | sh` is geo-blocked (`claude.ai` → 302 "app unavailable in region").
2. **Login required:** Claude Science demands a Claude Pro/Max/Team OAuth login, unreachable without a subscription and without access to `claude.ai`.

This skill solves both: download the binary directly from the unblocked `downloads.claude.ai` CDN, then run the open-source **claude-science-api-bridge** local proxy that (a) translates Anthropic Messages API ↔ your provider's format and (b) fakes a local login so no Claude account is needed. Works with **any** OpenAI-compatible or Anthropic-compatible endpoint — not limited to any one provider.

```
Claude Science → local bridge (127.0.0.1:9876) → your LLM API
      ↑                    ↑
  thinks it's logged in   translates Anthropic↔OpenAI, or passes through Anthropic-native
  (fake token + patch)    (Volcengine / DeepSeek / Kimi / Zhipu / OpenAI / local)
```

## When to Use

- User wants to install/run Claude Science in China or behind a `claude.ai` geo-block.
- User has no Claude Pro/Max subscription and wants to power Claude Science with their own API key.
- User wants to swap Claude Science's backend to a cheaper/different model (DeepSeek, GLM, Kimi, local, etc.).
- Don't use for: vanilla Claude Code CLI (use `npm install -g @anthropic-ai/claude-code` + `ANTHROPIC_BASE_URL` instead — no patch needed).

## Prerequisites

- Linux x64, or Windows WSL 2 (Ubuntu 24.04+ preferred for the sandbox; 20.04 works with `--dangerously-no-sandbox`).
- `curl`, `git`, `python3` (3.9+).
- An API key + base URL for any compatible provider (see `references/providers.md`).
- ~5 GB disk for the Claude Science runtime.

## Step 1 — Install Claude Science binary (bypass geo-block)

`claude.ai` is geo-blocked, but the binary CDN `downloads.claude.ai` (Google Cloud Storage) is **not**. Download directly and verify the SHA256 against the manifest:

```bash
# Use the bundled installer script (downloads + checksum-verifies + installs):
bash scripts/install-claude-science.sh
# Or manually:
curl -fsSL https://downloads.claude.ai/claude-science/latest/manifest.json   # version + sha256
curl -fSL https://downloads.claude.ai/claude-science/latest/linux-x64 \
  -o ~/.local/bin/claude-science && chmod +x ~/.local/bin/claude-science
sha256sum ~/.local/bin/claude-science   # must match manifest.json sha256.linux-x64
claude-science --version                 # expect 0.1.x
```

macOS: download the `.dmg` from `https://claude.com/product/claude-science` (that page is NOT geo-blocked).

## Step 2 — Install the API bridge (no sudo)

```bash
git clone https://github.com/Jyx0208/claude-science-api-bridge.git ~/claude-science-api-bridge
cd ~/claude-science-api-bridge
```

Configure with your provider via env vars. **Two modes** — pick based on what your provider offers:

- `anthropic` mode (BEST — native passthrough, preserves tool calls/thinking/SSE): use when the provider has an Anthropic Messages endpoint.
- `openai` mode (widest compatibility): use when the provider only has an OpenAI `/v1/chat/completions` endpoint.

```bash
# EXAMPLE — replace KEY, BASE_URL, MODEL with your provider's values.
# See references/providers.md for ready-made configs for Volcengine/DeepSeek/Kimi/Zhipu/OpenAI/Ollama.
CUSTOM_API_KEY="YOUR_KEY" \
CUSTOM_BASE_URL="https://your-provider-endpoint" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="your-model-name" \
MODEL_LIST_MODE="aliases" \
MODEL_MENU_STRATEGY="claude_compatible" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"My Model","backend":"custom","model":"your-model-name"}]' \
INLINE_IMAGE_POLICY="auto" \
PROXY_PORT="9876" \
./scripts/install-safe.sh
```

`install-safe.sh` creates a `.venv`, installs deps, writes `config.json`, and registers a systemd `--user` service (auto-start). Dashboard: `http://127.0.0.1:9876/dashboard`.

> **Port must be 4 digits** (e.g. 9876). The no-login patch uses byte-length-preserving URL replacement; 5-digit ports break it.

## Step 3 — First launch + generate no-login credentials

Three sub-steps: create the data dir, forge an OAuth token, patch the binary.

### 3a. First launch (creates `~/.claude-science/encryption.key`)

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:9876 \
  claude-science serve --port 8765 --no-browser --no-auto-update --dangerously-no-sandbox
# Wait ~5s, then Ctrl-C. (—dangerously-no-sandbox only needed if bubblewrap < 0.8.0; see Pitfalls.)
```

### 3b. Forge the OAuth token (expires 2099, no refresh needed)

```bash
~/claude-science-api-bridge/.venv/bin/python ~/claude-science-api-bridge/setup-token.py
# Creates ~/.claude-science/.oauth-tokens/byok-user-*.enc
```

### 3c. Patch the binary (redirect claude.ai auth → local bridge)

Claude Science hardcodes `claude.ai`/`api.anthropic.com` for login validation. The patch rewrites those URLs in the binary to point at the local bridge (which returns fake "logged-in" data):

```bash
cd ~/claude-science-api-bridge
PYTHON=.venv/bin/python PROXY_PORT=9876 PROXY_HTTPS_PORT=9877 \
  ./scripts/patch-daemon-auth.sh ~/.local/bin/claude-science
# Expect: "Patched N OAuth URL occurrence(s)" + "executable check passed"
```

Backup is saved as `.byok-auth-original`. **Re-apply after every Claude Science update** (updates replace the binary). The bundled `scripts/cs-start.sh` auto-detects and re-applies.

## Step 4 — Start and use

```bash
# One-click (checks bridge, re-patches if needed, refreshes token, starts CS):
bash ~/claude-science-api-bridge/cs-start.sh
# Or directly:
ANTHROPIC_BASE_URL=http://127.0.0.1:9876 \
  claude-science serve --port 8765 --no-browser --no-auto-update \
  --dangerously-no-sandbox --detached

claude-science url    # → http://localhost:8765/?nonce=...
```

Open the URL in a browser (WSL: localhost auto-forwards to Windows). Click **"Sign in"** — this is a one-time nonce confirmation, **no account/password needed**. The app loads; all chat/code runs through your configured API.

### Auto-start (systemd, optional)

```bash
cat > ~/.config/systemd/user/claude-science.service <<'EOF'
[Unit]
Description=Claude Science (BYOK)
After=claude-science-api-bridge.service
Requires=claude-science-api-bridge.service
[Service]
Type=simple
ExecStart=%h/.local/bin/claude-science serve --port 8765 --no-browser --no-auto-update --dangerously-no-sandbox
Environment=ANTHROPIC_BASE_URL=http://127.0.0.1:9876
Restart=on-failure
[Install]
WantedBy=default.target
EOF
systemctl --user daemon-reload && systemctl --user enable --now claude-science.service
```

## Volcengine /v3 URL patch (only for Volcengine Ark in OpenAI mode)

If using Volcengine Ark's OpenAI-compatible endpoint (`.../api/plan/v3`), the bridge's `normalize_openai_base_url()` wrongly appends `/v1` (→ `/v3/v1/...`). Apply the included patch so any `/vN` suffix is preserved:

```bash
cd ~/claude-science-api-bridge
git apply /path/to/patches/volcengine-v3-url-fix.patch
# Or edit proxy.py: in normalize_openai_base_url, replace
#   cleaned.endswith("/v1")  →  ends_with_version_segment(cleaned)
```

(Not needed in `anthropic` mode, or for non-Volcengine providers.)

## Common Pitfalls

1. **bubblewrap too old.** Claude Science's sandbox needs bubblewrap ≥ 0.8.0. Ubuntu 20.04/22.04 ship 0.4.x → `bwrap too old`. Fix: upgrade to Ubuntu 24.04+, or build bubblewrap from source (needs `libcap-dev` + `autoconf` via sudo), or pass `--dangerously-no-sandbox` (code gets full `$HOME` read/write — acceptable for personal use, not production).

2. **Patch lost after update.** `claude-science update` replaces the binary, wiping the auth patch. Re-run `patch-daemon-auth.sh`. `cs-start.sh` auto-detects and re-applies.

3. **Port not 4 digits.** The patch replaces `https://claude.ai` (17 chars) → `http://127.1:9876` (17 chars); 5-digit ports break length matching. Use 9876/9875/etc.

4. **"Sign in" page looks like a login wall.** It's NOT — it's a one-time nonce confirmation. Click the button (POSTs to `/api/auth/nonce`) and you're in. The fake OAuth token + binary patch handle the real auth in the background.

5. **Empty model replies.** Reasoning models (GLM-5.2, DeepSeek-R1) emit `thinking` blocks that consume `max_tokens`. Raise `max_tokens` to 512+.

6. **config.json `proxy_port` mismatch.** If you change the port, update BOTH config.json and the systemd service Environment, or `verify-proxy.sh` hits the wrong port.

7. **Leaking API keys.** `config.json` holds your key (chmod 600). Never screenshot/publish it. The bridge's install output masks secrets ("secrets updated: 1"). For sharing, use placeholder keys only.

8. **WSL path ≠ sandbox path.** A Windows path readable in a WSL shell may be unreadable inside Claude Science's tool sandbox. Copy data into `~/.claude-science/artifacts/` for reliability.

## Verification Checklist

- [ ] `claude-science --version` prints 0.1.x
- [ ] `curl -sS http://127.0.0.1:9876/health` → `"status":"ok"`, `custom_configured:true`
- [ ] `~/claude-science-api-bridge/.venv/bin/python ~/claude-science-api-bridge/setup-token.py` → "Encrypted OAuth token successfully"
- [ ] `patch-daemon-auth.sh` → "Patched N OAuth URL occurrence(s)" + "executable check passed"
- [ ] `curl -sS http://127.0.0.1:9876/v1/messages -H 'content-type: application/json' -d '{"model":"claude-sonnet-4-5","max_tokens":256,"messages":[{"role":"user","content":"Say OK"}]}'` → 200 + valid Anthropic response
- [ ] `PYTHON=.venv/bin/python PROXY_PORT=9876 ./scripts/verify-proxy.sh` → "proxy verification passed"
- [ ] Browser opens nonce URL → click "Sign in" → app loads (title "Claude Science", account "byok@localhost")

## Files in this skill

- `scripts/install-claude-science.sh` — download + SHA256-verify + install the binary
- `scripts/cs-start.sh` — one-click launcher (bridge check, patch re-apply, token refresh, start)
- `references/providers.md` — ready-made configs for Volcengine / DeepSeek / Kimi / Zhipu / OpenAI / Ollama / vLLM
- `patches/volcengine-v3-url-fix.patch` — fix /v3 URL normalization for Volcengine OpenAI mode
