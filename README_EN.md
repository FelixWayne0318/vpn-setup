# vpn-setup — Self-hosted VPN for AI Coding Tools

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/FelixWayne0318/vpn-setup?style=social)](https://github.com/FelixWayne0318/vpn-setup/stargazers)

[中文文档](README.md) | English

**One-click VLESS Reality VPN deployment. Fix Claude Code / Cursor / Windsurf / GitHub Copilot connection issues.**

> For developers in China, Iran, Russia, Turkey, and other censored regions — and anyone globally who gets 403 errors on AI tools after self-hosting a VPN on a VPS.

> If this project helped you, please Star it so more developers can find it.

## What Problem Does This Solve?

If you access AI coding tools through a VPN or proxy, you've probably hit these walls:

### Scenario 1: Browser works, but AI coding tools don't

You open claude.ai and chatgpt.com in your browser just fine, but every IDE-based tool fails:

| Tool | Symptom |
|------|---------|
| **VS Code** + Claude Code | `ECONNRESET` / `403 Request not allowed` |
| **VS Code** + GitHub Copilot | Connection failure / frequent drops |
| **Windsurf (Antigravity)** | Claude plugin connection failed |
| **Cursor** | Claude/GPT API timeout or 403 |
| **Terminal** `claude` CLI | Errors out |
| **Cline / Continue.dev** | Cannot connect to API |
| **Aider** | Connection refused |

The pattern: **Browser works fine. IDE tools all broken. VPN doesn't help.**

### Scenario 2: Works after login, breaks after a few hours

- First login to Claude Code works perfectly
- A few hours later: sudden 403, restarting VS Code doesn't help
- Re-login works, but breaks again in hours
- Endless cycle, impossible to work reliably

### Scenario 3: Self-hosted VPN, AI tools still 403

- You set up Xray/V2Ray, general browsing works fine
- Google, YouTube, Twitter — all accessible
- But Claude Code / Cursor returns 403
- Tried Vultr, AWS, DigitalOcean — all 403
- Tried WARP, changed IPs, changed DNS — nothing works

### Scenario 4: Commercial VPNs are unreliable

- VPN services drop frequently mid-coding session
- Context lost, have to start over
- Critical moments without access, workflow depends on an uncontrollable third party

---

## Root Causes (rarely explained clearly)

These scenarios stem from **three independent problems stacking up** — all three must be solved:

### Problem 1: Node.js ignores system proxy

All AI coding tools (Claude Code, Cursor, Windsurf, Copilot, Cline, Aider) run on Node.js or similar runtimes. Node.js **completely ignores macOS/Windows system proxy settings**.

Your VPN works for the browser, but the AI plugins in your IDE **never go through the VPN** — their requests go direct.

### Problem 2: Data center IPs get Cloudflare Challenged

Even with proxy working, your VPS (Vultr/AWS/DO) exit IP is a data center IP. Cloudflare returns JavaScript Challenges (403) for these IPs. Browsers can execute JS Challenges automatically; Node.js cannot.

| Endpoint | Cloudflare Challenge | Data Center IP Result |
|----------|---------------------|----------------------|
| `api.anthropic.com` | No | Works |
| `api.openai.com` | No | Works |
| `claude.ai` | **Yes** | **403** (Node.js can't pass) |
| `chatgpt.com` | **Yes** | **403** (Node.js can't pass) |
| `platform.claude.com` | **Yes** | **403** (Node.js can't pass) |

### Problem 3: OAuth Session expiry

Claude Code obtains a short-lived OAuth Session (~16 hours), stored in macOS Keychain. When it expires, auto-refresh hits `claude.ai` → Cloudflare Challenge → 403.

**This is why "it works after login but breaks hours later."**

### Why WARP doesn't work either

Cloudflare WARP exit IPs (104.28.x.x) belong to Cloudflare's own range and get Challenged too. WARP can unlock API-level access (`api.anthropic.com`), but **cannot solve the OAuth refresh 403 on `claude.ai`**.

---

## How This Project Solves It

```
Mac / Windows (Clash Verge + TUN global transparent proxy)
  |-- Primary    VLESS+Reality :2083  <- Anti-DPI, mimics legitimate TLS
  |-- Backup     VLESS+Reality :8443  <- Failover when primary is blocked
  +-- CDN node   Cloudflare Workers   <- CDN relay when IP is blocked
                    |
VPS (Xray + WARP)
  |-- Regular traffic -> Direct outbound
  +-- AI domains (Claude/OpenAI/Gemini) -> WARP outbound (clean IP)
                    |
AI coding tools <- Long-lived OAuth Token bypasses OAuth refresh (1-year validity)
```

**Three-layer solution, each layer solves one root cause:**

| Layer | Problem Solved | Implementation |
|-------|---------------|----------------|
| TUN global proxy | Node.js ignores system proxy | Clash Verge TUN mode captures all traffic + `HTTPS_PROXY` env var as fallback |
| WARP AI routing | Data center IP Challenged | Server-side AI domain routing through Cloudflare WARP socks5 |
| OAuth Token | OAuth refresh 403 | `claude setup-token` generates 1-year Token, bypasses OAuth refresh entirely |

## Quick Start

### Prerequisites
- An overseas VPS (recommended: Vultr Singapore, $5/month)
- Mac / Windows / iPhone / Android

### 1. Server one-click deploy
```bash
git clone https://github.com/FelixWayne0318/vpn-setup.git
cd vpn-setup
cp .env.example .env
vi .env  # Enter server IP, leave others blank for auto-generation

sudo bash server/install.sh
# Auto-installs: Xray + WARP + firewall + AI domain routing
```

### 2. Mac client one-click setup
```bash
# Install Clash Verge first: https://github.com/clash-verge-rev/clash-verge-rev/releases

bash client/setup-mac.sh
# Auto-generates Clash config + writes proxy env vars + verifies connectivity
```

After script completes, manual steps:
1. Clash Verge Settings -> Install Service Mode
2. Enable TUN (virtual network card) mode
3. Enable system proxy + auto-start on boot

### 3. Claude Code setup
```bash
# Generate 1-year OAuth Token
claude setup-token

# Add to ~/.zshrc
echo 'export CLAUDE_CODE_OAUTH_TOKEN="sk-ant-oat01-your-token..."' >> ~/.zshrc
source ~/.zshrc
```

See [docs/claude-code.md](docs/claude-code.md) for details.

### 4. Mobile / other platforms
See [docs/client-setup.md](docs/client-setup.md) (Shadowrocket / v2rayNG / Windows Clash Verge)

### 5. Verify everything works
```bash
bash verify.sh
# Tests: proxy port, Google, Claude API, Claude Code CLI, DNS leak
```

## How Is This Different From Other VPN Projects?

GitHub has plenty of Xray/Clash deployment scripts, but they only solve the proxy/tunnel part. **AI coding tools still don't work after that** — no project has systematically solved this:

| Problem | Other Projects | This Project |
|---------|---------------|--------------|
| Browser works but AI tools in IDE don't | Not addressed | [Complete solution](docs/claude-code.md) |
| Data center IP Cloudflare Challenged -> 403 | Root cause unclear | Root cause analysis + OAuth Token bypass |
| AI tools break after a few hours | Not addressed | OAuth Session expiry + long-lived Token |
| macOS Keychain caches expired Session -> repeated 403 | Not addressed | One-line cleanup command |
| AI domains need clean IP (server-side routing) | Some have WARP, no domain routing | AI domains -> WARP, rest direct |
| Clash Verge config lost on restart | Not addressed | merge.yaml persistence |
| Other VPNs hijack outbound -> TLS handshake eof | Not addressed | `interface-name: en0` forces physical NIC |
| DNS port 53 conflict crashes Clash entirely | Not addressed | Uses port 1053 instead |
| End-to-end (server -> client -> AI tools) | Partial coverage | All-in-one solution |

**TL;DR: Other projects set up your tunnel. This project makes AI coding tools actually work through it.**

## Affected Tools (Verified)

These tools all encounter the above issues when accessed through a VPN or proxy. This project solves all of them:

- Claude Code (VS Code extension + CLI)
- Cursor (Claude / GPT models)
- Windsurf / Codeium (Antigravity)
- GitHub Copilot
- Cline (VS Code extension)
- Continue.dev
- Aider
- Amazon Q Developer

## Who Is This For?

- Developers in censored regions (China, Iran, Russia, Turkey, etc.) using AI coding tools
- Anyone globally who gets 403 after self-hosting a VPN on a VPS (Cloudflare Challenge is a global issue)
- Need a stable dev environment, don't want to rely on commercial VPNs
- "Browser works but IDE plugins don't"
- "Works after login, breaks hours later"
- Want one-click deployment, don't want to manually configure Xray / Clash

## Not For

- Only need web browsing (a commercial VPN is enough)
- Not comfortable with terminal / don't have a VPS
- AI tools already work fine on your network

## License

MIT
