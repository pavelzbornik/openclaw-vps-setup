# OpenClaw Ansible - Quick Start Guide

This guide will get you up and running with OpenClaw on your Hyper-V Ubuntu VM in ~15 minutes.

## Prerequisites Checklist

- [ ] Ubuntu VM created and running (IP: 192.168.100.10)
- [ ] Ubuntu user created (username: `openclaw`)
- [ ] SSH enabled on the VM
- [ ] WSL2 with Ubuntu installed on Windows host
- [ ] Network connectivity between WSL2 and VM

## Step 1: Install Ansible in WSL2 (5 minutes)

Open WSL2 Ubuntu terminal:

```bash
# Update package list
sudo apt update

# Install Ansible
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Verify installation
ansible --version
```

Expected output: `ansible [core 2.x.x]`

## Step 2: Clone and Setup Project (2 minutes)

```bash
# Navigate to your projects directory
cd ~

# Clone the repository (or copy the ansible folder)
# If you already have the openclaw repo:
cd ~/openclaw/ansible

# Install dependencies
pip3 install molecule molecule-plugins[docker] ansible-lint

# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml
```

## Step 3: Setup SSH Access (3 minutes)

```bash
# Run the SSH setup script
chmod +x scripts/setup-ssh.sh
./scripts/setup-ssh.sh 192.168.100.10 openclaw
```

You'll be prompted for the VM password. After this, password-less SSH will be configured.

**Test connectivity:**

```bash
ansible all -i inventory/hosts.yml -m ping
```

Expected output: `SUCCESS`

## Step 4: Configure Secrets (Optional, 2 minutes)

### Option A: Environment Variables (Quick)

```bash
export OPENCLAW_GATEWAY_TOKEN="your-secure-token-here"
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
```

### Option B: Edit Configuration (Recommended for Production)

Edit `group_vars/all.yml` and update the `openclaw_config` section with your API keys.

### Option C: Use 1Password (Advanced)

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
```

## Step 5: Test with Molecule (Optional, 5 minutes)

Test the playbook in a Docker container before deploying to your VM:

```bash
# Full test cycle
molecule test
```

This validates that all roles work correctly.

## Step 6: Deploy to VM (5 minutes)

### Dry-run First (Recommended)

```bash
# See what would change
./scripts/deploy.sh --check -vv
```

### Deploy for Real

```bash
# Deploy everything
./scripts/deploy.sh

# Or use Makefile
make deploy
```

Watch the output. The deployment will:

1. ✓ Update system packages
2. ✓ Install Node.js 20.x
3. ✓ Install 1Password CLI
4. ✓ Configure firewall (UFW)
5. ✓ Install Tailscale
6. ✓ Install OpenClaw via npm
7. ✓ Create systemd service
8. ✓ Configure OpenClaw

## Step 7: Post-Deployment Configuration (3 minutes)

SSH to your VM:

```bash
ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10
```

### Configure Tailscale (Important!)

```bash
# Authenticate with Tailscale
sudo tailscale up

# Follow the URL to authenticate
# Your VM will get a Tailscale IP (100.x.x.x)
```

### Configure Secrets (if not done via 1Password)

Edit the environment file:

```bash
nano ~/.openclaw/.env
```

Add your API keys:

```
ANTHROPIC_API_KEY=sk-ant-your-key
OPENAI_API_KEY=sk-your-key
```

Save (Ctrl+O, Enter, Ctrl+X)

### Start OpenClaw

```bash
# Start the service
sudo systemctl start openclaw

# Check status
sudo systemctl status openclaw

# View logs
sudo journalctl -u openclaw -f
```

## Step 8: Access OpenClaw Gateway

From your main machine (connected to Tailscale):

1. Get the VM's Tailscale IP: `ssh openclaw@192.168.100.10 "tailscale ip -4"`
2. Open browser: `http://<tailscale-ip>:18789`
3. You should see the OpenClaw Gateway dashboard

## Troubleshooting

### Ansible can't connect to VM

```bash
# Test direct SSH
ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10

# Check inventory
cat inventory/hosts.yml
```

### OpenClaw service won't start

```bash
# Check logs
ssh openclaw@192.168.100.10 "sudo journalctl -u openclaw -n 50"

# Check if OpenClaw is installed
ssh openclaw@192.168.100.10 "which openclaw"
```

### Port 18789 not accessible

```bash
# Check if service is listening
ssh openclaw@192.168.100.10 "sudo ss -tulnp | grep 18789"

# Check firewall
ssh openclaw@192.168.100.10 "sudo ufw status"
```

### Molecule tests fail

```bash
# Check Docker
docker ps

# Run with debug
molecule --debug converge
```

## Common Commands

```bash
# Deploy specific roles
make deploy TAGS=openclaw           # Only OpenClaw
make deploy TAGS=firewall           # Only firewall

# View logs from VM
make logs

# Check service status
make status

# Restart OpenClaw
make restart

# Create VM snapshot (run on Windows)
# Checkpoint-VM -Name "OpenClaw-VM" -SnapshotName "pre-config"
```

## Next Steps

1. **Configure Channels**: Edit `~/.openclaw/config/openclaw.json` to enable Telegram, Discord, etc.
2. **Add Skills**: Place custom skills in `~/.openclaw/workspace/skills/`
3. **Home Assistant**: If using HA, configure the integration
4. **Monitoring**: Set up log monitoring and alerts
5. **Backups**: Schedule regular Hyper-V snapshots

## Security Checklist

- [ ] Changed default gateway token in config
- [ ] API keys stored securely (1Password or encrypted)
- [ ] Tailscale authenticated
- [ ] UFW firewall enabled (port 18789 only from Tailscale)
- [ ] SSH key-based auth only (no password)
- [ ] OpenClaw running as non-root user
- [ ] VM snapshot created before first run

## Help & Support

- Check logs: `make logs`
- Run diagnostics: `ansible openclaw_vms -i inventory/hosts.yml -m setup`
- Re-run deployment: `make deploy`
- Full reset: Create new VM snapshot and restore

---

**Estimated Total Time: 15-20 minutes** ⏱️

Enjoy your automated OpenClaw deployment! 🎉
