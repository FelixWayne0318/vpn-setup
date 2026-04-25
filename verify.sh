#!/bin/bash
# verify.sh — One-command full-chain verification / 一键全链路验证
# Usage: bash verify.sh

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local label="$1"
    local status="$2"  # pass / fail / warn
    local detail="$3"

    case "$status" in
        pass)
            echo -e "  ${GREEN}[PASS]${NC} $label — $detail"
            ((PASS++))
            ;;
        fail)
            echo -e "  ${RED}[FAIL]${NC} $label — $detail"
            ((FAIL++))
            ;;
        warn)
            echo -e "  ${YELLOW}[WARN]${NC} $label — $detail"
            ((WARN++))
            ;;
    esac
}

PROXY_PORT="${CLASH_MIXED_PORT:-7897}"

echo ""
echo "============================================"
echo "  VPN + AI Tools Full-Chain Verification"
echo "  VPN + AI 工具全链路验证"
echo "============================================"
echo ""

# ===== 1. Proxy port =====
echo "1. Proxy Port / 代理端口"
if lsof -i -P 2>/dev/null | grep "$PROXY_PORT" | grep LISTEN > /dev/null 2>&1; then
    check "Port $PROXY_PORT" "pass" "listening"
else
    check "Port $PROXY_PORT" "fail" "not listening — is Clash Verge running?"
fi
echo ""

# ===== 2. Proxy connectivity =====
echo "2. Proxy Connectivity / 代理连通性"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --proxy "http://127.0.0.1:${PROXY_PORT}" https://www.google.com 2>/dev/null)
if [ "$CODE" = "200" ]; then
    check "Google via proxy" "pass" "HTTP $CODE"
else
    check "Google via proxy" "fail" "HTTP $CODE"
fi
echo ""

# ===== 3. AI API endpoints =====
echo "3. AI API Endpoints / AI API 端点"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --proxy "http://127.0.0.1:${PROXY_PORT}" https://api.anthropic.com 2>/dev/null)
if [ "$CODE" = "404" ] || [ "$CODE" = "401" ]; then
    check "api.anthropic.com" "pass" "HTTP $CODE (reachable)"
else
    check "api.anthropic.com" "fail" "HTTP $CODE"
fi

CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 --proxy "http://127.0.0.1:${PROXY_PORT}" https://api.openai.com 2>/dev/null)
if [ "$CODE" = "404" ] || [ "$CODE" = "421" ] || [ "$CODE" = "200" ]; then
    check "api.openai.com" "pass" "HTTP $CODE (reachable)"
else
    check "api.openai.com" "fail" "HTTP $CODE"
fi
echo ""

# ===== 4. Claude Code OAuth Token =====
echo "4. Claude Code OAuth Token"
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
    PREFIX=$(echo "$CLAUDE_CODE_OAUTH_TOKEN" | cut -c1-15)
    check "Token loaded" "pass" "$PREFIX..."
else
    check "Token loaded" "fail" "CLAUDE_CODE_OAUTH_TOKEN not set — run: claude setup-token"
fi
echo ""

# ===== 5. Proxy environment variables =====
echo "5. Proxy Env Vars / 代理环境变量"
if [ -n "$HTTPS_PROXY" ] || [ -n "$https_proxy" ]; then
    check "HTTPS_PROXY" "pass" "${HTTPS_PROXY:-$https_proxy}"
else
    check "HTTPS_PROXY" "fail" "not set — add to ~/.zshrc"
fi
echo ""

# ===== 6. Claude Code CLI =====
echo "6. Claude Code CLI"
if command -v claude &> /dev/null; then
    check "claude binary" "pass" "$(which claude)"
    echo -n "  Testing claude -p ... "
    RESULT=$(claude -p "say exactly: VERIFICATION_OK" 2>/dev/null | head -1)
    if echo "$RESULT" | grep -q "VERIFICATION_OK"; then
        echo -e "${GREEN}OK${NC}"
        check "Claude Code response" "pass" "working"
    else
        echo -e "${RED}FAILED${NC}"
        check "Claude Code response" "fail" "no valid response"
    fi
else
    check "claude binary" "warn" "not found in PATH — skip CLI test"
fi
echo ""

# ===== 7. China direct connection =====
echo "7. China Direct / 国内直连"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 https://www.baidu.com 2>/dev/null)
if [ "$CODE" = "200" ]; then
    check "baidu.com (direct)" "pass" "HTTP $CODE"
else
    check "baidu.com (direct)" "warn" "HTTP $CODE — may not be in China"
fi
echo ""

# ===== 8. DNS leak check =====
echo "8. DNS Leak Check / DNS 泄漏检测"
DNS_IP=$(dig +short +time=5 whoami.akamai.net @ns1-1.akamaitech.net 2>/dev/null)
if [ -n "$DNS_IP" ]; then
    check "DNS resolver IP" "pass" "$DNS_IP"
else
    check "DNS resolver" "warn" "could not determine — dig not available or timeout"
fi
echo ""

# ===== Summary =====
echo "============================================"
echo -e "  Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$WARN warnings${NC}"
echo "============================================"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All critical checks passed!${NC}"
else
    echo -e "${RED}Some checks failed. Review the output above.${NC}"
    echo "Docs: docs/claude-code.md | docs/client-setup.md"
fi
echo ""
