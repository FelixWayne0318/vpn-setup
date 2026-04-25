#!/bin/bash
# Xray VLESS Reality + WARP 服务器一键安装脚本
# 使用方法: sudo bash server/install.sh
# 需要 root 权限，Ubuntu 22.04+
#
# 功能:
#   - Xray VLESS Reality 双节点 (主+备)
#   - CDN WebSocket 节点 (Cloudflare 中转)
#   - Cloudflare WARP socks5 代理 (AI 域名解锁)
#   - AI 域名路由规则 (Claude/OpenAI/Gemini 走 WARP)
#   - 流量统计 + Sniffing

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Xray VLESS Reality + WARP 一键安装"
echo "============================================"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 或 sudo 运行此脚本${NC}"
    exit 1
fi

# Load .env
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}未找到 .env 文件，请先复制 .env.example 并填入真实值${NC}"
    echo "  cp .env.example .env"
    exit 1
fi

source "$ENV_FILE"

# Defaults
WARP_SOCKS_PORT="${WARP_SOCKS_PORT:-40000}"
CDN_WS_PORT="${CDN_WS_PORT:-10000}"
CDN_WS_PATH="${CDN_WS_PATH:-/$(openssl rand -hex 8)}"

# ===== 1. System update =====
echo -e "${GREEN}[1/8] 更新系统...${NC}"
apt update && apt upgrade -y

# ===== 2. Install dependencies =====
echo -e "${GREEN}[2/8] 安装依赖...${NC}"
apt install -y curl wget unzip jq gnupg lsb-release

# ===== 3. Install Xray =====
echo -e "${GREEN}[3/8] 安装 Xray...${NC}"
XRAY_DIR="/opt/xray"
mkdir -p "$XRAY_DIR"

XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
echo "安装 Xray $XRAY_VERSION"
wget -q "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" -O /tmp/xray.zip
unzip -o /tmp/xray.zip -d "$XRAY_DIR"
chmod +x "$XRAY_DIR/xray"
rm /tmp/xray.zip

# ===== 4. Generate keys if needed =====
echo -e "${GREEN}[4/8] 生成密钥...${NC}"

if [ "$MAIN_PRIVATE_KEY" = "你的私钥" ] || [ -z "$MAIN_PRIVATE_KEY" ]; then
    KEYS=$("$XRAY_DIR/xray" x25519)
    MAIN_PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
    MAIN_PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')
    echo -e "${YELLOW}主节点私钥: $MAIN_PRIVATE_KEY${NC}"
    echo -e "${YELLOW}主节点公钥: $MAIN_PUBLIC_KEY${NC}"
fi

if [ "$BACKUP_PRIVATE_KEY" = "你的私钥" ] || [ -z "$BACKUP_PRIVATE_KEY" ]; then
    KEYS2=$("$XRAY_DIR/xray" x25519)
    BACKUP_PRIVATE_KEY=$(echo "$KEYS2" | grep "Private" | awk '{print $3}')
    BACKUP_PUBLIC_KEY=$(echo "$KEYS2" | grep "Public" | awk '{print $3}')
    echo -e "${YELLOW}备用节点私钥: $BACKUP_PRIVATE_KEY${NC}"
    echo -e "${YELLOW}备用节点公钥: $BACKUP_PUBLIC_KEY${NC}"
fi

if [ "$MAIN_UUID" = "你的UUID" ] || [ -z "$MAIN_UUID" ]; then
    MAIN_UUID=$("$XRAY_DIR/xray" uuid)
    echo -e "${YELLOW}主节点 UUID: $MAIN_UUID${NC}"
fi

if [ "$BACKUP_UUID" = "你的UUID" ] || [ -z "$BACKUP_UUID" ]; then
    BACKUP_UUID=$("$XRAY_DIR/xray" uuid)
    echo -e "${YELLOW}备用节点 UUID: $BACKUP_UUID${NC}"
fi

if [ "$CDN_UUID" = "你的UUID" ] || [ -z "$CDN_UUID" ]; then
    CDN_UUID=$("$XRAY_DIR/xray" uuid)
    echo -e "${YELLOW}CDN 节点 UUID: $CDN_UUID${NC}"
fi

