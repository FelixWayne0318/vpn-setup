# 自建 VPN 完整部署指南

## 项目说明

基于 Xray VLESS Reality 协议的自建 VPN，客户端使用 Clash Verge (mihomo)。
支持从零开始在新服务器和新 Mac 上完整部署。

## 架构

```
Mac (Clash Verge + TUN) → VPS (Xray VLESS Reality) → 互联网
                        ↗ CDN节点 (Cloudflare Workers)
```

## 目录结构

```
vpn-setup/
├── README.md                          # 本文件
├── .gitignore                         # 忽略敏感文件
├── .env.example                       # 环境变量模板（不含真实值）
├── .env                               # 真实环境变量（不上传）
│
├── server/                            # 服务端配置
│   ├── install.sh                     # 一键安装脚本
│   ├── xray-config.json               # Xray 配置模板
│   ├── ufw-rules.sh                   # 防火墙规则
│   └── systemd/
│       └── xray.service               # systemd 服务文件
│
├── client/                            # 客户端配置
│   ├── clash-verge.yaml               # Clash Verge 主配置
│   ├── merge.yaml                     # 持久化配置（防覆盖）
│   └── setup-mac.sh                   # Mac 一键配置脚本
│
└── docs/
    ├── server-setup.md                # 服务器部署详细步骤
    ├── client-setup.md                # 客户端配置详细步骤
    ├── troubleshooting.md             # 常见问题排查
    └── changes-log.md                 # 本次修复记录
```

## 快速开始

### 1. 服务器部署
```bash
# 复制 .env.example 为 .env，填入真实值
cp .env.example .env
vi .env

# 执行安装
bash server/install.sh
```

### 2. 客户端配置
```bash
# Mac 一键配置
bash client/setup-mac.sh
```

### 3. 手机配置
参见 docs/client-setup.md 中的手机章节

---

## 本次修复记录 (2026-04-25)

### 修改的文件和设置

#### 1. Clash Verge 配置 (clash-verge.yaml)
- DNS 监听端口: `0.0.0.0:53` → `0.0.0.0:1053` (避免权限冲突)
- 新增: `interface-name: en0` (强制物理网卡出站，绕过其他 VPN 干扰)
- TUN 模式: `enable: false` → `enable: true` (全局透明代理)

#### 2. 新建 merge.yaml
- 持久化 `interface-name` 和 DNS 端口设置
- 防止 Clash Verge 重启时覆盖配置

#### 3. ~/.zshrc 代理变量
- 添加 https_proxy / http_proxy / HTTPS_PROXY / HTTP_PROXY
- 指向 127.0.0.1:7897

#### 4. Clash Verge 界面操作
- 安装 Service Mode（服务模式）
- 开启虚拟网卡模式（TUN）
- 开启系统代理
- 开启开机自启

#### 5. 服务器端
- 未做任何修改，服务器配置完全正常
