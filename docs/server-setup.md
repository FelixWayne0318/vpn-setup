# 服务器部署指南

## 前提条件

- 一台海外 VPS（推荐 Vultr、Bandwagon、DigitalOcean）
- Ubuntu 22.04+
- 至少 1 核 1G 内存
- SSH 访问权限

## 架构概览

```
x-ui 面板 (Web 管理)
  └── Xray 核心
        ├── 主节点   VLESS+Reality :2083 (伪装 www.microsoft.com)
        ├── 备用节点  VLESS+Reality :8443 (伪装 addons.mozilla.org)
        └── CDN节点  VLESS+WS :10000 (Cloudflare 中转)
              ↓ 路由规则
        ├── AI 域名 → WARP socks5 出站 (干净 IP)
        ├── 私有 IP → 屏蔽
        ├── BT 协议 → 屏蔽
        └── 其他 → 直连出站

Cloudflare WARP (socks5 :40000)
  └── AI 域名解锁 (Claude/OpenAI/Gemini/Cursor)
```

## 部署步骤

### 1. 购买并配置 VPS

推荐配置:
- 地区: 新加坡 / 香港 / 日本 / 美国（按延迟优先）
- 系统: Ubuntu 22.04 LTS
- 配置: 1核 1G 起步

### 2. SSH 登录服务器

```bash
ssh root@你的服务器IP
```

### 3. 创建普通用户（安全最佳实践）

```bash
adduser linuxuser
usermod -aG sudo linuxuser
```

### 4. 一键安装

```bash
git clone https://github.com/FelixWayne0318/vpn-setup.git
cd vpn-setup
cp .env.example .env
vi .env  # 填入服务器 IP

sudo bash server/install.sh
```

脚本会自动安装:
- **3x-ui 面板** (内置 Xray，Web 界面管理节点)
- **Cloudflare WARP** (AI 域名走干净 IP)
- **UFW 防火墙** 规则

### 5. 配置 x-ui 面板

安装完成后，浏览器访问:

```
http://你的服务器IP:2096
```

#### 5.1 添加入站节点

在 x-ui 面板 → 入站列表 → 添加入站:

**主节点 (Reality)**
| 设置 | 值 |
|------|------|
| 协议 | VLESS |
| 监听 | 0.0.0.0 |
| 端口 | 2083 |
| 传输 | TCP |
| 安全 | Reality |
| 目标域名 | www.microsoft.com:443 |
| SNI | www.microsoft.com |
| Flow | xtls-rprx-vision |
| Sniffing | 开启 |

**备用节点 (Reality)**
| 设置 | 值 |
|------|------|
| 协议 | VLESS |
| 端口 | 8443 |
| 目标域名 | addons.mozilla.org:443 |
| SNI | addons.mozilla.org |
| 其余同主节点 | |

**CDN 节点 (WebSocket)**
| 设置 | 值 |
|------|------|
| 协议 | VLESS |
| 监听 | 127.0.0.1 |
| 端口 | 10000 |
| 传输 | WebSocket |
| WS Path | 自动生成 |
| 说明 | 配合 Cloudflare Workers 反代使用 |

#### 5.2 配置 AI 域名路由

在 x-ui 面板 → Xray 设置 → 路由规则:

1. 添加出站 `warp`:
   - 协议: socks
   - 地址: 127.0.0.1
   - 端口: 40000

2. 添加路由规则:
   - 出站: warp
   - 域名:
     ```
     domain:anthropic.com
     domain:claude.ai
     domain:openai.com
     domain:chatgpt.com
     domain:oaistatic.com
     domain:oaiusercontent.com
     domain:gemini.google.com
     domain:generativelanguage.googleapis.com
     domain:ai.google.dev
     domain:bard.google.com
     domain:perplexity.ai
     domain:cursor.sh
     domain:cursor.com
     ```

### 6. 记录配置信息

节点创建后，x-ui 会自动生成 UUID、密钥对、Short ID。

**将这些信息更新到 `.env` 文件中**作为备份，然后回到客户端配置。

## 维护命令

```bash
# 查看 x-ui 状态
systemctl status x-ui

# 查看 Xray 日志
journalctl -u x-ui -f

# 重启 x-ui (会同时重启 Xray)
sudo systemctl restart x-ui

# 查看所有监听端口
ss -tlnp

# 查看 WARP 状态
systemctl status warp-svc

# 测试 WARP 出口 IP
curl --socks5 127.0.0.1:40000 https://ifconfig.me
```

## 更换服务器流程

1. 在新服务器运行 `sudo bash server/install.sh`
2. 在 x-ui 面板中配置节点和路由规则
3. 更新 `.env` 中的 `SERVER_IP` 和新生成的密钥
4. 在 Mac 端运行 `bash client/setup-mac.sh`
5. 手机端更新服务器 IP 和密钥信息
6. Claude Code OAuth Token **不需要重新生成**
