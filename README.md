# vpn-setup — 中国开发者 AI 工具专用自建 VPN

**一键部署 VLESS Reality VPN，彻底解决 Claude Code / ChatGPT / Cursor 在中国大陆的连接问题。**

## 这个项目解决什么问题？

如果你在中国大陆做开发，大概率遇到过这些情况：

### 商业 VPN 不可靠
- 机场/商业 VPN 经常断线，正在写代码时突然断掉
- Claude Code 跑到一半报 `ECONNRESET`，之前的上下文全丢了
- 关键时刻用不了，你的工作流完全依赖一个不可控的第三方

### 浏览器能用，但 AI 编程工具全部不能用
- 浏览器打开 claude.ai / chatgpt.com 完全正常
- 但 VS Code Claude 插件、Windsurf (Antigravity)、Cursor、终端 CLI 全部报错
- 403 / ECONNRESET / 连接失败
- 刚登录能用，过几小时又不行了
- 开了 VPN 也没用，换了节点也没用，完全搞不懂为什么

### 自建了 VPN，AI 工具还是 403
- Vultr / AWS / DigitalOcean 的数据中心 IP 被 Cloudflare Challenge 拦截
- 搜了一堆帖子，试了 WARP、换 IP、改 DNS，折腾半天还是不行

### 根本原因（很少有人说清楚）
**两个独立问题叠加**，必须同时解决：

1. **Node.js 不读系统代理** — Claude Code / Cursor 运行在 Node.js 上，macOS 系统代理对它们无效，必须设置 `HTTPS_PROXY` 环境变量 + TUN 全局透明代理
2. **数据中心 IP 被 Cloudflare Challenge** — Claude Code 的 OAuth 刷新会访问 `claude.ai`，该域名对数据中心 IP 返回 403（浏览器能过 JS Challenge，Node.js 过不了）

| 端点 | Cloudflare Challenge | 数据中心 IP |
|------|---------------------|------------|
| `api.anthropic.com` | 无 | 正常 |
| `claude.ai` | 有 | 403 |
| `chatgpt.com` | 有 | 403 |

## 这个项目怎么解决的？

```
Mac (Clash Verge + TUN 全局透明代理)
  ├── 主节点   VLESS+Reality :2083  ← 抗 DPI 检测，伪装合法 TLS
  ├── 备用     VLESS+Reality :8443  ← 主节点被封时切换
  └── CDN节点  Cloudflare Workers   ← IP 被封时通过 CDN 中转
                    ↓
VPS (Xray + WARP)
  ├── 普通流量 → 直接出站
  └── AI 域名 (Claude/OpenAI/Gemini) → WARP 出站（干净 IP）
                    ↓
Claude Code ← 长期 OAuth Token 绕过 OAuth 刷新（1 年有效）
```

**三层解决方案，缺一不可：**

| 层 | 解决的问题 | 实现方式 |
|----|-----------|---------|
| TUN 全局代理 | Node.js 不读系统代理 | Clash Verge TUN 模式 + `HTTPS_PROXY` 环境变量 |
| WARP AI 路由 | 数据中心 IP 被 Challenge | 服务器端 AI 域名走 Cloudflare WARP 出站 |
| OAuth Token | OAuth 刷新 403 | `claude setup-token` 生成 1 年期 Token，绕过刷新流程 |

## 快速开始

### 前提
- 一台海外 VPS（推荐 Vultr Singapore，$5/月）
- Mac / Windows / iPhone / Android

### 1. 服务器一键部署
```bash
git clone https://github.com/FelixWayne0318/vpn-setup.git
cd vpn-setup
cp .env.example .env
vi .env  # 填入服务器 IP，其他留空让脚本自动生成

sudo bash server/install.sh
# 自动安装: Xray + WARP + 防火墙 + AI 域名路由
```

### 2. Mac 客户端一键配置
```bash
# 先安装 Clash Verge: https://github.com/clash-verge-rev/clash-verge-rev/releases

bash client/setup-mac.sh
# 自动生成 Clash 配置 + 写入代理环境变量 + 验证连通性
```

脚本完成后手动操作：
1. Clash Verge 设置 → 安装 Service Mode
2. 开启虚拟网卡模式（TUN）
3. 开启系统代理 + 开机自启

