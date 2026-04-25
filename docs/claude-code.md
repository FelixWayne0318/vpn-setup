# Claude Code (VS Code 插件) 配置指南

## 问题背景

Claude Code 运行在 Node.js 上，有两个独立问题叠加导致无法工作：

1. **Node.js 不读系统代理** — 必须通过环境变量 `HTTPS_PROXY` 显式指定
2. **Vultr IP 被 Cloudflare Challenge** — OAuth 刷新访问 `claude.ai` / `platform.claude.com` 时返回 403

### 关键区别

| 端点 | Cloudflare Challenge | Vultr/WARP IP 结果 |
|------|---------------------|-------------------|
| `api.anthropic.com` | 无 | 正常 |
| `claude.ai` | 有 | 403 |
| `platform.claude.com` | 有 | 403 |

> **WARP 也无效**: Cloudflare WARP 的出口 IP (104.28.x.x) 同属 Cloudflare，同样被 Challenge。服务器端 WARP 路由只能解锁 API 级别访问，不能解决 OAuth 刷新问题。

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
