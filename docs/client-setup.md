# 客户端配置指南

## Mac 配置

### 自动配置
```bash
# 1. 填写环境变量
cp .env.example .env
vi .env

# 2. 运行配置脚本
bash client/setup-mac.sh

# 3. 手动操作（脚本会提醒）
#    - Clash Verge 设置 → 安装 Service Mode
#    - 开启虚拟网卡模式
#    - 开启系统代理
#    - 开启开机自启

# 4. 配置 Claude Code（如需使用）
#    参见 docs/claude-code.md
```

---

## iPhone 配置 (Shadowrocket)

1. 打开 Shadowrocket → 右上角 `+`
2. 填写以下信息（值从 `.env` 文件获取）:

### 主节点
```
类型:        VLESS
地址:        .env 中的 SERVER_IP
端口:        .env 中的 MAIN_PORT (默认 2083)
UUID:        .env 中的 MAIN_UUID
加密:        none
传输方式:     tcp
TLS:         开启
Flow:        xtls-rprx-vision
SNI:         .env 中的 MAIN_DEST (默认 www.microsoft.com)
Fingerprint: chrome
Reality:     开启
Public Key:  .env 中的 MAIN_PUBLIC_KEY
Short ID:    .env 中的 MAIN_SHORT_ID
```

3. 保存并连接测试

### 备用节点
```
端口:        .env 中的 BACKUP_PORT (默认 8443)
UUID:        .env 中的 BACKUP_UUID
SNI:         .env 中的 BACKUP_DEST (默认 addons.mozilla.org)
Public Key:  .env 中的 BACKUP_PUBLIC_KEY
Short ID:    .env 中的 BACKUP_SHORT_ID
```
其余设置与主节点相同。

---

## Android 配置 (v2rayNG)

1. 打开 v2rayNG → 右上角 `+` → 手动输入[VLESS]
2. 填写（值从 `.env` 文件获取）:

```
别名:        主节点-Reality
地址:        SERVER_IP
端口:        MAIN_PORT (2083)
用户ID:      MAIN_UUID
Flow:        xtls-rprx-vision
加密方式:     none
传输协议:     tcp
TLS:         reality
SNI:         MAIN_DEST (www.microsoft.com)
Fingerprint: chrome
PublicKey:    MAIN_PUBLIC_KEY
ShortId:     MAIN_SHORT_ID
```

3. 保存 → 右下角连接按钮

---

## Windows 配置 (Clash Verge)

1. 安装 Clash Verge: https://github.com/clash-verge-rev/clash-verge-rev/releases
2. 将 `client/clash-verge.yaml` 中的变量替换为 `.env` 中的实际值
3. 导入配置文件
4. 设置 → 安装 Service Mode → 开启 TUN 模式
5. 开启系统代理

---

## 验证连接

连接后在浏览器中访问:
- https://www.google.com — 应正常打开
- https://myip.ipip.net — 应显示 VPS 的 IP
- https://www.baidu.com — 应正常打开（走直连）
