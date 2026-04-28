# AI 编程工具连接配置指南 (Claude Code / OpenAI Codex)

## 症状

**浏览器打开 claude.ai 正常，但所有 AI 编程工具都报错：**

- VS Code Claude Code 插件 → `ECONNRESET` 或 `403`
- Windsurf (Antigravity) Claude 插件 → 连接失败
- Cursor 调用 Claude API → 无法连接
- 终端 `claude` CLI → 报错

开了 VPN 也没用，换了节点也没用，但浏览器一直正常 —— 这不是 VPN 的问题，而是这些工具的运行方式导致的。

**所有基于 Node.js 的 AI 编程工具都会中招**，因为它们共享同一个根本原因。

## 根本原因

Claude Code 运行在 Node.js 上，有**两个独立问题叠加**：

### 问题 1: Node.js 不读系统代理

浏览器能用是因为它读取了 macOS 系统代理设置。但 Node.js（Claude Code 的运行时）**完全忽略系统代理**，必须通过 `HTTPS_PROXY` 环境变量显式指定，否则 Claude Code 的网络请求根本不走 VPN。

### 问题 2: 数据中心 IP 被 Cloudflare Challenge

即使代理生效了，Claude Code 的 OAuth 刷新流程会访问 `claude.ai`。该域名对数据中心 IP（Vultr/AWS/DigitalOcean）返回 Cloudflare JavaScript Challenge（403）。浏览器能自动执行 JS Challenge 通过验证，但 Node.js 不能。

| 端点 | Cloudflare Challenge | 数据中心 IP 结果 |
|------|---------------------|----------------|
| `api.anthropic.com` | 无 | 正常 |
| `api.openai.com` | 无 | 正常 |
| `claude.ai` | 有 | 403 (Node.js 过不了) |
| `platform.claude.com` | 有 | 403 (Node.js 过不了) |
| `auth.openai.com` | 有 | 403 (Codex/ChatGPT OAuth 登录超时) |

> **WARP 也无效**: Cloudflare WARP 的出口 IP (104.28.x.x) 同属 Cloudflare，同样被 Challenge。服务器端 WARP 路由只能解锁 API 级别访问，不能解决 OAuth 刷新问题。WARP 出口与 VPS 同区域（如新加坡），无法选择出口地区。

### 为什么"过几小时就不能用了"

Claude Code 登录后获得一个短期 OAuth Session（约 16 小时），存在 macOS Keychain 中。过期后 Claude Code 尝试刷新 → 访问 `claude.ai` → 403 → 报错。所以你会看到"刚登录能用，过一会就不行了"。

## 解决方案（两步，缺一不可）

### Step 1: TUN 模式 + 代理环境变量

TUN 模式接管全局流量，确保所有进程（包括 VS Code 子进程）走代理。

同时在 `~/.zshrc` 设置环境变量作为双重保障：

```bash
# Clash Verge 代理
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
export all_proxy=socks5://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=http://127.0.0.1:7897
export NO_PROXY=localhost,127.0.0.1,::1,*.local
```

### Step 2: 长期 OAuth Token

生成一个有效期约 1 年的 Token，绕过 OAuth 刷新流程（不再访问 claude.ai）：

```bash
claude setup-token
```

命令会打开浏览器完成 OAuth 授权（浏览器能通过 Cloudflare Challenge），授权后复制 token 写入 `~/.zshrc`：

```bash
export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-你的token..."
```

> **注意**: 如果 `~/.zshrc` 中存在 `ANTHROPIC_API_KEY`，必须删除，否则 Token 会被覆盖（优先级更高）。

## 验证

```bash
source ~/.zshrc

# 1. 代理通路
curl -x http://127.0.0.1:7897 https://api.anthropic.com/ 2>&1 | head -3
# 期望: 401 或 404（网络通）

# 2. Token 已加载
echo $CLAUDE_CODE_OAUTH_TOKEN | cut -c1-20
# 期望: sk-ant-oat01-

# 3. Claude Code 测试
claude -p "say: OK"
# 期望: OK
```

## Token 续期

有效期约 **1 年**。到期后重新运行：

```bash
claude setup-token
```

浏览器授权后更新 `~/.zshrc` 中的 token 值，然后 `source ~/.zshrc`。

## macOS Keychain 干扰

macOS Keychain 会缓存短期 OAuth Session（16 小时）。过期后 Claude Code 尝试刷新 → 访问 claude.ai → 403。

**症状**: 设置了 Token 仍然 403（通常是新终端未 source ~/.zshrc）。

**修复**:
```bash
security delete-generic-password -s "Claude Code-credentials"
source ~/.zshrc
```

## Claude 二进制路径 (macOS)

Claude Code CLI 通过 VS Code 扩展安装，symlink 指向扩展内的原生二进制：

```
~/.local/node/bin/claude
  → ~/.vscode/extensions/anthropic.claude-code-<版本>-darwin-arm64/resources/native-binary/claude
```

VS Code 扩展升级后版本号变化，需要更新 symlink：

```bash
# 找到新版本
ls ~/.vscode/extensions/ | grep claude-code

# 更新 symlink
ln -sf ~/.vscode/extensions/anthropic.claude-code-<新版本>/resources/native-binary/claude \
       ~/.local/node/bin/claude
```

## 换服务器后