### 3. Claude Code 配置
```bash
# 生成 1 年期 OAuth Token
claude setup-token

# 写入 ~/.zshrc
echo 'export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-你的token..."' >> ~/.zshrc
source ~/.zshrc
```

详见 [docs/claude-code.md](docs/claude-code.md)

### 4. 手机 / 其他平台
详见 [docs/client-setup.md](docs/client-setup.md)（Shadowrocket / v2rayNG / Windows Clash Verge）

## 项目结构

```
vpn-setup/
├── server/
│   ├── install.sh              # 服务器一键安装 (Xray + WARP + UFW)
│   └── ufw-rules.sh            # 防火墙规则
├── client/
│   ├── clash-verge.yaml         # Clash Verge 配置模板
│   ├── merge.yaml               # 持久化配置（防重启覆盖）
│   └── setup-mac.sh             # Mac 一键配置脚本
├── docs/
│   ├── server-setup.md          # 服务器部署详细步骤
│   ├── client-setup.md          # 多平台客户端配置
│   └── claude-code.md           # Claude Code 连接问题完整解决方案
├── .env.example                 # 环境变量模板
└── .gitignore                   # 排除 .env 等敏感文件
```

## 技术细节

| 组件 | 选型 | 理由 |
|------|------|------|
| 协议 | VLESS + Reality | 当前抗 DPI 检测最强方案，伪装合法 TLS 握手 |
| 加密 | TLS 1.3 CHACHA20 | 最新标准 |
| 客户端 | Clash Verge (mihomo) | 支持 TUN 全局透明代理 + 规则分流 |
| AI 解锁 | Cloudflare WARP socks5 | AI 域名走干净 IP，绕过 CF Challenge |
| 备用通道 | Cloudflare CDN Workers | IP 被封时通过 CDN 中转，永不断线 |
| 分流 | GEOSITE/GEOIP CN → DIRECT | 国内流量直连，不走代理 |

## 验证效果

```bash
# 代理连通
curl https://www.google.com  # 200

# Claude Code 正常
claude -p "say: OK"  # OK

# 国内直连
curl https://www.baidu.com  # 200（不走代理）

# 无 DNS / IPv6 泄漏
```

## 这个项目和其他 VPN 项目有什么不同？

GitHub 上 Xray/Clash 部署脚本很多，但它们只解决"翻墙"这一步。**翻墙之后 AI 工具还是用不了**的问题，没有项目系统性解决过：

| 问题 | 其他项目 | 本项目 |
|------|---------|--------|
| 浏览器能用但 VS Code / Windsurf / Cursor 全不能用 | 没有涉及 | [完整解决方案](docs/claude-code.md) |
| 数据中心 IP 被 Cloudflare Challenge → 403 | 没有说清根因 | 根因分析 + OAuth Token 绕过 |
| 登录后几小时 AI 工具又断了 | 没有涉及 | OAuth Session 过期机制 + 长期 Token |
| macOS Keychain 缓存过期 Session 导致反复 403 | 没有涉及 | 一行命令清理 |
| AI 域名需要干净 IP（服务器端分流） | 少数有 WARP，不做域名路由 | AI 域名走 WARP，其余直连 |
| Clash Verge 重启后配置丢失 | 没有涉及 | merge.yaml 持久化 |
| 其他 VPN 劫持出站导致 TLS handshake eof | 没有涉及 | `interface-name: en0` 强制物理网卡 |
| DNS 端口 53 权限冲突导致 Clash 整体崩溃 | 没有涉及 | 改用 1053 |
| 端到端全链路（服务器→客户端→AI 工具） | 分段覆盖 | 一站式解决 |

简单说：**其他项目帮你翻墙，这个项目帮你翻墙之后还能正常用 Claude Code。**

## 适用场景

- 在中国大陆使用 Claude Code / Cursor / GitHub Copilot
- 需要稳定的开发环境，不想依赖商业 VPN
- 自建 VPN 后 AI 工具仍然 403 / ECONNRESET
- "浏览器能用但 VS Code / Windsurf / Cursor 插件不能用"
- 想要一键部署，不想手动配置 Xray / Clash

## 不适用

- 只需要浏览网页（商业 VPN 够用了）
- 不会用终端 / 没有 VPS

## License

MIT
