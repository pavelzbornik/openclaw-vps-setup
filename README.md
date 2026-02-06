# OpenClaw VPS setup

Automated provisioning and deployment for the OpenClaw AI agent on Ubuntu VPS or Hyper-V VMs.

![License](https://img.shields.io/badge/license-MIT-blue)
![Stack](https://img.shields.io/badge/stack-ansible%20%2B%20terraform%20%2B%20tailscale-informational)

## ✅ Purpose

This repo packages the infrastructure and automation needed to install OpenClaw securely on a dedicated Ubuntu host.

### Who This Is For

- Self-hosters who want a hardened, reproducible OpenClaw deployment
- Windows users running Hyper-V VMs
- VPS users who prefer native installs (no Docker)


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
├── terraform/                 # Discord IaC (optional)
└── docs/                      # Project guides and references
    ├── README.md              # Docs index
    ├── hyperv-setup.md         # Hyper-V VM checklist
    ├── firewall.md             # Firewall and network controls
    ├── openclaw-config-repo.md # Git sync guidance
    └── discord-terraform.md    # Discord setup overview
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

- ✅ Provisions Ubuntu VM with Node.js (via the official `openclaw-ansible` submodule)
- ✅ Installs OpenClaw natively (no Docker runtime)
- ✅ Configures firewall via upstream role (optional)
- ✅ Sets up Tailscale VPN (optional)
- ✅ Installs 1Password CLI for secrets management
- ✅ Syncs an OpenClaw config repo (optional)
- ✅ Creates a systemd service for OpenClaw
- ✅ Includes Molecule and devcontainer testing

### Prerequisites

- Ubuntu 24.04 VM or VPS with SSH access
- WSL2 with Ubuntu on Windows host (if using Hyper-V)
- Basic Ansible knowledge (optional)

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [ansible/README.md](ansible/README.md) | Complete Ansible documentation |
| [ansible/QUICKSTART.md](ansible/QUICKSTART.md) | Step-by-step deployment guide |
| [ansible/TROUBLESHOOTING.md](ansible/TROUBLESHOOTING.md) | Problem solving guide |
| [ansible/IMPLEMENTATION_NOTES.md](ansible/IMPLEMENTATION_NOTES.md) | Critical configuration notes |
| [docs/README.md](docs/README.md) | Documentation index |
| [docs/hyperv-setup.md](docs/hyperv-setup.md) | Hyper-V VM checklist |
| [docs/firewall.md](docs/firewall.md) | Firewall and network controls |
| [docs/openclaw-config-repo.md](docs/openclaw-config-repo.md) | Config repo sync guidance |
| [docs/discord-terraform.md](docs/discord-terraform.md) | Discord IaC overview |
| [docs/PRE_COMMIT_SETUP.md](docs/PRE_COMMIT_SETUP.md) | Pre-commit hooks setup and usage |

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

## 🔐 Security

- OpenClaw runs as non-root user
- Firewall rules applied via upstream tasks (when enabled)
- Tailscale access available via upstream submodule tasks (when enabled)
- SSH key-based authentication only
- fail2ban and unattended upgrades when local security packages are enabled

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

1. **openclaw_vendor_base**: Wrapper that invokes the official `openclaw-ansible` submodule tasks
2. **common**: Base system setup, security packages
3. **onepassword**: 1Password CLI for secrets management
4. **openclaw_git**: Config repo sync and migration
5. **openclaw**: OpenClaw npm installation and systemd unit

### Testing

- **Molecule framework**: Test playbooks in Docker before VM deployment
- **Verification tasks**: Validate installation and configuration
- **Idempotence tests**: Ensure playbooks can run multiple times safely

## 🎯 Design Decisions

- **Native installation** (not Docker): OpenClaw runs directly on the VM
- **Upstream submodule**: Extend the official openclaw-ansible playbook for Node.js/Tailscale/firewall
- **Molecule testing**: Validate playbooks in containers before production
- **1Password integration**: Secrets management without committing to git
- **systemd service**: Automatic startup and restart on failure

## 📄 License

MIT. See [LICENSE](LICENSE).

## 🙏 Acknowledgments

Based on community research and the official openclaw-ansible playbook used as a submodule.

---

**Ready to deploy?** → Start with [ansible/QUICKSTART.md](ansible/QUICKSTART.md)
