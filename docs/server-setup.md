# 服务器部署指南

## 前提条件

- 一台海外 VPS（推荐 Vultr、Bandwagon、DigitalOcean）
- Ubuntu 22.04+
- 至少 1 核 1G 内存
- SSH 访问权限

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

### 4. 上传项目文件

在本地执行:
```bash
scp -r vpn-setup/ linuxuser@你的服务器IP:~/
```

### 5. 配置环境变量

在服务器上:
```bash
cd ~/vpn-setup
cp .env.example .env
vi .env
# 填入服务器 IP，其他值留空让脚本自动生成
```

### 6. 运行安装脚本

```bash
sudo bash server/install.sh
```

脚本会自动:
- 安装 Xray (VLESS Reality 双节点 + CDN WS 节点)
- 安装 Cloudflare WARP (AI 域名走干净 IP)
- 生成 UUID、Reality 密钥对、Short ID
- 配置 AI 域名路由规则 (Claude/OpenAI/Gemini)
- 配置防火墙 (UFW)
- 启动 Xray + WARP 服务

### 7. 记录输出信息

安装完成后会输出:
- 主节点 UUID、公钥、Short ID
- 备用节点 UUID、公钥、Short ID
- CDN 节点 UUID、WS Path
- WARP 出口 IP
- 服务器 IP

**将这些信息更新到 .env 文件中**，然后回到客户端配置。

## 维护命令

```bash
# 查看 Xray 状态
systemctl status xray

# 查看日志
journalctl -u xray -f

# 重启 Xray
sudo systemctl restart xray

# 查看连接数
ss -tnp | grep xray-linux | wc -l

# 查看 WARP 状态
systemctl status warp-svc

# 测试 WARP 出口
curl --socks5 127.0.0.1:40000 https://ifconfig.me
```

## 更换服务器流程

1. 在新服务器运行 `sudo bash server/install.sh`
2. 更新 `.env` 中的 `SERVER_IP` 和新生成的密钥
3. 在 Mac 端运行 `bash client/setup-mac.sh`
4. 手机端更新服务器 IP 和密钥信息
5. Claude Code OAuth Token **不需要重新生成**
