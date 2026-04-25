#!/bin/bash
# Xray VLESS Reality 服务器一键安装脚本
# 使用方法: bash install.sh
# 需要 root 权限

set -e

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Xray VLESS Reality 服务器安装"
echo "============================================"

# 检查 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 或 sudo 运行此脚本${NC}"
    exit 1
fi

# 加载环境变量
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}未找到 .env 文件，请先复制 .env.example 并填入真实值${NC}"
    echo "  cp .env.example .env"
    exit 1
fi

source "$ENV_FILE"

# ===== 1. 系统更新 =====
echo -e "${GREEN}[1/6] 更新系统...${NC}"
apt update && apt upgrade -y

# ===== 2. 安装依赖 =====
echo -e "${GREEN}[2/6] 安装依赖...${NC}"
apt install -y curl wget unzip jq

# ===== 3. 安装 Xray =====
echo -e "${GREEN}[3/6] 安装 Xray...${NC}"
XRAY_DIR="/opt/xray"
mkdir -p "$XRAY_DIR"

# 下载最新版 Xray
XRAY_VERSION=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r .tag_name)
echo "安装 Xray $XRAY_VERSION"
wget -q "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" -O /tmp/xray.zip
unzip -o /tmp/xray.zip -d "$XRAY_DIR"
chmod +x "$XRAY_DIR/xray"
rm /tmp/xray.zip

# ===== 4. 生成配置 =====
echo -e "${GREEN}[4/6] 生成 Xray 配置...${NC}"
mkdir -p /usr/local/etc/xray

# 如果没有提供密钥，生成新的 Reality 密钥对
if [ "$MAIN_PRIVATE_KEY" = "你的私钥" ] || [ -z "$MAIN_PRIVATE_KEY" ]; then
    echo "生成 Reality 密钥对..."
    KEYS=$("$XRAY_DIR/xray" x25519)
    MAIN_PRIVATE_KEY=$(echo "$KEYS" | grep "Private" | awk '{print $3}')
    MAIN_PUBLIC_KEY=$(echo "$KEYS" | grep "Public" | awk '{print $3}')
    echo -e "${YELLOW}主节点私钥: $MAIN_PRIVATE_KEY${NC}"
    echo -e "${YELLOW}主节点公钥: $MAIN_PUBLIC_KEY${NC}"
    echo -e "${YELLOW}请记录以上密钥并更新 .env 文件${NC}"
fi

if [ "$BACKUP_PRIVATE_KEY" = "你的私钥" ] || [ -z "$BACKUP_PRIVATE_KEY" ]; then
    KEYS2=$("$XRAY_DIR/xray" x25519)
    BACKUP_PRIVATE_KEY=$(echo "$KEYS2" | grep "Private" | awk '{print $3}')
    BACKUP_PUBLIC_KEY=$(echo "$KEYS2" | grep "Public" | awk '{print $3}')
    echo -e "${YELLOW}备用节点私钥: $BACKUP_PRIVATE_KEY${NC}"
    echo -e "${YELLOW}备用节点公钥: $BACKUP_PUBLIC_KEY${NC}"
fi

# 生成 UUID（如果没有提供）
if [ "$MAIN_UUID" = "你的UUID" ] || [ -z "$MAIN_UUID" ]; then
    MAIN_UUID=$("$XRAY_DIR/xray" uuid)
    echo -e "${YELLOW}主节点 UUID: $MAIN_UUID${NC}"
fi

if [ "$BACKUP_UUID" = "你的UUID" ] || [ -z "$BACKUP_UUID" ]; then
    BACKUP_UUID=$("$XRAY_DIR/xray" uuid)
    echo -e "${YELLOW}备用节点 UUID: $BACKUP_UUID${NC}"
fi

# 生成 Short ID
if [ "$MAIN_SHORT_ID" = "你的shortid" ] || [ -z "$MAIN_SHORT_ID" ]; then
    MAIN_SHORT_ID=$(openssl rand -hex 4)
    echo -e "${YELLOW}主节点 Short ID: $MAIN_SHORT_ID${NC}"
fi

if [ "$BACKUP_SHORT_ID" = "你的shortid" ] || [ -z "$BACKUP_SHORT_ID" ]; then
    BACKUP_SHORT_ID=$(openssl rand -hex 4)
    echo -e "${YELLOW}备用节点 Short ID: $BACKUP_SHORT_ID${NC}"
fi

# 写入 Xray 配置
cat > /usr/local/etc/xray/config.json << XRAYEOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "reality-2083",
      "listen": "0.0.0.0",
      "port": ${MAIN_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${MAIN_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${MAIN_DEST}:443",
          "serverNames": ["${MAIN_DEST}"],
          "privateKey": "${MAIN_PRIVATE_KEY}",
          "shortIds": ["${MAIN_SHORT_ID}"]
        }
      }
    },
    {
      "tag": "reality-8443",
      "listen": "0.0.0.0",
      "port": ${BACKUP_PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${BACKUP_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${BACKUP_DEST}:443",
          "serverNames": ["${BACKUP_DEST}"],
          "privateKey": "${BACKUP_PRIVATE_KEY}",
          "shortIds": ["${BACKUP_SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
XRAYEOF

echo "Xray 配置已写入 /usr/local/etc/xray/config.json"

# ===== 5. 配置 systemd 服务 =====
echo -e "${GREEN}[5/6] 配置 systemd 服务...${NC}"
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

# ===== 6. 配置防火墙 =====
echo -e "${GREEN}[6/6] 配置防火墙...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw allow ${MAIN_PORT}/tcp comment 'Xray Reality Main'
ufw allow ${BACKUP_PORT}/tcp comment 'Xray Reality Backup'
ufw allow 443/tcp comment 'HTTPS/CDN'
ufw allow 80/tcp comment 'HTTP'
ufw --force enable

# ===== 验证 =====
echo ""
echo "============================================"
echo "  安装完成，验证中..."
echo "============================================"
echo ""

sleep 2

echo -n "Xray 进程: "
pgrep -x xray > /dev/null && echo -e "${GREEN}✅ 运行中${NC}" || echo -e "${RED}❌ 未运行${NC}"

echo -n "端口 ${MAIN_PORT}: "
ss -tlnp | grep -q ":${MAIN_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

echo -n "端口 ${BACKUP_PORT}: "
ss -tlnp | grep -q ":${BACKUP_PORT}" && echo -e "${GREEN}✅ 监听中${NC}" || echo -e "${RED}❌ 未监听${NC}"

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
echo -e "${YELLOW}请将以上信息更新到 .env 文件和客户端配置中${NC}"
