# OpenClaw Ansible - Quick Start Guide

This guide shows exactly what to prepare on:

- the Ubuntu VM (deployment target)
- the Ansible host machine (where you run Ansible)

The default Windows path below uses PowerShell + Docker (no WSL shell required).

## 1) Prerequisites Checklist

> **Hyper-V users**: Skip manual VM setup — run `.\powershell\New-OpenClawVM.ps1` from the
> repository root (Admin PowerShell). See [docs/hyperv-setup.md](../docs/hyperv-setup.md).

### VM checklist (Ubuntu target)

- [ ] Ubuntu VM is running and reachable over the network (example: `192.168.1.151`)
- [ ] SSH server is installed and enabled (`sshd`)
- [ ] Login user exists (example: `claw`) and has sudo access
- [ ] At least ~4 GB free disk space on `/` before first full deploy
- [ ] Optional: Tailscale account ready (if you plan to enable Tailscale)

## 1.1) Setup SSH Server on the VM (Ubuntu)

Run these commands directly in the VM console:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

If UFW is enabled on the VM, allow SSH:

```bash
sudo ufw allow OpenSSH
sudo ufw status
```

Confirm VM is listening on port 22:

```bash
sudo ss -tulpen | grep ':22'
```

### Ansible host checklist (control machine)

#### Option A (recommended on Windows): PowerShell + Docker

- [ ] Windows PowerShell 5.1+ or PowerShell 7
- [ ] Docker Desktop installed and running
- [ ] OpenSSH client tools available (`ssh`, `scp`, `ssh-keygen`)
- [ ] Repo cloned locally

#### Option B: Linux/WSL shell

- [ ] Linux or WSL Ubuntu
- [ ] `ansible-core` installed
- [ ] Python 3.10+

## 2) Configure Inventory

Update `inventory/hosts.yml` with your VM details:

```yaml
all:
  children:
    openclaw_vms:
      hosts:
        openclaw-vm:
          ansible_host: 192.168.1.151
          ansible_user: claw
          ansible_ssh_private_key_file: ~/.ssh/openclaw_vm_ansible
```

## 3) Setup SSH Access

### Windows PowerShell

