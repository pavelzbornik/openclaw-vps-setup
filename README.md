# OpenClaw

Automated provisioning and deployment for OpenClaw AI agent on Hyper-V Ubuntu VMs.

## 📁 Repository Structure

```
openclaw/
├── ansible/                    # Ansible provisioning (⭐ START HERE)
│   ├── README.md              # Full documentation
│   ├── QUICKSTART.md          # Step-by-step guide
│   ├── TROUBLESHOOTING.md     # Common issues
│   ├── roles/                 # Ansible roles
│   ├── molecule/              # Testing framework
│   └── scripts/               # Deployment scripts
└── docs/
    └── research/              # Research and guides
```

## 🚀 Quick Start

### Option 1: DevContainer Testing (Easiest!)

Test the complete setup in an isolated container environment:

1. Open this repo in VS Code
2. Install "Dev Containers" extension
3. Press F1 → "Dev Containers: Reopen in Container"
4. Run `./test-deploy.sh` in the integrated terminal

See **[.devcontainer/README.md](.devcontainer/README.md)** for details.

### Option 2: Production Deployment

```bash
cd ansible
# Follow the QUICKSTART.md guide
```

See **[ansible/QUICKSTART.md](ansible/QUICKSTART.md)** for complete step-by-step instructions.

### What This Does

- ✅ Provisions Ubuntu VM with Node.js 20.x
- ✅ Installs OpenClaw natively (no Docker)
- ✅ Configures UFW firewall (port 18789 only from Tailscale)
- ✅ Sets up Tailscale VPN
- ✅ Installs 1Password CLI for secrets management
- ✅ Creates systemd service for OpenClaw
- ✅ Implements security hardening (fail2ban, auto-updates)
- ✅ Includes Molecule testing framework

### Prerequisites

- Hyper-V VM with Ubuntu 24.04 (already created)
- WSL2 with Ubuntu on Windows host
- SSH access to VM
- Basic Ansible knowledge (optional)

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [ansible/README.md](ansible/README.md) | Complete Ansible documentation |
| [ansible/QUICKSTART.md](ansible/QUICKSTART.md) | Step-by-step deployment guide |
| [ansible/TROUBLESHOOTING.md](ansible/TROUBLESHOOTING.md) | Problem solving guide |
| [ansible/IMPLEMENTATION_NOTES.md](ansible/IMPLEMENTATION_NOTES.md) | Critical configuration notes |
| [docs/PRE_COMMIT_SETUP.md](docs/PRE_COMMIT_SETUP.md) | Pre-commit hooks setup and usage |
| [docs/research/openclaw-hyperv-setup-guide.md](docs/research/openclaw-hyperv-setup-guide.md) | Original manual setup guide |

## 🔧 Common Commands

```bash
# Setup SSH access
cd ansible
./scripts/setup-ssh.sh

# Test with Molecule (Docker validation)
make test

# Deploy to VM
make deploy

# View logs
make logs

# Check service status
make status
```

## 📝 Research Notes

The `docs/research/` directory contains detailed research on:

- OpenClaw security considerations for Windows 11 home servers
- Hyper-V VM setup and networking
- Firewall configuration strategies
- Discord channel provisioning
- 1Password integration
- Cost optimization with model routing

These documents informed the Ansible implementation.

## 🔐 Security

- OpenClaw runs as non-root user
- UFW firewall with restrictive rules
- Port 18789 only accessible via Tailscale network
- SSH key-based authentication only
- fail2ban brute-force protection
- Automatic security updates
- SMB/NetBIOS ports blocked

## 🤖 About OpenClaw

OpenClaw is an autonomous AI personal assistant that connects messaging platforms (WhatsApp, Telegram, Discord, etc.) to AI agents that execute real-world tasks. It's a Node.js service that can:

- Manage calendars and send messages
- Run shell commands and automate workflows
- Control browsers via Chrome DevTools Protocol
- Integrate with Home Assistant for smart home control
- Execute custom skills and plugins

**⚠️ Security Note**: OpenClaw requires broad system permissions. This project deploys it in an isolated Hyper-V VM with network restrictions for maximum security.

## 📦 What's Inside

### Ansible Roles

1. **common**: Base system setup, security packages
2. **nodejs**: Node.js 20.x from NodeSource
3. **openclaw**: OpenClaw installation and configuration
4. **onepassword**: 1Password CLI for secrets management
5. **firewall**: UFW firewall with security rules
6. **tailscale**: Tailscale mesh VPN

### Testing

- **Molecule framework**: Test playbooks in Docker before VM deployment
- **Verification tasks**: Validate installation and configuration
- **Idempotence tests**: Ensure playbooks can run multiple times safely

## 🎯 Design Decisions

- **Native installation** (not Docker): Per requirements, OpenClaw runs directly on the VM
- **Molecule testing**: Validates changes in containers before production
- **1Password integration**: Secure secrets management without committing to git
- **Tailscale-only access**: Gateway only accessible via VPN (100.64.0.0/10 network)
- **systemd service**: Automatic startup and restart on failure

## 🚧 Known Limitations

1. **OpenClaw npm package name needs verification** - Check official repo for correct package
2. **Manual Tailscale authentication required** - Run `tailscale up` after deployment
3. **No Docker isolation** - OpenClaw runs natively per requirements
4. See [IMPLEMENTATION_NOTES.md](ansible/IMPLEMENTATION_NOTES.md) for complete list

## 🏗️ Future Enhancements

- Automated Tailscale authentication with auth key
- Nginx reverse proxy with SSL/TLS
- Monitoring with Prometheus/Grafana
- Automated backup/restore playbooks
- CI/CD pipeline integration
- Multi-instance support

## 📄 License

See individual component licenses. This automation is provided as-is.

## 🙏 Acknowledgments

Based on research and documentation in `docs/research/`, including:

- OpenClaw security analysis
- Hyper-V networking strategies
- Community best practices for AI agent deployment

---

**Ready to deploy?** → Start with [ansible/QUICKSTART.md](ansible/QUICKSTART.md)