| 操作 | 是否需要 |
|------|---------|
| 更新 Clash 节点 IP | 是 |
| 重新生成 Token | 否（Token 与服务器 IP 无关） |

---

## OpenAI Codex (VS Code 扩展 / CLI)

### 症状

Codex 扩展点击登录 → "糟糕，出错了！Operation timed out"。

### 根因

与 Claude Code 相同的问题。`auth.openai.com` 被 Cloudflare Managed Challenge 保护。

浏览器 OAuth 重定向本身没问题，但 **Codex 的 HTTP 客户端无法完成 token exchange**（POST 到 `auth.openai.com/oauth/token`），因为 Cloudflare JS Challenge 阻止了非浏览器请求。这是 [OpenAI 已知 Bug](https://github.com/openai/codex/issues/16052)，全球多个地区受影响。

- VPS 直连 (Vultr IP) → 403 `cf-mitigated: challenge`
- VPS WARP (Cloudflare IP) → 403 `cf-mitigated: challenge`
- `api.openai.com` 正常可达 → **API 调用没问题，只有 OAuth 登录有问题**

### Codex 的两种认证方式

| 方式 | 计费 | 适用场景 |
|------|------|---------|
| **ChatGPT 订阅登录** | 使用 ChatGPT Plus/Pro 订阅额度，不额外花钱 | 日常开发 |
| **API Key 登录** | 使用 OpenAI Platform API 额度，**独立计费** | CI/CD、无浏览器环境 |

> **重要**: API Key 和 ChatGPT 订阅是**独立计费**的。如果你有 ChatGPT Plus/Pro 订阅，应优先使用方案 A（订阅登录），避免额外费用。

---

### 方案 A: 使用 ChatGPT 订阅登录（推荐，不额外花钱）

由于 Cloudflare Challenge 阻止了 token exchange，需要**在干净网络上完成一次登录**，然后缓存凭证。

**步骤 1: 配置 Codex 使用文件存储凭证**

```bash
mkdir -p ~/.codex
cat > ~/.codex/config.toml << 'EOF'
# 强制使用 ChatGPT 订阅登录（不走 API Key）
forced_login_method = "chatgpt"

# 凭证存储到文件（方便跨网络复用）
cli_auth_credentials_store = "file"
EOF
```

**步骤 2: 在干净网络上完成登录**

需要一个不触发 Cloudflare Challenge 的网络（以下任选一种）：

- **手机热点共享** — 手机 4G/5G 热点连 Mac，临时关闭 Clash Verge，然后打开 Codex 登录
- **其他设备上登录** — 在能正常访问 auth.openai.com 的设备上安装 Codex CLI，登录后复制 `~/.codex/auth.json` 到你的 Mac

```bash
# 方式一: 手机热点
# 1. 手机开热点，Mac 连上
# 2. 暂停 Clash Verge（退出或关闭系统代理+TUN）
# 3. 打开 VS Code → Codex 扩展 → 点击登录
# 4. 浏览器完成 OAuth → 登录成功
# 5. 重新开启 Clash Verge
# 6. 凭证已缓存在 ~/.codex/auth.json，后续自动复用

# 方式二: 从其他设备复制
# 在能正常登录的设备上:
scp ~/.codex/auth.json your-mac:~/.codex/auth.json
```

**步骤 3: 验证**

```bash
# 重启 VS Code，Codex 应直接进入已登录状态
# 检查凭证文件
ls -la ~/.codex/auth.json
# 应存在且非空
```

> **凭证有效期**: auth.json 中的 token 会自动刷新。如果后续刷新失败（Cloudflare 再次阻断），重复步骤 2。

---

### 方案 B: 使用 API Key（独立计费，立即可用）

如果方案 A 不可行（没有干净网络），可以用 API Key。**注意: 这会使用 OpenAI Platform API 额度，与 ChatGPT 订阅分开计费。**

**步骤 1: 生成 API Key**

浏览器打开 https://platform.openai.com/api-keys → 创建 Key

**步骤 2: 配置**

```bash
# 写入环境变量
echo 'export OPENAI_API_KEY="sk-proj-你的key..."' >> ~/.zshrc
source ~/.zshrc

# 配置 Codex 使用 API Key
mkdir -p ~/.codex
cat > ~/.codex/config.toml << 'EOF'
forced_login_method = "api"
cli_auth_credentials_store = "file"
EOF
```

**步骤 3: 重启 VS Code**

---

### 方案 C: 手动写入 auth.json（高级）

如果你能通过浏览器获取到 OAuth token（比如从浏览器开发者工具中提取），可以直接写入：

```bash
mkdir -p ~/.codex
cat > ~/.codex/auth.json << 'EOF'
{
  "token": "你的access_token",
  "refresh_token": "你的refresh_token"
}
EOF
chmod 600 ~/.codex/auth.json
```

---

### 验证

```bash
# 检查 Codex 配置
cat ~/.codex/config.toml

# 检查凭证
ls -la ~/.codex/auth.json

# API 通路测试
curl -x http://127.0.0.1:7897 \
  -H "Authorization: Bearer ${OPENAI_API_KEY:-test}" \
  https://api.openai.com/v1/models 2>&1 | head -3
# 期望: 200 (API Key 模式) 或 401 (订阅模式，正常)
```
