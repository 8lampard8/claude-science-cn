# 国内免登录用上 Claude Science:一份不挑 API 供应商的全流程教程

> 官方安装命令被墙、又没有 Claude 付费账号?这篇教你绕过地理封锁安装 Claude Science,并用任意一家大模型 API(火山引擎、DeepSeek、Kimi、智谱、OpenAI、甚至本地模型)替代官方接口——全程无需登录 Claude 账号。

## 📌 本仓库包含

- **README.md** — 完整图文教程(即下文)
- **scripts/cs-start.sh** — 一键启动脚本(自动检测补丁 / 刷新令牌 / 启动服务)
- **patches/volcengine-v3-url-fix.patch** — 修复代理对火山引擎 `/v3` 端点的 URL 拼接问题
- 上游代理项目:[Jyx0208/claude-science-api-bridge](https://github.com/Jyx0208/claude-science-api-bridge)

> 适用于 Claude Science 0.1.15 + claude-science-api-bridge v0.2.9。不绑定任何一家模型供应商。

## 一、先说清楚:Claude Science 是什么,为什么国内用不了

Claude Science 是 Anthropic 在 2026 年 6 月底推出的"科研工作台":一个装在本地的桌面应用,让 Claude 帮你跑 Python / R / shell 代码、查文献、连科学数据库、生成可复现的图表和报告。对生信画图、数据分析、教程复现这类任务,它比普通聊天窗口好用得多。

但在国内直接用,有两道坎:

1. **装不上**:官方安装命令 `curl -fsSL https://claude.ai/install-claude-science.sh | sh` 从国内访问会跳转到"该地区不可用"页面——`claude.ai` 整个域名被地理封锁了。
2. **登不进**:就算装上了,Claude Science 要求用 Claude Pro / Max / Team 账号登录(OAuth),国内用户既访问不了 claude.ai,很多人也没有付费订阅。

这篇教程一次性解决这两个问题:**绕过封锁直接下载二进制** + **用本地代理 + 免登录补丁**,让 Claude Science 以为你已登录,实际却把请求转发给你自己的 API。

## 二、原理一句话版

```
Claude Science  →  本地代理(127.0.0.1:9876)  →  你自己的大模型 API
        ↑                    ↑
   以为在连官方        实际转发给火山引擎/DeepSeek/Kimi/...
   (靠补丁+假token)    (Anthropic格式↔OpenAI格式自动转换)
```

代理做两件事:一是把 Claude Science 发出的 Anthropic 格式请求,翻译成你的 API 能听懂的格式(OpenAI 或 Anthropic 原生);二是伪造一个本地登录态,让 Claude Science 不去找 claude.ai 验证。

## 三、你需要准备什么

- 一台 Linux 机器,或 Windows 上的 **WSL 2**(推荐 Ubuntu 24.04+;Ubuntu 20.04 也能用,见后文注意事项)
- 任意一家大模型 API 的密钥和地址(下面会列支持的供应商)
- 会复制粘贴终端命令即可

> 本文以 WSL Ubuntu 为例。macOS 流程更简单(官方有一键安装包),可参考代理项目自带文档。

## 四、第一步:安装 Claude Science(绕过封锁)

`claude.ai` 被墙了,但存放二进制的下载 CDN `downloads.claude.ai`(Google Cloud Storage)**没有**被墙。我们直接从 CDN 下载,再校验完整性:

```bash
# 1. 确认 ~/.local/bin 存在并在 PATH 里
mkdir -p ~/.local/bin
grep -q '.local/bin' ~/.profile || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
source ~/.profile

# 2. 下载校验清单(含版本号和 SHA256)
curl -fsSL https://downloads.claude.ai/claude-science/latest/manifest.json

# 3. 下载 Linux 二进制(约 150MB)
curl -fSL https://downloads.claude.ai/claude-science/latest/linux-x64 \
  -o ~/.local/bin/claude-science
chmod +x ~/.local/bin/claude-science

# 4. 校验 SHA256(把下面这串换成 manifest.json 里 linux-x64 的值)
sha256sum ~/.local/bin/claude-science

# 5. 确认可运行
claude-science --version
# 应输出类似:claude-science 0.1.15-...
```

> macOS 用户:直接在 `https://claude.com/product/claude-science` 下载 dmg 安装即可(该页面未被封锁)。

## 五、第二步:安装本地 API 代理

用的是开源项目 **Jyx0208/claude-science-api-bridge**,它专门干上面说的"翻译 + 伪造登录"两件事。

```bash
git clone https://github.com/Jyx0208/claude-science-api-bridge.git \
  ~/claude-science-api-bridge
cd ~/claude-science-api-bridge
```

然后用环境变量一次性把**你的 API 配置**写进去。下面给出几个常见供应商的写法,**任选其一**(`sk-xxx` 换成你自己的密钥):

### 写法 A:有"兼容 Anthropic 协议"端点的供应商(推荐,效果最好)

火山引擎方舟、DeepSeek、智谱等都提供 Anthropic 原生端点,直通不翻译,tool calls / 思考链 / 流式都能完整保留:

```bash
# 以火山引擎方舟为例
CUSTOM_API_KEY="ark-你的密钥" \
CUSTOM_BASE_URL="https://ark.cn-beijing.volces.com/api/plan" \
CUSTOM_UPSTREAM_MODE="anthropic" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="glm-5.2" \
MODEL_LIST_MODE="aliases" \
MODEL_MENU_STRATEGY="claude_compatible" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"我的模型","backend":"custom","model":"glm-5.2"}]' \
INLINE_IMAGE_POLICY="auto" \
PROXY_PORT="9876" \
./scripts/install-safe.sh
```

### 写法 B:只有 OpenAI 兼容端点的供应商

DeepSeek、硅基流动(Kimi/Qwen)、OpenAI、本地 Ollama/vLLM 等都属于这类:

```bash
# 以 DeepSeek 为例
CUSTOM_API_KEY="sk-你的密钥" \
CUSTOM_BASE_URL="https://api.deepseek.com" \
CUSTOM_UPSTREAM_MODE="openai" \
DEFAULT_BACKEND="custom" \
FORCE_MODEL="deepseek-chat" \
MODEL_LIST_MODE="aliases" \
MODEL_MENU_STRATEGY="claude_compatible" \
MODEL_ALIASES='[{"id":"claude-sonnet-4-5","display_name":"DeepSeek","backend":"custom","model":"deepseek-chat"}]' \
INLINE_IMAGE_POLICY="auto" \
PROXY_PORT="9876" \
./scripts/install-safe.sh
```

安装脚本会自动:创建 Python 虚拟环境、装依赖、生成配置、注册 systemd 用户服务(开机自启)。

> ⚠️ **端口必须用 4 位数**(如 9876),后面打免登录补丁要用到等长替换,5 位数会失败。

## 六、支持的 API 供应商(不限于火山引擎)

| 供应商 | base_url | 模式 | 模型示例 |
|---|---|---|---|
| 火山引擎方舟 | `https://ark.cn-beijing.volces.com/api/plan` | anthropic | glm-5.2 / doubao-seed-2.0-pro |
| DeepSeek | `https://api.deepseek.com` | openai 或 anthropic | deepseek-chat |
| 智谱 z.ai | `https://api.z.ai/api/paas/v4` | openai | glm-4.6 |
| 硅基流动 | `https://api.siliconflow.cn` | openai | Pro/moonshotai/Kimi-K2.6 |
| OpenAI | `https://api.openai.com` | openai | gpt-4o |
| 本地 Ollama | `http://127.0.0.1:11434/v1` | openai | qwen2.5 |
| 本地 vLLM | `http://127.0.0.1:8000/v1` | openai | 你的模型 |
| 任何 OneAPI/NewAPI 中转 | 你的中转地址 | openai | 任意 |

**一句话:只要是 OpenAI 兼容或 Anthropic 兼容的接口,都能接。** 有 Anthropic 原生端点就优先用 `anthropic` 模式,没有就用 `openai` 模式。

## 七、第三步:首次启动 + 生成免登录凭证

这一步要做三件事:让 Claude Science 创建本地数据目录、伪造一个 OAuth 登录令牌、给二进制打补丁把 claude.ai 的验证请求重定向到本地代理。

### 7.1 首次启动,创建数据目录

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:9876 \
  claude-science serve --port 8765 --no-browser --no-auto-update --dangerously-no-sandbox
```

等几秒,看到它打印出数据目录路径后 **按 Ctrl-C 停止**。这一步只是为了生成 `~/.claude-science/encryption.key`(后面伪造令牌要用)。

> `--dangerously-no-sandbox` 是因为 Ubuntu 20.04 自带的 bubblewrap 版本太旧(需 0.8+,20.04 只有 0.4)。Ubuntu 24.04+ 可去掉这个参数,享受完整沙箱隔离。详见后文注意事项。

### 7.2 伪造 OAuth 登录令牌

```bash
~/claude-science-api-bridge/.venv/bin/python \
  ~/claude-science-api-bridge/setup-token.py
```

这会在 `~/.claude-science/.oauth-tokens/` 生成一个加密的假登录令牌(有效期到 2099 年,无需刷新)。Claude Science 读到它就以为自己已登录。

### 7.3 给二进制打免登录补丁(关键)

Claude Science 启动时会偷偷请求 `claude.ai` / `api.anthropic.com` 验证登录状态,这些请求在国内必然失败。补丁的作用是在二进制里把这些 URL 等长替换成本地代理地址,让验证请求转到代理上(代理会返回"已登录"的假数据):

```bash
cd ~/claude-science-api-bridge
PYTHON=.venv/bin/python PROXY_PORT=9876 PROXY_HTTPS_PORT=9877 \
  ./scripts/patch-daemon-auth.sh ~/.local/bin/claude-science
```

看到 `Patched N OAuth URL occurrence(s)` 和 `executable check passed` 就成功了。脚本会自动备份原文件(`.byok-auth-original`)。

> **补丁会在 Claude Science 更新后失效**(更新会替换二进制),更新后需重新跑一次这条命令。

## 八、第四步:启动,开用

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:9876 \
  claude-science serve --port 8765 --no-browser --no-auto-update \
  --dangerously-no-sandbox --detached

# 拿一次性登录链接
claude-science url
```

把打印出的 `http://localhost:8765/?nonce=...` 链接复制到浏览器(WSL 用户在 Windows 浏览器打开即可,localhost 会自动转发),点一下页面上的 **"Sign in"** 按钮——这只是确认一次性令牌,**不需要任何账号密码**。点完就进入主界面了。

之后所有对话、代码执行都走你配置的 API。新建项目、丢数据进去、让它画图分析,尽情用。

### 设成开机自启(可选)

把 Claude Science 也注册成 systemd 服务,WSL 启动时自动拉起:

```bash
cat > ~/.config/systemd/user/claude-science.service <<'EOF'
[Unit]
Description=Claude Science
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

systemctl --user daemon-reload
systemctl --user enable --now claude-science.service
```

以后打开 WSL 就自动运行,只需 `claude-science url` 拿链接即可。

## 九、验证是否成功

在终端跑一条测试,确认整条链路通:

```bash
curl -sS http://127.0.0.1:9876/v1/messages \
  -H 'content-type: application/json' \
  -d '{"model":"claude-sonnet-4-5","max_tokens":256,"messages":[{"role":"user","content":"17乘以23等于多少?"}]}'
```

能正常返回答案就说明:Claude Science → 本地代理 → 你的 API,全线打通。

## 十、注意事项与排坑

1. **bubblewrap 版本**:Claude Science 的代码沙箱需要 bubblewrap 0.8.0+。Ubuntu 20.04 / 22.04 自带版本太旧,会报 `bwrap too old`。两个办法:升级到 Ubuntu 24.04+(推荐);或暂时加 `--dangerously-no-sandbox` 跳过沙箱(代码会有完整的家目录读写权限,自用可接受,生产环境慎用)。

2. **补丁随更新失效**:Claude Science 更新会覆盖二进制,免登录补丁要重打。可以写个启动脚本每次检测补丁是否还在,缺失就自动重打。

3. **模型会"思考"消耗 token**:GLM-5.2、DeepSeek-R1 等带思考链的模型,思考过程也算 token。如果发现回复正文是空的,把 max_tokens 调大(512 以上)。

4. **端口冲突**:代理默认用 9876。如果被占用可换别的**四位**端口(如 9875),但补丁要求端口必须是 4 位数。

5. **WSL 路径**:Claude Science 装在 WSL/Linux 里,处理文件最稳的做法是把数据放到 WSL 可访问目录(如 `~/.claude-science/artifacts/`),而不是直接喂 `/mnt/d/...` 的 Windows 路径。终端能读 ≠ 沙箱工具能读。

6. **不要泄露密钥**:配置文件 `config.json` 里有你的 API 密钥(chmod 600 已限制权限)。截图、发文章、分享日志时记得打码。本文所有密钥均为占位符。

## 十一、小结

这套方案的核心思路其实很简单:

- **封锁**绕不过去?那就绕开被封锁的域名,直接从没被封锁的 CDN 拿二进制。
- **登录**办不到?那就伪造登录态,再把验证请求重定向到本地代理。
- **官方 API** 用不起/用不了?那就接你自己的 API,代理帮你做格式转换。

Claude Science 真正的价值在于那个"过程可追溯"的科研工作台:代码、数据、图表、执行记录都焊在一起,复盘时不用在聊天记录和文件夹之间来回翻。而这套免登录 + 自带 API 的玩法,让国内研究者也能用上它——而且不绑定任何一家模型供应商,哪家便宜、哪家好用就换哪家。

---

*本文基于 Claude Science 0.1.15 和 claude-science-api-bridge v0.2.9。软件会更新,步骤可能有微调,以官方文档和项目 README 为准。*

*涉及的工具均为开源项目,仅供学习研究使用。*
