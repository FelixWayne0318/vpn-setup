# Claude Code (VS Code 插件) 配置指南

## 症状

**浏览器打开 claude.ai 正常，但 VS Code 中的 Claude Code 插件报错：**

- `API Error: Unable to connect to API (ECONNRESET)`
- `Request not allowed` (403)
- 登录后几小时突然不能用了

开了 VPN 也没用，换了节点也没用，但浏览器一直正常 —— 这不是 VPN 的问题，而是 Claude Code 的运行方式导致的。

## 根本原因

Claude Code 运行在 Node.js 上，有**两个独立问题叠加**：

### 问题 1: Node.js 不读系统代理

浏览器能用是因为它读取了 macOS 系统代理设置。但 Node.js（Claude Code 的运行时）**完全忽略系统代理**，必须通过 `HTTPS_PROXY` 环境变量显式指定，否则 Claude Code 的网络请求根本不走 VPN。

### 问题 2: 数据中心 IP 被 Cloudflare Challenge

即使代理生效了，Claude Code 的 OAuth 刷新流程会访问 `claude.ai`。该域名对数据中心 IP（Vultr/AWS/DigitalOcean）返回 Cloudflare JavaScript Challenge（403）。浏览器能自动执行 JS Challenge 通过验证，但 Node.js 不能。

| 端点 | Cloudflare Challenge | 数据中心 IP 结果 |
|------|---------------------|----------------|
| `api.anthropic.com` | 无 | 正常 |
| `claude.ai` | 有 | 403 (Node.js 过不了) |
| `platform.claude.com` | 有 | 403 (Node.js 过不了) |

> **WARP 也无效**: Cloudflare WARP 的出口 IP (104.28.x.x) 同属 Cloudflare，同样被 Challenge。服务器端 WARP 路由只能解锁 API 级别访问，不能解决 OAuth 刷新问题。

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