From repo root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ansible\scripts\setup-ssh.ps1 -VmAddress 192.168.1.151 -VmUser claw -SshKeyPath "$HOME\.ssh\openclaw_vm_ansible"
```

Optional host-side connectivity check before key setup:

```powershell
Test-NetConnection 192.168.1.151 -Port 22
```

### Linux/WSL

From `ansible/` directory:

```bash
chmod +x scripts/setup-ssh.sh
./scripts/setup-ssh.sh 192.168.1.151 claw
```

Validate connectivity:

```bash
ansible all -i inventory/hosts.yml -m ping
```

## 4) Configure Secrets

All secrets are stored in **1Password** — no Ansible Vault needed.

### Required: 1Password Service Account

1. Go to [my.1password.com](https://my.1password.com) → Settings → Service Accounts
2. Create a service account with **read + write** access (write is only needed on first deploy to bootstrap items)
3. Copy the `ops_...` token

Set it in your PowerShell session before every deploy:

```powershell
$env:OP_SERVICE_ACCOUNT_TOKEN = "ops_your-token-here"
```

### 1Password Items

Run the bootstrap script once (before first deploy) to create the **OpenClaw** vault and all required items. Existing items are never overwritten.

```powershell
$env:OP_SERVICE_ACCOUNT_TOKEN = "ops_your-token-here"
.\scripts\bootstrap-1password.ps1
```

Then update the `PLACEHOLDER_*` values in 1Password with your real credentials before deploying:

| 1Password Item | Field | Used for |
| --- | --- | --- |
| `Telegram Bot` | `credential` | `TELEGRAM_BOT_TOKEN` |
| `discord` | `credential` | `DISCORD_BOT_TOKEN` |
| `OpenAI` | `credential` | `OPENAI_API_KEY` |
| `OpenRouter API Credentials` | `credential` | `OPENROUTER_API_KEY` |
| `OpenClaw Gateway` | `credential` | `OPENCLAW_GATEWAY_TOKEN` (auto-generated — no action needed) |
| `Tailscale` | `credential` | Tailscale auth key for VPN |
| `OpenClaw` | `vscode_ssh_key` | Your SSH public key for VS Code Remote SSH access (optional) |

### Optional: `vault.yml` for non-sensitive config

`group_vars/vault.yml` is only needed for non-secret local overrides (Discord allowlists, agent identity text). Copy and edit if needed:

```powershell
Copy-Item .\group_vars\vault.example.yml .\group_vars\vault.yml
# Edit vault.yml — no encryption needed, no secrets here
```

## 5) Deploy

### Windows (no WSL shell) - recommended

From `ansible/` directory in PowerShell:

```powershell
# Set your 1Password service account token first (required)
$env:OP_SERVICE_ACCOUNT_TOKEN = "ops_your-token-here"

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\deploy-windows.ps1 -Check
.\scripts\deploy-windows.ps1
```

Notes:

- This runs Ansible inside Docker, launched from PowerShell.
- It uses `windows-deploy-overrides.yml` automatically when present.

### Linux/WSL shell

From `ansible/` directory:

```bash
./scripts/deploy.sh --check -vv
./scripts/deploy.sh
```

## 6) Post-Deployment VM Tasks

SSH into the VM:

```bash
ssh -i ~/.ssh/openclaw_vm_ansible claw@192.168.1.151
```

### Complete Tailscale login (if enabled)

```bash
sudo tailscale up
tailscale ip -4
```

### Verify OpenClaw service

```bash
sudo systemctl status openclaw
sudo journalctl -u openclaw -n 100 --no-pager
```

### Verify gateway process responds

```bash
which openclaw
openclaw --version
```

### Verify LAN HTTPS ingress (Nginx)

LAN ingress is opt-in. Enable it per host/group by setting `openclaw_lan_enabled: true` in inventory/group vars and adjust `openclaw_lan_subnet` if your LAN is not `192.168.1.0/24`.

```bash
sudo systemctl status nginx --no-pager
sudo ss -tulpen | grep -E ':(80|443)'
curl -kI https://openclaw.lan
```

## 7) VS Code Remote SSH Access (Optional)

You can browse and edit `/home/openclaw` directly in VS Code using the Remote SSH extension.

### Store your SSH public key in 1Password

```bash
op item edit "OpenClaw" --vault OpenClaw \
  "vscode_ssh_key=$(cat ~/.ssh/id_ed25519.pub)"
```

### Deploy the vendor role to write `authorized_keys`

```bash
# Linux/WSL
cd ansible && bash scripts/deploy.sh --tags vendor

# PowerShell
cd ansible
.\scripts\deploy-windows.ps1 -Tags vendor
```

### Configure `~/.ssh/config`

```
Host openclaw-vps
  HostName 192.168.1.151
  User openclaw
  IdentityFile ~/.ssh/id_ed25519
```

### Connect

VS Code → Command Palette (`F1`) → **Remote-SSH: Connect to Host** → `openclaw-vps`.

VS Code Server installs itself automatically into `/home/openclaw/.vscode-server/` on first connect.

### Verify

```bash
ssh openclaw@192.168.1.151 'cat ~/.ssh/authorized_keys'
```

## 8) Common Validation Commands

From Ansible host:

```bash
ansible openclaw_vms -i inventory/hosts.yml -m ping
ansible-playbook -i inventory/hosts.yml site.yml --check
```

From VM:

```bash
sudo systemctl is-enabled openclaw
sudo systemctl is-active openclaw
```

## Troubleshooting Quick Hits

- SSH auth fails: rerun `setup-ssh` and ensure key path in inventory matches your actual private key.
- `Missing sudo password`: make sure your VM user can `sudo` without interactive prompts for automation.
- `No space left on device`: clean package cache and verify free disk before rerun.
- Docker deploy errors on Windows: confirm Docker Desktop is running and file sharing is enabled for the repo drive.

For more details, see `TROUBLESHOOTING.md`.
