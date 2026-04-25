# 常见问题排查

## 问题 1: Clash 代理端口 7897 未监听

**症状:** `lsof -i -P | grep 7897` 无输出

**排查步骤:**

```bash
# 检查 mihomo 进程
ps aux | grep verge-mihomo | grep -v grep

# 检查日志
tail -30 "$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/logs/"*.log
```

**常见原因:**

1. **DNS 端口 53 冲突** — mihomo 无法绑定 53 端口（需 root 权限）
   - 修复: 将 DNS listen 改为 `0.0.0.0:1053`

2. **其他 VPN 占用端口** — 快连等 VPN 可能占用相同端口
   - 修复: 先关闭其他 VPN

3. **配置文件语法错误**
   - 修复: 检查 YAML 格式

---

## 问题 2: TLS handshake eof

**症状:** 日志中出现 `tls handshake eof`

**原因:** 其他 VPN（如快连）劫持了出站路由，Clash 的节点流量被其他 VPN 包裹

**修复:**

在 clash-verge.yaml 中添加:
```yaml
interface-name: en0
```

这强制 Clash 从物理网卡出站，绕过其他 VPN 的虚拟网卡。

---

## 问题 3: TUN 模式不生效

**症状:** 日志中出现 `disable tun`

**原因:** Service Mode 未安装，TUN 需要 root 权限

**修复:**
1. 打开 Clash Verge → 设置
2. 点击"虚拟网卡模式"旁边的扳手图标
3. 安装 Service Mode
4. 开启虚拟网卡模式

---

## 问题 4: VS Code Claude Code ECONNRESET

**症状:** `API Error: Unable to connect to API (ECONNRESET)`

**排查:**

```bash
# 确认代理变量
echo $https_proxy

# 测试 Claude API
curl -I --max-time 10 --proxy http://127.0.0.1:7897 https://api.anthropic.com
```

**修复:**

确保 ~/.zshrc 中有:
```bash
export https_proxy=http://127.0.0.1:7897
export http_proxy=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export HTTP_PROXY=http://127.0.0.1:7897
```

然后重启 VS Code (`Cmd + Q` 后重开)。

---

## 问题 5: Clash Verge 重启后配置被覆盖

**原因:** Clash Verge 每次启动会根据内部设置重新生成 clash-verge.yaml

**修复:** 使用 `profiles/merge.yaml` 持久化关键设置:

```yaml
# profiles/merge.yaml
interface-name: en0
tun:
  enable: true
  stack: gvisor
  auto-route: true
  strict-route: false
  auto-detect-interface: true
  dns-hijack:
    - any:53
dns:
  listen: 0.0.0.0:1053
```

---

## 问题 6: Telegram 显示"连接中"

**原因:** Telegram 使用 MTProto 协议直连 DC 服务器，需要 TUN 模式接管流量

**修复:** 确保 TUN 模式已开启:
```bash
ifconfig | grep "198.18"
```
如果没有输出，参考问题 3 开启 TUN。

---

## 一键诊断命令

```bash
echo -n "Clash端口: "; lsof -i -P | grep 7897 | grep LISTEN | wc -l | tr -d ' ';
echo -n " Claude: "; curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 https://api.anthropic.com;
echo -n "Google: "; curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 https://www.google.com
```

预期输出: `Clash端口: 1 Claude: 404 Google: 200`
