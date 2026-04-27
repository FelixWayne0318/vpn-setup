# vpn-setup — AI 编程工具专用自建 VPN

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/FelixWayne0318/vpn-setup?style=social)](https://github.com/FelixWayne0318/vpn-setup/stargazers)

中文 | [English](README_EN.md)

**一键部署 VLESS Reality VPN，彻底解决 Claude Code / Cursor / Windsurf / GitHub Copilot 的连接问题。**

> 适用于中国大陆、伊朗、俄罗斯、土耳其等受网络审查影响的地区，也适用于全球任何使用 VPS 自建代理后遇到 AI 工具 403 的开发者。

> 如果这个项目帮到了你，请点个 Star 让更多开发者看到。

## 这个项目解决什么问题？

如果你通过 VPN/代理访问 AI 编程工具，大概率遇到过这些情况：

### 场景一：浏览器能用，但 AI 编程工具全部用不了

浏览器打开 claude.ai、chatgpt.com 完全正常，但切到 IDE 就全挂了：

| 工具 | 症状 |
|------|------|
| **VS Code** + Claude Code 插件 | `ECONNRESET` / `403 Request not allowed` |
| **VS Code** + GitHub Copilot | 无法连接 / 频繁掉线 |
| **Windsurf (Antigravity)** | Claude 插件连接失败 |
| **Cursor** | 调用 Claude/GPT API 超时或 403 |
| **终端** `claude` CLI | 报错退出 |
| **Cline / Continue.dev** | 无法连接 API |
| **Aider** | Connection refused |

共同特征：**浏览器正常，IDE 全挂，开了 VPN 也没用。**

### 场景二：刚登录能用，过几小时又不行了

- 第一次登录 Claude Code，一切正常
- 几个小时后突然 403，重启 VS Code 也不行
- 重新登录又能用了，但过几小时又挂
- 循环往复，根本没法稳定工作

### 场景三：自建了 VPN，AI 工具还是 403

- 自己搭了 Xray/V2Ray，科学上网完全正常
- Google、YouTube、Twitter 都能用
- 唯独 Claude Code / Cursor 报 403
- 换了 Vultr、AWS、DigitalOcean，全部 403
- 试了 WARP、换 IP、改 DNS，折腾一整天还是不行

### 场景四：商业 VPN / 机场不可靠

- 商业 VPN 或机场经常断线，正在用 Claude Code 写代码时突然断掉
- 上下文全丢了，只能重新开始
- 关键时刻用不了，工作流完全依赖一个不可控的第三方

---

## 根本原因（很少有人说清楚）

以上场景的根本原因是 **三个独立问题叠加**，必须全部解决才能稳定使用：

### 问题 1: Node.js 不读系统代理

所有 AI 编程工具（Claude Code、Cursor、Windsurf、Copilot、Cline、Aider）底层都依赖 Node.js 或类似运行时。Node.js **完全忽略 macOS/Windows 系统代理设置**。

所以你的 VPN 对浏览器生效了，但对 IDE 中的 AI 插件**根本没有生效** —— 它们的网络请求直接走裸连。

### 问题 2: 数据中心 IP 被 Cloudflare Challenge

即使解决了代理问题，你的 VPS（Vultr/AWS/DO）出口 IP 是数据中心 IP。Cloudflare 对这些 IP 返回 JavaScript Challenge（403）。浏览器能自动执行 JS Challenge 通过验证，Node.js 不能。

| 端点 | Cloudflare Challenge | 数据中心 IP 结果 |
|------|---------------------|----------------|
| `api.anthropic.com` | 无 | 正常 |
| `api.openai.com` | 无 | 正常 |
| `claude.ai` | **有** | **403** (Node.js 过不了) |
| `chatgpt.com` | **有** | **403** (Node.js 过不了) |
| `platform.claude.com` | **有** | **403** (Node.js 过不了) |

### 问题 3: OAuth Session 过期

Claude Code 登录后获得一个短期 OAuth Session（约 16 小时），存在 macOS Keychain 中。过期后自动刷新 → 访问 `claude.ai` → 被 Cloudflare Challenge → 403。

**这就是"刚登录能用、过几小时就挂"的原因。**

### 为什么 WARP 也没用？

Cloudflare WARP 的出口 IP (104.28.x.x) 同属 Cloudflare 自己的网段，同样会被 Challenge。WARP 能解锁 API 级别访问（`api.anthropic.com`），但**不能解决 OAuth 刷新访问 `claude.ai` 的 403 问题**。

---

## 这个项目怎么解决的？

```
Mac / Windows (Clash Verge + TUN 全局透明代理)
  ├── 主节点   VLESS+Reality :2083  ← 抗 DPI 检测，伪装合法 TLS
  ├── 备用     VLESS+Reality :8443  ← 主节点被封时切换
  └── CDN节点  Cloudflare Workers   ← IP 被封时通过 CDN 中转
                    ↓
VPS (x-ui 面板 + Xray + WARP)
  ├── x-ui Web 面板管理节点和路由规则
  ├── 普通流量 → 直接出站
  └── AI 域名 (Claude/OpenAI/Gemini) → WARP 出站（干净 IP）
                    ↓
AI 编程工具 ← 长期 OAuth Token 绕过 OAuth 刷新（1 年有效）
```

**三层解决方案，每一层解决一个根本问题：**

| 层 | 解决的问题 | 实现方式 |
|----|-----------|---------|
| TUN 全局代理 | Node.js 不读系统代理 | Clash Verge TUN 模式接管全部流量 + `HTTPS_PROXY` 环境变量双保障 |
| WARP AI 路由 | 数据中心 IP 被 Challenge | 服务器端 AI 域名走 Cloudflare WARP socks5 出站 |
| OAuth Token | OAuth 刷新 403 | `claude setup-token` 生成 1 年期 Token，彻底绕过 OAuth 刷新 |

## 快速开始

### 前提
- 一台海外 VPS（推荐 Vultr Singapore，$5/月）
- Mac / Windows / iPhone / Android

### 1. 服务器一键部署
```bash
git clone https://github.com/FelixWayne0318/vpn-setup.git
cd vpn-setup
cp .env.example .env
vi .env  # 填入服务器 IP

sudo bash server/install.sh
# 自动安装: x-ui 面板 + WARP + 防火墙
# 然后在 x-ui Web 面板中配置节点和 AI 域名路由规则
# 详见 docs/server-setup.md
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
│   ├── install.sh              # 服务器一键安装 (x-ui + WARP + UFW)
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
├── verify.sh                    # 一键全链路验证
├── .github/ISSUE_TEMPLATE/      # Issue 模板
└── .gitignore                   # 排除 .env 等敏感文件
```

## 技术细节

| 组件 | 选型 | 理由 |
|------|------|------|
| 协议 | VLESS + Reality | 当前抗 DPI 检测最强方案，伪装合法 TLS 握手 |
| 加密 | TLS 1.3 CHACHA20 | 最新标准 |
| 服务端管理 | 3x-ui 面板 | Web 界面管理节点、路由、流量统计 |
| 客户端 | Clash Verge (mihomo) | 支持 TUN 全局透明代理 + 规则分流 |
| AI 解锁 | Cloudflare WARP socks5 | AI 域名走干净 IP，绕过 CF Challenge |
| 备用通道 | Cloudflare CDN Workers | IP 被封时通过 CDN 中转，永不断线 |
| 分流 | GEOSITE/GEOIP CN → DIRECT | 国内流量直连，不走代理 |

## 验证效果

```bash
# 一键全链路验证
bash verify.sh

# 或手动验证:
curl https://www.google.com  # 200
claude -p "say: OK"          # OK
curl https://www.baidu.com   # 200（不走代理）
```

## 这个项目和其他 VPN 项目有什么不同？

GitHub 上 Xray/Clash 部署脚本很多，但它们只解决"翻墙"这一步。**翻墙之后 AI 编程工具还是用不了**的问题，没有项目系统性解决过：

| 问题 | 其他项目 | 本项目 |
|------|---------|--------|
| 浏览器能用但 IDE 中的 AI 工具全不能用 | 没有涉及 | [完整解决方案](docs/claude-code.md) |
| 数据中心 IP 被 Cloudflare Challenge → 403 | 没有说清根因 | 根因分析 + OAuth Token 绕过 |
| 登录后几小时 AI 工具又断了 | 没有涉及 | OAuth Session 过期机制 + 长期 Token |
| macOS Keychain 缓存过期 Session 导致反复 403 | 没有涉及 | 一行命令清理 |
| AI 域名需要干净 IP（服务器端分流） | 少数有 WARP，不做域名路由 | AI 域名走 WARP，其余直连 |
| Clash Verge 重启后配置丢失 | 没有涉及 | merge.yaml 持久化 |
| 其他 VPN 劫持出站导致 TLS handshake eof | 没有涉及 | `interface-name: en0` 强制物理网卡 |
| DNS 端口 53 权限冲突导致 Clash 整体崩溃 | 没有涉及 | 改用 1053 |
| 端到端全链路（服务器→客户端→AI 工具） | 分段覆盖 | 一站式解决 |

简单说：**其他项目帮你翻墙，这个项目帮你翻墙之后还能正常用 AI 编程工具。**

## 受影响的工具（已验证）

以下工具在通过 VPN/代理访问时都会遇到上述问题，本项目均可解决：

- Claude Code (VS Code 插件 + CLI)
- Cursor (Claude / GPT 模型)
- Windsurf / Codeium (Antigravity)
- GitHub Copilot
- Cline (VS Code 插件)
- Continue.dev
- Aider
- Amazon Q Developer

## 适用场景

- 在受审查地区（中国、伊朗、俄罗斯、土耳其等）使用 AI 编程工具
- 全球任何地区，自建 VPN 后 AI 工具仍然 403 / ECONNRESET（Cloudflare Challenge 是全球性问题）
- 需要稳定的开发环境，不想依赖商业 VPN
- "浏览器能用但 IDE 插件不能用"
- "刚登录能用，过几小时又不行了"
- 想要一键部署，不想手动配置 Xray / Clash

## 不适用

- 只需要浏览网页（商业 VPN 够用了）
- 不会用终端 / 没有 VPS
- AI 工具在你的网络下已经正常工作

## License

MIT
