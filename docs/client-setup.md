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
```

---

## iPhone 配置 (Shadowrocket)

1. 打开 Shadowrocket → 右上角 `+`
2. 填写以下信息:

```
类型:        VLESS
地址:        你的服务器IP
端口:        2083
UUID:        （主节点 UUID）
加密:        none
传输方式:     tcp
TLS:         开启
Flow:        xtls-rprx-vision
SNI:         www.microsoft.com
Fingerprint: chrome
Reality:     开启
Public Key:  （主节点公钥）
Short ID:    （主节点 Short ID）
```

3. 保存并连接测试

### 备用节点配置
```
端口:        8443
UUID:        （备用节点 UUID）
SNI:         addons.mozilla.org
Public Key:  （备用节点公钥）
Short ID:    （备用节点 Short ID）
```
其余设置相同。

---

## Android 配置 (v2rayNG)

1. 打开 v2rayNG → 右上角 `+` → 手动输入[VLESS]
2. 填写:

```
别名:        主节点-Reality
地址:        你的服务器IP
端口:        2083
用户ID:      （主节点 UUID）
Flow:        xtls-rprx-vision
加密方式:     none
传输协议:     tcp
TLS:         reality
SNI:         www.microsoft.com
Fingerprint: chrome
PublicKey:    （主节点公钥）
ShortId:     （主节点 Short ID）
```

3. 保存 → 右下角连接按钮

---

## Windows 配置 (Clash Verge)

1. 安装 Clash Verge: https://github.com/clash-verge-rev/clash-verge-rev/releases
2. 将 `client/clash-verge.yaml` 中的变量替换为实际值
3. 导入配置文件
4. 设置 → 安装 Service Mode → 开启 TUN 模式
5. 开启系统代理

---

## 验证连接

连接后在浏览器中访问:
- https://www.google.com — 应正常打开
- https://myip.ipip.net — 应显示 VPS 的 IP
- https://www.baidu.com — 应正常打开（走直连）
