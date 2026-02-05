# Running OpenClaw securely on a Windows 11 home server

**For maximum security isolation on Windows 11, deploy OpenClaw inside a Hyper-V virtual machine rather than using Docker with WSL2 or bare WSL2.** This provides the strongest boundary between the AI agent and your other services. OpenClaw—an autonomous AI assistant that can execute shell commands, control browsers, and access files—requires broad system permissions that security researchers have flagged as inherently risky. Over **42,000 misconfigured instances** were found publicly exposed in January 2026, with 93% exhibiting critical vulnerabilities. The project itself acknowledges there is "no perfectly secure setup."

Your recommended path: create a dedicated Linux VM in Hyper-V with isolated networking, run OpenClaw inside Docker within that VM, and use Tailscale for secure remote access. This dual-layer approach (VM + container) provides defense-in-depth while keeping your Windows host and other services completely protected.

---

## What OpenClaw actually is and why it's risky

OpenClaw (formerly Clawdbot/Moltbot) is an open-source autonomous AI personal assistant created by Peter Steinberger. It runs as a **Node.js service** connecting messaging platforms—WhatsApp, Telegram, Discord, Slack, iMessage, Signal—to AI agents that execute real-world tasks. Unlike chatbots that merely respond to prompts, OpenClaw acts independently: managing calendars, sending messages, running shell commands, controlling browsers, and automating workflows across services.

The core security concern is the **breadth of permissions required**. OpenClaw needs:

- **Shell command execution** on the host system
- **File system read/write access** across user directories  
- **Browser automation** via Chrome DevTools Protocol
- **Network access** to LLM APIs, messaging platforms, and webhooks
- **Credential storage** for all connected services in local JSON files

Cisco's AI Threat Research Team analyzed OpenClaw and found **nine security issues including two critical and five high-severity vulnerabilities**. Third-party "skills" (plugins) can silently exfiltrate data—26% of 31,000 analyzed skills contained vulnerabilities. Prompt injection attacks through emails, web content, or attachments remain unsolved even with leading models.

The **minimum system requirements** are lightweight: 1-2 vCPU, 2-4 GB RAM, 500 MB disk. The default network port is **18789** for the Gateway API and dashboard. OpenClaw officially supports Docker deployment with security hardening options.

---

## Option 1: Docker on Windows 11 with Hyper-V backend

Docker Desktop on Windows 11 runs containers inside a lightweight Linux VM. Security varies significantly between backends: **WSL2 is faster but less isolated; Hyper-V provides stronger boundaries**.

### Docker with Hyper-V backend (more secure)

With the Hyper-V backend, Docker Desktop runs a dedicated VM with its own kernel. Users cannot easily access this VM directly, which prevents bypassing Docker's security controls. This is the **recommended backend** when running containers with broad permissions.

**Practical security configuration for OpenClaw:**

```bash
docker run -d \
  --name openclaw \
  --memory=2g \
  --cpus=1 \
  --user 1000:1000 \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -v openclaw-data:/home/node/.openclaw \
  -p 127.0.0.1:18789:18789 \
  openclaw/openclaw:latest
```

Key hardening measures: bind port to **127.0.0.1 only** (never expose to 0.0.0.0), run as non-root user, use read-only filesystem, drop all Linux capabilities, and limit memory/CPU.

### Docker with WSL2 backend (less secure)

WSL2 offers better performance but **all WSL2 distributions share one Linux kernel**. Users can bypass Docker Desktop entirely via `wsl -d docker-desktop`, gaining root access to modify engine settings. Docker's own documentation states: "Use Hyper-V backend for maximum security."

### Network isolation in Docker

| Mode | Isolation | When to use |
|------|-----------|-------------|
| **bridge** (default) | Good | Most applications |
| **none** | Maximum | Sensitive processing without network |
| **host** | None | Never for OpenClaw |
| **custom internal** | Configurable | Multi-container setups |

Create truly isolated networks with: `docker network create --driver bridge --internal isolated_net`

### Protecting other services on the host

