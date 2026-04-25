# 自建 VPN 完整部署指南

## 项目说明

基于 Xray VLESS Reality 协议的自建 VPN，客户端使用 Clash Verge (mihomo)。
支持从零开始在新服务器和新 Mac 上完整部署。

## 架构

```
Mac (Clash Verge + TUN) → VPS (Xray VLESS Reality) → 互联网
                        ↗ CDN节点 (Cloudflare Workers)
```

服务器端特性:
- VLESS Reality 双节点 (主 2083 + 备 8443)
- CDN WebSocket 节点 (Cloudflare 中转，IP 被封时备用)
- Cloudflare WARP 出站 (AI 域名走干净 IP)
- 流量统计 + Sniffing

## 目录结构

```
vpn-setup/
├── README.md                          # 本文件
├── .gitignore                         # 忽略敏感文件
├── .env.example                       # 环境变量模板（不含真实值）
├── .env                               # 真实环境变量（不上传）
│
├── server/                            # 服务端配置
│   ├── install.sh                     # 一键安装脚本 (Xray + WARP)
│   └── ufw-rules.sh                   # 防火墙规则
│
├── client/                            # 客户端配置
│   ├── clash-verge.yaml               # Clash Verge 主配置模板
│   ├── merge.yaml                     # 持久化配置（防重启覆盖）
│   └── setup-mac.sh                   # Mac 一键配置脚本
│
└── docs/
    ├── server-setup.md                # 服务器部署详细步骤
    ├── client-setup.md                # 客户端配置 (Mac/iPhone/Android/Windows)
    └── claude-code.md                 # Claude Code VS Code 插件配置
```

## 快速开始

### 1. 服务器部署
```bash
# 复制 .env.example 为 .env，填入真实值
cp .env.example .env
vi .env

# 一键安装 (Xray + WARP + 防火墙)
sudo bash server/install.sh
```

### 2. Mac 客户端配置
```bash
# 安装 Clash Verge (手动下载)
# https://github.com/clash-verge-rev/clash-verge-rev/releases

# 一键配置
bash client/setup-mac.sh

# 手动操作 (脚本会提醒):
#   - Clash Verge 设置 → 安装 Service Mode
#   - 开启虚拟网卡模式 (TUN)
#   - 开启系统代理
#   - 开启开机自启
```

### 3. Claude Code 配置
参见 [docs/claude-code.md](docs/claude-code.md) — OAuth Token + 代理环境变量

### 4. 手机配置
参见 [docs/client-setup.md](docs/client-setup.md)
