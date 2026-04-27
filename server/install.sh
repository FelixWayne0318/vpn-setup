#!/bin/bash
# x-ui + WARP 服务器一键安装脚本
# 使用方法: sudo bash server/install.sh
# 需要 root 权限，Ubuntu 22.04+
#
# 功能:
#   - 3x-ui 面板 (内置 Xray，Web 管理界面)
#   - VLESS Reality 双节点 (主+备)
#   - CDN WebSocket 节点 (Cloudflare 中转)
#   - Cloudflare WARP socks5 代理 (AI 域名解锁)
#   - AI 域名路由规则 (Claude/OpenAI/Gemini 走 WARP)

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  x-ui + WARP 一键安装"
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
XUI_PORT="${XUI_PORT:-2096}"

# ===== 1. System update =====
echo -e "${GREEN}[1/6] 更新系统...${NC}"
apt update && apt upgrade -y

# ===== 2. Install dependencies =====
echo -e "${GREEN}[2/6] 安装依赖...${NC}"
apt install -y curl wget unzip jq gnupg lsb-release

# ===== 3. Install 3x-ui =====
echo -e "${GREEN}[3/6] 安装 3x-ui 面板...${NC}"

if [ -f /usr/local/x-ui/x-ui ]; then
    echo "x-ui 已安装，跳过"
else
    echo -e "${YELLOW}开始安装 3x-ui...${NC}"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
    echo -e "${GREEN}x-ui 安装完成${NC}"
fi

# ===== 4. Install Cloudflare WARP =====
echo -e "${GREEN}[4/6] 安装 Cloudflare WARP...${NC}"

if command -v warp-cli &> /dev/null; then
    echo "WARP 已安装，跳过"
else
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
fi

# Verify WARP
echo -n "WARP socks5 代理: "
if ss -tlnp | grep -q ":${WARP_SOCKS_PORT}"; then
    echo -e "${GREEN}✅ 127.0.0.1:${WARP_SOCKS_PORT} 监听中${NC}"
else
    echo -e "${RED}❌ 未监听，请检查 warp-cli status${NC}"
fi

# ===== 5. Configure firewall =====
echo -e "${GREEN}[5/6] 配置防火墙...${NC}"
ufw allow 22/tcp comment 'SSH'
ufw allow ${SSH_PORT:-22}/tcp comment 'SSH custom'
ufw allow ${MAIN_PORT}/tcp comment 'Xray Reality Main'
ufw allow ${BACKUP_PORT}/tcp comment 'Xray Reality Backup'
ufw allow 443/tcp comment 'HTTPS/CDN'
ufw allow 80/tcp comment 'HTTP'
ufw allow ${XUI_PORT}/tcp comment 'x-ui panel'
ufw --force enable

# ===== 6. Post-install instructions =====
echo -e "${GREEN}[6/6] 安装完成${NC}"

echo ""
echo "============================================"
echo "  安装完成，验证中..."
echo "============================================"
echo ""

sleep 2

echo -n "x-ui 进程: "
systemctl is-active x-ui > /dev/null 2>&1 && echo -e "${GREEN}✅ 运行中${NC}" || echo -e "${RED}❌ 未运行${NC}"

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
echo "  后续配置步骤"
echo "============================================"
echo ""
echo "1. 访问 x-ui 面板:"
echo "   http://${SERVER_IP}:${XUI_PORT}"
echo ""
echo "2. 在面板中添加节点:"
echo "   - 主节点: VLESS + Reality, 端口 ${MAIN_PORT}, SNI ${MAIN_DEST}"
echo "   - 备用节点: VLESS + Reality, 端口 ${BACKUP_PORT}, SNI ${BACKUP_DEST}"
echo "   - CDN 节点: VLESS + WS, 端口 ${CDN_WS_PORT}, 监听 127.0.0.1"
echo ""
echo "3. 在面板 Xray 设置中配置路由规则:"
echo "   - AI 域名 (anthropic.com, openai.com 等) → warp 出站"
echo "   - warp 出站: socks5 → 127.0.0.1:${WARP_SOCKS_PORT}"
echo ""
echo "4. 详细步骤参见: docs/server-setup.md"
echo ""
echo -e "${YELLOW}提示: UUID、密钥等信息在 x-ui 面板中自动生成，${NC}"
echo -e "${YELLOW}生成后请更新 .env 文件作为备份。${NC}"
