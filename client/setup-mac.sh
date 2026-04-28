#!/bin/bash
# Mac 客户端一键配置脚本
# 使用方法: bash client/setup-mac.sh
# 前提: 已安装 Clash Verge

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Mac 客户端配置"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

# 加载环境变量
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}未找到 .env 文件${NC}"
    echo "请先: cp .env.example .env 并填入真实值"
    exit 1
fi
source "$ENV_FILE"

CLASH_DIR="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"

# ===== 1. 检查 Clash Verge 是否安装 =====
echo -e "${GREEN}[1/5] 检查 Clash Verge...${NC}"
if [ ! -d "/Applications/Clash Verge.app" ]; then
    echo -e "${RED}Clash Verge 未安装${NC}"
    echo "请先从 https://github.com/clash-verge-rev/clash-verge-rev/releases 下载安装"
    exit 1
fi
echo "✅ Clash Verge 已安装"

# ===== 2. 生成 Clash 配置 =====
echo -e "${GREEN}[2/5] 生成 Clash 配置...${NC}"

# 备份现有配置
if [ -f "$CLASH_DIR/clash-verge.yaml" ]; then
    cp "$CLASH_DIR/clash-verge.yaml" "$CLASH_DIR/clash-verge.yaml.backup-$(date +%Y%m%d%H%M%S)"
    echo "已备份现有配置"
fi

# 使用 sed 替换模板中的变量
cp "$SCRIPT_DIR/clash-verge.yaml" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${SERVER_IP}|${SERVER_IP}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${MAIN_PORT}|${MAIN_PORT}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${MAIN_UUID}|${MAIN_UUID}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${MAIN_DEST}|${MAIN_DEST}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${MAIN_PUBLIC_KEY}|${MAIN_PUBLIC_KEY}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${MAIN_SHORT_ID}|${MAIN_SHORT_ID}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${BACKUP_PORT}|${BACKUP_PORT}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${BACKUP_UUID}|${BACKUP_UUID}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${BACKUP_DEST}|${BACKUP_DEST}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${BACKUP_PUBLIC_KEY}|${BACKUP_PUBLIC_KEY}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${BACKUP_SHORT_ID}|${BACKUP_SHORT_ID}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${CDN_UUID}|${CDN_UUID}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${CDN_DOMAIN}|${CDN_DOMAIN}|g" /tmp/clash-verge-generated.yaml
sed -i '' "s|\${CDN_WS_PATH}|${CDN_WS_PATH}|g" /tmp/clash-verge-generated.yaml

cp /tmp/clash-verge-generated.yaml "$CLASH_DIR/clash-verge.yaml"
rm /tmp/clash-verge-generated.yaml
echo "✅ Clash 配置已生成"

# ===== 3. 复制 merge.yaml =====
echo -e "${GREEN}[3/5] 配置持久化设置...${NC}"
mkdir -p "$CLASH_DIR/profiles"
cp "$SCRIPT_DIR/merge.yaml" "$CLASH_DIR/profiles/Merge.yaml"
echo "✅ merge.yaml 已部署"

# ===== 4. 配置终端代理 =====
echo -e "${GREEN}[4/5] 配置终端代理...${NC}"

PROXY_PORT="${CLASH_MIXED_PORT:-7897}"

# 检查是否已配置
if grep -q "$PROXY_PORT" ~/.zshrc 2>/dev/null; then
    echo "终端代理已配置，跳过"
else
    cat >> ~/.zshrc << PROXYEOF

# Clash Verge 代理
export https_proxy=http://127.0.0.1:${PROXY_PORT}
export http_proxy=http://127.0.0.1:${PROXY_PORT}
export all_proxy=socks5://127.0.0.1:${PROXY_PORT}
export HTTPS_PROXY=http://127.0.0.1:${PROXY_PORT}
export HTTP_PROXY=http://127.0.0.1:${PROXY_PORT}
export NO_PROXY=localhost,127.0.0.1,::1,*.local

# OpenAI API Key (仅在无法用手机热点登录 Codex 时使用，独立计费)
# https://platform.openai.com/api-keys 生成后取消注释:
# export OPENAI_API_KEY="sk-proj-你的key..."
PROXYEOF
    echo "✅ 已写入 ~/.zshrc"
fi

# ===== 5. 重启 Clash Verge =====
echo -e "${GREEN}[5/5] 重启 Clash Verge...${NC}"
pkill -f verge-mihomo 2>/dev/null || true
pkill -f clash-verge 2>/dev/null || true
sleep 2
open -a "Clash Verge"
echo "等待 10 秒..."
sleep 10

# ===== 验证 =====
echo ""
echo "============================================"
echo "  验证配置"
echo "============================================"
echo ""

echo -n "Clash 端口: "
lsof -i -P 2>/dev/null | grep "$PROXY_PORT" | grep LISTEN > /dev/null && echo -e "${GREEN}✅ $PROXY_PORT 监听中${NC}" || echo -e "${RED}❌ $PROXY_PORT 未监听${NC}"

echo -n "Google: "
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 --proxy "http://127.0.0.1:${PROXY_PORT}" https://www.google.com 2>/dev/null)
[ "$CODE" = "200" ] && echo -e "${GREEN}✅ HTTP $CODE${NC}" || echo -e "${RED}❌ HTTP $CODE${NC}"

echo -n "Claude API: "
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 --proxy "http://127.0.0.1:${PROXY_PORT}" https://api.anthropic.com 2>/dev/null)
[ "$CODE" = "404" ] && echo -e "${GREEN}✅ HTTP $CODE (正常)${NC}" || echo -e "${RED}❌ HTTP $CODE${NC}"

# ===== 6. 配置 Codex =====
echo -e "${GREEN}[6/6] 配置 OpenAI Codex...${NC}"
CODEX_DIR="$HOME/.codex"
CODEX_CONFIG="$CODEX_DIR/config.toml"
if [ -f "$CODEX_CONFIG" ]; then
    echo "Codex 配置已存在，跳过"
else
    mkdir -p "$CODEX_DIR"
    cat > "$CODEX_CONFIG" << 'CODEXEOF'
# Codex 认证配置
# auth.openai.com 被 Cloudflare Challenge 拦截，OAuth 登录会超时
# 推荐: 用手机热点临时登录（使用 ChatGPT 订阅额度，不额外花钱）
# 备选: 设置 OPENAI_API_KEY 环境变量（独立计费）
forced_login_method = "chatgpt"
cli_auth_credentials_store = "file"
CODEXEOF
    echo "✅ Codex 配置已写入 $CODEX_CONFIG"
fi

echo ""
echo "============================================"
echo "  配置完成"
echo "============================================"
echo ""
echo "手动操作提醒:"
echo "1. 在 Clash Verge 设置中安装 Service Mode（点击扳手图标）"
echo "2. 开启虚拟网卡模式（TUN）"
echo "3. 开启系统代理"
echo "4. 开启开机自启"
echo "5. 配置 Claude Code: 参见 docs/claude-code.md"
echo "   运行 'claude setup-token' 生成 OAuth Token 写入 ~/.zshrc"
echo "6. 配置 OpenAI Codex:"
echo "   手机开热点 → 暂停 Clash → 打开 Codex 登录 → 重开 Clash"
echo "   凭证缓存在 ~/.codex/auth.json，后续自动复用"
echo "   详见 docs/claude-code.md"
echo "7. 重启 VS Code"
