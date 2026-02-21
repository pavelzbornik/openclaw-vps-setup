# OpenClaw Ansible - Quick Start Guide

This guide shows exactly what to prepare on:

- the Ubuntu VM (deployment target)
- the Ansible host machine (where you run Ansible)

The default Windows path below uses PowerShell + Docker (no WSL shell required).

## 1) Prerequisites Checklist

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

### Required: Ansible Vault for `tailscale_authkey` + `OP_SERVICE_ACCOUNT_TOKEN`

From `ansible/` directory:

```powershell
# 1) Create vault password file (do not commit)
Set-Content -Path .\.vault_pass.txt -Value "choose-a-strong-password"

# 2) Create your local vault file from example
Copy-Item .\group_vars\vault.example.yml .\group_vars\vault.yml

# 3) Edit the file in VS Code/Notepad and set your real values
#    (vault_tailscale_authkey and vault_openclaw_op_service_account_token)

# 4) Encrypt using Ansible Vault inside Docker (no local ansible install needed)
docker run --rm -v "${PWD}:/work" -w /work python:3.11-bookworm bash -lc "python -m pip install --quiet ansible-core && ansible-vault encrypt group_vars/vault.yml --vault-password-file .vault_pass.txt"
```

Set:

- `vault_tailscale_authkey`
- `vault_openclaw_op_service_account_token`

Then deploy (PowerShell + Docker):

```powershell
.\scripts\deploy-windows.ps1 -VaultPasswordFile .\.vault_pass.txt
```

Notes:

- `group_vars/vault.yml` and `.vault_pass.txt` are gitignored.
- Secret fallbacks are disabled; `vault_openclaw_op_service_account_token` is required.
- Runtime `.env` values are populated on the VM via `op inject` from 1Password references.
- Create a 1Password item `OpenClaw / OpenClaw Gateway / credential` for `OPENCLAW_GATEWAY_TOKEN`.

To update vaulted values later:

```powershell
# Decrypt
docker run --rm -v "${PWD}:/work" -w /work python:3.11-bookworm bash -lc "python -m pip install --quiet ansible-core && ansible-vault decrypt group_vars/vault.yml --vault-password-file .vault_pass.txt"

# Edit group_vars/vault.yml locally, then re-encrypt
docker run --rm -v "${PWD}:/work" -w /work python:3.11-bookworm bash -lc "python -m pip install --quiet ansible-core && ansible-vault encrypt group_vars/vault.yml --vault-password-file .vault_pass.txt"
```

## 5) Deploy

### Windows (no WSL shell) - recommended

From `ansible/` directory in PowerShell:

```powershell
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

## 7) Common Validation Commands

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