if [ "$MAIN_SHORT_ID" = "你的shortid" ] || [ -z "$MAIN_SHORT_ID" ]; then
    MAIN_SHORT_ID=$(openssl rand -hex 4)
    echo -e "${YELLOW}主节点 Short ID: $MAIN_SHORT_ID${NC}"
fi

if [ "$BACKUP_SHORT_ID" = "你的shortid" ] || [ -z "$BACKUP_SHORT_ID" ]; then
    BACKUP_SHORT_ID=$(openssl rand -hex 4)
    echo -e "${YELLOW}备用节点 Short ID: $BACKUP_SHORT_ID${NC}"
fi

# ===== 5. Install Cloudflare WARP =====
echo -e "${GREEN}[5/8] 安装 Cloudflare WARP...${NC}"

if ! command -v warp-cli &> /dev/null; then
    # Add Cloudflare GPG key and repo
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/cloudflare-client.list
    apt update
    apt install -y cloudflare-warp

    # Register and set proxy mode
    echo -e "${YELLOW}注册 WARP...${NC}"
    warp-cli registration new
    warp-cli mode proxy
    warp-cli proxy port ${WARP_SOCKS_PORT}
    warp-cli connect

    echo "等待 WARP 启动..."
    sleep 5
else
    echo "WARP 已安装，跳过"
fi

# Verify WARP
echo -n "WARP socks5 代理: "
if ss -tlnp | grep -q ":${WARP_SOCKS_PORT}"; then
    echo -e "${GREEN}✅ 127.0.0.1:${WARP_SOCKS_PORT} 监听中${NC}"
else
    echo -e "${RED}❌ 未监听，请检查 warp-cli status${NC}"
fi

# ===== 6. Write Xray config =====
echo -e "${GREEN}[6/8] 生成 Xray 配置...${NC}"
mkdir -p /usr/local/etc/xray

