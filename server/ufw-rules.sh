#!/bin/bash
# UFW 防火墙规则配置
# 使用方法: sudo bash ufw-rules.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../.env"

ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS/CDN'
ufw allow ${MAIN_PORT}/tcp comment 'Xray Reality Main'
ufw allow ${BACKUP_PORT}/tcp comment 'Xray Reality Backup'
ufw --force enable
ufw status verbose