Windows Firewall integrates with Docker via `vpnkit.exe`. Configure explicit rules limiting what ports Docker can expose. Resource limits prevent runaway containers from starving your other services—set memory caps and CPU quotas in Docker Compose:

```yaml
services:
  openclaw:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
```

**Docker Desktop is free for personal use** (under 250 employees and $10M revenue), making it suitable for home servers without licensing concerns.

---

## Option 2: VPS deployment (risk isolation from home)

Running OpenClaw on a remote VPS **physically isolates all risk from your home network**. If the agent is compromised, attackers cannot pivot to smart home devices, NAS systems, or personal computers.

### Security advantages

A VPS provider offers enterprise-grade DDoS protection, **99.9% uptime SLAs**, and professional datacenter security. Your home IP remains hidden from internet scanners associating your identity with exposed AI services. As one analysis noted: "It's actually even better to host this on a cloud VPS as the agent won't have access to any of your personal information on your local machine."

### Security disadvantages

API keys (Anthropic, OpenAI) must be stored on the VPS—if compromised, they can be abused. VPS providers technically have hypervisor-level access to your server's memory and disk. For extreme sensitivity, choose providers offering **AMD SEV (Secure Encrypted Virtualization)** like VPSBG.

### Provider comparison for AI agents

| Provider | Starting price | RAM | Best for |
|----------|---------------|-----|----------|
| **Hetzner** | €3.79/mo | 2GB | Best price/performance, EU privacy |
| **DigitalOcean** | $6/mo | 1GB | Excellent documentation |
| **Vultr** | $6/mo | 1GB | Global coverage (32 regions) |
| **Linode** | $6/mo | 1GB | Generous bandwidth |

**Recommended specs**: 4GB RAM, 2 vCPU, 40GB NVMe (~$12-24/month)

### Connecting VPS to home services

**Tailscale** (recommended): Zero-config mesh VPN built on WireGuard. Install on both VPS and home server—both join your private "tailnet" with encrypted 100.x.x.x addresses. No port forwarding required, works through CGNAT, takes ~5 minutes to set up. Free tier supports 100 devices.

Architecture: `OpenClaw (VPS) <--Tailscale--> Home Server --> Smart Home / NAS / Local Services`

Limit SSH access to Tailscale IPs only:

```bash
ufw allow from 100.64.0.0/10 to any port 22
ufw deny 22
```

### VPS hardening checklist

Run as non-root user, use Nginx as reverse proxy (never expose Node.js directly), enable UFW firewall, install Fail2ban for brute-force protection, configure automatic security updates.

---

## Option 3: Hyper-V virtual machine (strongest isolation)

**Hyper-V provides the strongest security boundary on Windows 11**—a Type-1 hypervisor running directly on hardware with complete separation between host and guest operating systems.

### Why Hyper-V is superior for security

Each VM has its own virtualized hardware (CPU, memory, storage) completely isolated from Windows. Hyper-V supports **Shielded VMs** with BitLocker encryption preventing even host administrators from accessing VM data, **Secure Boot** to verify firmware integrity, and **TPM support** for encryption key protection. The performance impact is typically **less than 1-2%** compared to bare metal.

### Network isolation options

| Switch type | Isolation level | Description |
|-------------|-----------------|-------------|
| **Private** | Complete | VMs only communicate with each other |
| **Internal** | Partial | VMs + host only, no external network |
| **External** | None | Full LAN access |
| **NAT** | Good | Internet access but invisible to LAN |

For OpenClaw, use an **Internal switch with NAT**—the VM can reach the internet for API calls while remaining invisible to your LAN:

```powershell
New-VMSwitch -SwitchName "OpenClawNAT" -SwitchType Internal
New-NetNat -Name "OpenClawNATNetwork" -InternalIPInterfaceAddressPrefix "192.168.100.0/24"
```

### Practical deployment steps