cat > /usr/local/etc/xray/config.json << XRAYEOF
{
  "log": {
    "access": "none",
    "dnsLog": false,
    "loglevel": "warning"
  },
  "api": {
    "tag": "api",
    "services": ["HandlerService", "LoggerService", "StatsService"]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true,
      "statsOutboundDownlink": false,
      "statsOutboundUplink": false
    }
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "outboundTag": "warp",
        "domain": [
          "domain:anthropic.com",
          "domain:claude.ai",
          "domain:openai.com",
          "domain:chatgpt.com",
          "domain:oaistatic.com",
          "domain:oaiusercontent.com",
          "domain:gemini.google.com",
          "domain:generativelanguage.googleapis.com",
          "domain:ai.google.dev",
          "domain:bard.google.com",
          "domain:perplexity.ai",
          "domain:cursor.sh",
          "domain:cursor.com"
        ]
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "ip": ["geoip:private"]
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      }
    ]
  },
  "inbounds": [
    {
      "tag": "api",
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "tunnel",
      "settings": {
        "address": "127.0.0.1"
      }
    },
    {
      "tag": "inbound-${MAIN_PORT}",
      "listen": "0.0.0.0",
      "port": ${MAIN_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${MAIN_UUID}",
            "email": "user-main",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "tcpSettings": {
          "acceptProxyProtocol": false,
          "header": { "type": "none" }
        },
        "realitySettings": {
          "show": false,
          "dest": "${MAIN_DEST}:443",
          "xver": 0,
          "serverNames": ["${MAIN_DEST}"],
          "privateKey": "${MAIN_PRIVATE_KEY}",
          "shortIds": ["${MAIN_SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "metadataOnly": false,
        "routeOnly": false
      }
    },
    {
      "tag": "inbound-${BACKUP_PORT}",
      "listen": "0.0.0.0",
      "port": ${BACKUP_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${BACKUP_UUID}",
            "email": "user-backup",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "tcpSettings": {
          "acceptProxyProtocol": false,
          "header": { "type": "none" }
        },
        "realitySettings": {
          "show": false,
          "dest": "${BACKUP_DEST}:443",
          "xver": 0,
          "serverNames": ["${BACKUP_DEST}"],
          "privateKey": "${BACKUP_PRIVATE_KEY}",
          "shortIds": ["${BACKUP_SHORT_ID}"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "metadataOnly": false,
        "routeOnly": false
      }
    },
    {
      "tag": "inbound-cdn-ws",
      "listen": "127.0.0.1",
      "port": ${CDN_WS_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${CDN_UUID}",
            "email": "user-cdn",
            "flow": ""
          }
        ],
        "decryption": "none",
        "fallbacks": []
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "headers": {},
          "path": "${CDN_WS_PATH}"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "metadataOnly": false
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "AsIs"
      }
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    },
    {
      "tag": "warp",
      "protocol": "socks",
      "settings": {
        "servers": [
          {
            "address": "127.0.0.1",
            "port": ${WARP_SOCKS_PORT}
          }
        ]
      }
    }
  ],
  "metrics": {
    "tag": "metrics_out",
    "listen": "127.0.0.1:11111"
  }
}
XRAYEOF

echo "Xray 配置已写入 /usr/local/etc/xray/config.json"

# ===== 7. Configure systemd =====
echo -e "${GREEN}[7/8] 配置 systemd 服务...${NC}"
cat > /etc/systemd/system/xray.service << 'SERVICEEOF'
[Unit]
Description=Xray Service
Documentation=https://xtls.github.io/
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/opt/xray/xray -c /usr/local/etc/xray/config.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ===== 8. Configure firewall =====
echo -e "${GREEN}[8/8] 配置防火墙...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw allow ${MAIN_PORT}/tcp comment 'Xray Reality Main'
ufw allow ${BACKUP_PORT}/tcp comment 'Xray Reality Backup'
ufw allow 443/tcp comment 'HTTPS/CDN'
ufw allow 80/tcp comment 'HTTP'
ufw --force enable

# ===== Verify =====
echo ""
echo "============================================"
echo "  安装完成，验证中..."
echo "============================================"
echo ""

sleep 2

echo -n "Xray 进程: "
pgrep -x xray > /dev/null && echo -e "${GREEN}✅ 运行中${NC}" || echo -e "${RED}❌ 未运行${NC}"

echo -n "端口 ${MAIN_PORT} (Reality 主): "
ss -tlnp | grep -q ":${MAIN_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

echo -n "端口 ${BACKUP_PORT} (Reality 备): "
ss -tlnp | grep -q ":${BACKUP_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

echo -n "端口 ${CDN_WS_PORT} (CDN WS): "
ss -tlnp | grep -q ":${CDN_WS_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

echo -n "WARP socks5 (${WARP_SOCKS_PORT}): "
ss -tlnp | grep -q ":${WARP_SOCKS_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

echo -n "WARP 出口 IP: "
WARP_IP=$(curl -s --socks5 127.0.0.1:${WARP_SOCKS_PORT} https://ifconfig.me 2>/dev/null)
if [ -n "$WARP_IP" ]; then
    echo -e "${GREEN}${WARP_IP}${NC}"
else
    echo -e "${RED}获取失败${NC}"
fi

echo ""
echo "============================================"
echo "  客户端配置信息"
echo "============================================"
echo ""
echo "服务器 IP: $(curl -s ifconfig.me)"
echo ""
echo "主节点 Reality:"
echo "  端口: ${MAIN_PORT}"
echo "  UUID: ${MAIN_UUID}"
echo "  公钥: ${MAIN_PUBLIC_KEY}"
echo "  Short ID: ${MAIN_SHORT_ID}"
echo "  SNI: ${MAIN_DEST}"
echo ""
echo "备用节点 Reality:"
echo "  端口: ${BACKUP_PORT}"
echo "  UUID: ${BACKUP_UUID}"
echo "  公钥: ${BACKUP_PUBLIC_KEY}"
echo "  Short ID: ${BACKUP_SHORT_ID}"
echo "  SNI: ${BACKUP_DEST}"
echo ""
echo "CDN 节点 (WebSocket):"
echo "  本地端口: ${CDN_WS_PORT}"
echo "  UUID: ${CDN_UUID}"
echo "  WS Path: ${CDN_WS_PATH}"
echo "  说明: 需配合 Cloudflare Workers 反代使用"
echo ""
echo "WARP AI 域名解锁:"
echo "  socks5 端口: ${WARP_SOCKS_PORT}"
echo "  出口 IP: ${WARP_IP:-N/A}"
echo "  路由域名: anthropic.com, openai.com, gemini.google.com 等"
echo ""
echo -e "${YELLOW}请将以上信息更新到 .env 文件和客户端配置中${NC}"
