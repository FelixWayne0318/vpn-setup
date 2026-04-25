# 修复记录 2026-04-25

## 背景
升级到 Claude Opus 4.7 后，VS Code 中 Claude Code 插件报错 `API Error: Unable to connect to API (ECONNRESET)`。

## 根本原因分析

### 原因 1: Clash DNS 端口冲突
- Clash 配置 DNS 监听 `0.0.0.0:53`
- 端口 53 需要 root 权限（<1024 的端口），且被快连 VPN 占用
- 导致 mihomo 内核整体启动失败，代理端口 7897 无法监听

### 原因 2: 快连 VPN 劫持出站路由
- 快连通过虚拟网卡 `utun6` (IP `26.26.26.1`) 接管了默认路由
- Clash 的节点连接也被快连隧道包裹
- VLESS Reality 的 TLS 握手被破坏，出现 `tls handshake eof`

### 原因 3: 终端代理未配置
- 终端和 VS Code 不读系统代理，需要环境变量
- `~/.zshrc` 中未设置 `https_proxy`

### 原因 4: TUN 模式未启用
- Clash 只开了 HTTP 系统代理
- Telegram 等使用自有协议的应用无法走 HTTP 代理
- 需要 TUN 模式接管全部流量

## 修复措施

| 序号 | 修改位置 | 修改内容 | 原值 | 新值 |
|------|----------|----------|------|------|
| 1 | clash-verge.yaml | DNS 监听端口 | `0.0.0.0:53` | `0.0.0.0:1053` |
| 2 | clash-verge.yaml | 出站网卡绑定 | (无) | `interface-name: en0` |
| 3 | clash-verge.yaml | TUN 模式 | `enable: false` | `enable: true` |
| 4 | profiles/merge.yaml | 持久化配置 | (文件不存在) | 新建 |
| 5 | ~/.zshrc | 代理环境变量 | (未设置小写) | 添加 https_proxy 等 |
| 6 | Clash Verge 界面 | Service Mode | 未安装 | 已安装 |
| 7 | Clash Verge 界面 | 虚拟网卡模式 | 关闭 | 开启 |

## 服务器端
未做任何修改。经检查确认:
- Xray 进程正常运行
- 端口 2083/8443/443 全部正常监听
- 防火墙规则正确
- 系统负载正常 (0.07)
- 已运行 56 天无重启

## 验证结果

### 连通性测试 (全部通过)
- Claude API: 404 ✅
- Google: 200 ✅
- YouTube: 200 ✅
- GitHub: 200 ✅
- Twitter: 200 ✅
- Instagram: 200 ✅
- Facebook: 200 ✅
- Telegram DC: succeeded ✅
- Netflix: 200 ✅
- 百度(直连): 200 ✅
- 淘宝(直连): 200 ✅

### 分流验证
- 国内流量出口 IP: 117.173.246.171 (成都移动) → 直连 ✅
- 国外流量出口 IP: 139.180.157.152 (新加坡 VPS) → 代理 ✅

### 稳定性
- 20 次连续 Google 请求: 100% 成功率

### 隐私
- 无 DNS 泄漏
- 无 IPv6 泄漏
- TLS 1.3 加密