1. Enable Hyper-V: `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All`
2. Create Ubuntu Server VM with 4GB RAM, 2 vCPU, 40GB dynamic VHDX
3. Configure Internal NAT switch for isolated networking
4. Install Docker inside the VM
5. Deploy OpenClaw in Docker with hardening flags
6. Create a **baseline checkpoint** before first run
7. Install Tailscale inside VM for secure remote access

### Snapshot and rollback capabilities

Hyper-V supports up to **50 checkpoints per VM** with instant rollback. Use **Production Checkpoints** (VSS-based) for data-consistent backups. Before running risky commands or installing new skills, create a checkpoint: `Checkpoint-VM -Name "OpenClaw-VM" -SnapshotName "Pre-experiment"`. If anything goes wrong, restore in seconds.

---

## Why WSL2 alone is not recommended

WSL2 provides **integration, not isolation**—it's designed for developer convenience, not security containment.

Critical security limitations:

- All Windows drives are **auto-mounted** at `/mnt/c/`, `/mnt/d/`, etc.
- Any Windows process can **access all WSL files** via `\\wsl$\`
- All WSL2 distributions **share one Linux kernel**—one distribution can modify kernel settings affecting others
- Malicious software can steal SSH keys, credentials, and sensitive data from WSL filesystems without elevation

Security researcher CyberArk explicitly warns: "A standard (non-admin) Windows process can steal sensitive static data (e.g., SSH keys) by simply copying them from the WSL file system."

**WSL2 should only be used as a Docker backend with Hyper-V unavailable, never for running security-sensitive applications directly.**

---

## Recommended deployment approach

For a Windows 11 home server where you want **maximum security while keeping other services unaffected**, implement this layered approach:

**Layer 1 - Hyper-V VM**: Create a dedicated Ubuntu VM on an Internal NAT switch. This provides hardware-level isolation—nothing OpenClaw does can affect your Windows host or other services.

**Layer 2 - Docker container**: Run OpenClaw inside Docker within the VM with all hardening flags (`--read-only`, `--cap-drop ALL`, non-root user, resource limits). This adds defense-in-depth.

**Layer 3 - Application hardening**: Configure OpenClaw's built-in security:

```json
{
  "gateway": {
    "bind": "loopback",
    "auth": { "mode": "token", "token": "your-long-random-token" }
  },
  "channels": {
    "whatsapp": {
      "dmPolicy": "pairing",
      "groups": { "*": { "requireMention": true } }
    }
  }
}
```

Run `openclaw security audit --fix` to auto-apply safe guardrails.

**Layer 4 - Network security**: Use Tailscale inside the VM for remote access (never expose port 18789 to your LAN). Configure Windows Firewall to block all inbound traffic to the VM's virtual switch except from Tailscale.

**Maintenance**: Keep snapshots before updates. Run security audits weekly. Monitor logs at `/tmp/openclaw/openclaw-YYYY-MM-DD.log`. Update Node.js promptly—recent CVEs affected permission model bypass (CVE-2026-21636).

---

## Alternative: VPS with Tailscale to home

If you prefer **not running any AI agent on your home network**, deploy on a **Hetzner 4GB VPS** (~€7/month) with:

- UFW firewall allowing only SSH (Tailscale-restricted) and ports 80/443
- Nginx reverse proxy with Let's Encrypt TLS
- Docker with resource limits
- Tailscale for connecting to home services when needed
- Automated daily backups

This approach completely separates AI agent risk from your home while maintaining connectivity through encrypted tunnels. The trade-off is ~$20/month recurring cost versus one-time VM setup effort.

## Conclusion

OpenClaw is a powerful autonomous AI assistant that requires careful deployment due to its broad system access requirements. **Hyper-V with Docker inside** provides the strongest isolation for Windows 11 home servers—your other services remain completely protected even if OpenClaw is compromised. VPS deployment offers an alternative that physically separates risk from your home network. Avoid running OpenClaw directly in WSL2 or on your bare Windows host. Whichever path you choose, enable gateway authentication, restrict DM policies to pairing/allowlist mode, run regular security audits, and maintain snapshots for rapid rollback if incidents occur.
