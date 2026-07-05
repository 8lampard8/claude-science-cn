# Supported API Providers

Claude Science (via the bridge) works with **any** OpenAI-compatible or Anthropic-compatible endpoint. Pick the mode based on what your provider offers:

- **`anthropic` mode** — provider has a native Anthropic Messages endpoint (`/v1/messages`). Best fidelity: tool calls, thinking blocks, and SSE streaming pass through untranslated. Prefer this when available.
- **`openai` mode** — provider only has OpenAI Chat Completions (`/v1/chat/completions`). Widest compatibility; the bridge translates Anthropic ↔ OpenAI.

## Ready-made configs

Replace `***` with your API key. Set these as env vars before running `./scripts/install-safe.sh`.

### Volcengine Ark (火山引擎方舟) — anthropic mode
Has both protocols. The Anthropic-native endpoint gives best results.
```bash
CUSTOM_API_KEY=*** \
CUSTOM_BASE_URL="https://ark.cn-beijing.volces.com/api/plan" \
CUSTOM_UPSTREAM_MODE="anthropic" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="glm-5.2" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"GLM-5.2","backend":"custom","model":"glm-5.2"}]' \
PROXY_PORT="9876" ./scripts/install-safe.sh
```
> If using the OpenAI endpoint (`.../api/plan/v3`) instead, apply `patches/volcengine-v3-url-fix.patch` first (the bridge otherwise appends `/v1`).

### DeepSeek — openai mode (or anthropic)
```bash
CUSTOM_API_KEY=*** \
CUSTOM_BASE_URL="https://api.deepseek.com" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="deepseek-chat" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"DeepSeek","backend":"custom","model":"deepseek-chat"}]' \
PROXY_PORT="9876" ./scripts/install-safe.sh
```
DeepSeek also offers a native Anthropic endpoint at `https://api.deepseek.com/anthropic` — use `CUSTOM_UPSTREAM_MODE="anthropic"` with that base URL for better fidelity.

### Zhipu / z.ai (智谱) — openai mode
```bash
CUSTOM_API_KEY=*** \
CUSTOM_BASE_URL="https://api.z.ai/api/paas/v4" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="glm-4.6" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"GLM-4.6","backend":"custom","model":"glm-4.6"}]' \
PROXY_PORT="9876" ./scripts/install-safe.sh
```

### SiliconFlow (硅基流动, hosts Kimi/Qwen/GLM) — openai mode
```bash
CUSTOM_API_KEY=*** \
CUSTOM_BASE_URL="https://api.siliconflow.cn" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="Pro/moonshotai/Kimi-K2.6" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"Kimi K2.6","backend":"custom","model":"Pro/moonshotai/Kimi-K2.6"}]' \
INLINE_IMAGE_POLICY="preserve" \
PROXY_PORT="9876" ./scripts/install-safe.sh
```

### OpenAI — openai mode
```bash
CUSTOM_API_KEY=*** \
CUSTOM_BASE_URL="https://api.openai.com" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="gpt-4o" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"GPT-4o","backend":"custom","model":"gpt-4o"}]' \
PROXY_PORT="9876" ./scripts/install-safe.sh
```

### Local Ollama — openai mode
```bash
CUSTOM_API_KEY="ollama" \
CUSTOM_BASE_URL="http://127.0.0.1:11434/v1" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="qwen2.5" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"Qwen2.5 (local)","backend":"custom","model":"qwen2.5"}]' \
PROXY_PORT="9876" ./scripts/install-safe.sh
```

### Local vLLM — openai mode
```bash
CUSTOM_API_KEY="vllm" \
CUSTOM_BASE_URL="http://127.0.0.1:8000/v1" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="your-model" \
PROXY_PORT="9876" ./scripts/install-safe.sh
```

### Any OneAPI / NewAPI relay — openai mode
Point `CUSTOM_BASE_URL` at your relay address (e.g. `https://your-relay.com/v1`), set `FORCE_MODEL` to whatever model ID the relay accepts.

## How model mapping works

Claude Science always sends Claude model names (`claude-sonnet-4-5`, `claude-opus-4-8`, etc.). The bridge maps them to your backend model:

1. **`model_aliases`** — explicit map: a Claude-facing ID → your real model. Highest priority.
2. **`force_model`** — the fallback for any model not in aliases. Set this to your default model so everything routes correctly.
3. The response's `model` field keeps the Claude-facing name (so Claude Science is happy), while the backend gets your real model name.

## Image input

- `inline_image_policy="preserve"` — keep images for vision-capable models (GPT-4o, Kimi-K2.6, GLM with vision).
- `inline_image_policy="omit"` — strip images for text-only models.
- `inline_image_policy="auto"` — let the bridge decide.

## Reasoning / thinking

Set `reasoning_content_policy="never"` (default) to hide provider reasoning payloads from Claude Science. Leave `anthropic` mode passthrough to keep native `thinking` blocks visible.
