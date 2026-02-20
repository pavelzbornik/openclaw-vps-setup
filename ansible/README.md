# OpenClaw Ansible Provisioning

This directory contains Ansible playbooks and roles for automated provisioning of OpenClaw on Ubuntu VMs.

## Prerequisites

### Target VM (Ubuntu)

- Ubuntu VM/VPS reachable via SSH (OpenSSH server installed and running)
- Login user with sudo access (example: `claw`)
- Python 3 available on VM (`/usr/bin/python3`)
- Sufficient free disk space for package upgrades

If SSH server is not set up yet, use the VM setup steps in [QUICKSTART.md](QUICKSTART.md) under "Setup SSH Server on the VM (Ubuntu)".

### Ansible Host (Control Node)

Choose one:

- **Windows PowerShell + Docker (recommended, no WSL shell)**
   - Docker Desktop running
   - OpenSSH client tools installed (`ssh`, `scp`, `ssh-keygen`)
- **Linux/WSL shell**
   - `ansible-core` 2.14+
   - Python 3.10+

### For DevContainer Testing (Recommended)

- VS Code with "Dev Containers" extension
- Docker Desktop
- No other dependencies needed!

## Quick Start

### Option 1: DevContainer Testing (Easiest!)

Test everything in an isolated container environment without touching your PC:

1. **Open in DevContainer**
   - Install VS Code extension: "Dev Containers"
   - Open this repo in VS Code
   - Press F1 → "Dev Containers: Reopen in Container"
   - Wait for setup (~5 minutes first time)

2. **Test Deployment**

   ```bash
   # From repo root
   ./test-deploy.sh --check  # Dry-run
   ./test-deploy.sh          # Deploy to test container
   ```

3. **Verify**

   ```bash
   ssh -i ~/.ssh/id_ed25519 root@172.25.0.10
   systemctl status openclaw
   ```

See [.devcontainer/README.md](../.devcontainer/README.md) for complete devcontainer guide.

### Option 2: Production Deployment

Follow the full step-by-step in [QUICKSTART.md](QUICKSTART.md). In short:

1. Configure `inventory/hosts.yml`
2. Set up SSH keys to the VM
3. Deploy from either:
   - `scripts/deploy-windows.ps1` (PowerShell + Docker), or
   - `scripts/deploy.sh` (Linux/WSL shell)

### 2. Configure Inventory

Edit `inventory/hosts.yml` with your VM details:

```yaml
openclaw_vms:
  hosts:
    openclaw-vm:
      ansible_host: 192.168.100.10
      ansible_user: openclaw
```

### 3. Setup SSH Key

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/openclaw_vm -N ""

# Copy to VM
ssh-copy-id -i ~/.ssh/openclaw_vm.pub openclaw@192.168.100.10

# Test connection
ansible openclaw_vms -i inventory/hosts.yml -m ping
```

PowerShell alternative (from repo root):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ansible\scripts\setup-ssh.ps1 -VmAddress 192.168.1.151 -VmUser claw -SshKeyPath "$HOME\.ssh\openclaw_vm_ansible"
```

### 4. Configure Secrets

This deployment now relies on 1Password for runtime secrets. Use Ansible Vault to provide the 1Password service account token and Tailscale auth key:

```powershell
cd ansible
Set-Content -Path .\.vault_pass.txt -Value "choose-a-strong-password"
Copy-Item .\group_vars\vault.example.yml .\group_vars\vault.yml
# Edit group_vars\vault.yml locally, then encrypt it via Docker:
docker run --rm -v "${PWD}:/work" -w /work python:3.11-bookworm bash -lc "python -m pip install --quiet ansible-core && ansible-vault encrypt group_vars/vault.yml --vault-password-file .vault_pass.txt"
```

Set these vaulted vars in `group_vars/vault.yml`:

- `vault_tailscale_authkey`
- `vault_openclaw_op_service_account_token`

At deploy time, the role renders `.env` with `op://...` references and runs `op inject` on the VM to materialize all runtime secret values.

Required 1Password items/fields for unattended deploys include:

- `OpenClaw / Service Account Auth Token / credential` (for `OP_SERVICE_ACCOUNT_TOKEN`)
- `OpenClaw / OpenClaw Gateway / credential` (for `OPENCLAW_GATEWAY_TOKEN`)

### 5. Test with Molecule

```bash
# Run tests in Docker container
cd ansible
molecule test
```

### 6. Deploy to VM

Windows PowerShell + Docker (recommended):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\deploy-windows.ps1 -Check -VaultPasswordFile .\.vault_pass.txt
.\scripts\deploy-windows.ps1 -VaultPasswordFile .\.vault_pass.txt
```

Linux/WSL shell:

```bash
# Dry run
ansible-playbook -i inventory/hosts.yml site.yml --check

# Deploy
ansible-playbook -i inventory/hosts.yml site.yml

# Deploy with verbose output
ansible-playbook -i inventory/hosts.yml site.yml -v
```

## Structure

```
ansible/
├── inventory/
│   └── hosts.yml           # VM inventory
├── group_vars/
│   └── all.yml             # Global variables
├── roles/
│   ├── common/             # Base system setup
│   ├── openclaw_vendor_base/ # Wrapper around the official openclaw-ansible submodule
│   ├── openclaw_git/       # Config repo sync and migration
│   ├── openclaw_app/       # OpenClaw config templating and systemd
│   ├── openclaw_gateway_proxy/ # Nginx HTTPS reverse proxy for LAN ingress
│   └── onepassword/        # 1Password CLI setup
├── molecule/
│   └── default/            # Molecule test scenario
├── site.yml                # Main playbook
├── requirements.yml        # Ansible Galaxy requirements
└── ansible.cfg             # Ansible configuration
```

## Roles

- **openclaw_vendor_base**: Wrapper role that invokes tasks from the official openclaw-ansible submodule
- **common**: Base system packages, timezone, locale
- **onepassword**: 1Password CLI for secrets management
- **openclaw_git**: Config repo sync, migration, and deployment of personal workspace files from private repo
- **openclaw_app**: OpenClaw config templating and systemd unit for unattended deploys
- **openclaw_gateway_proxy**: Nginx HTTPS reverse proxy, LAN allowlist, and firewall rules for local network access

### Personal Workspace Files (Public/Private Split)

- Keep personal workspace markdown files in your private config repository (`openclaw_config_repo`).
- Default behavior (`openclaw_workspace_source: private_repo`) deploys personal files from private repo `workspace/` to `~/.openclaw/workspace/`.
- Temporary local staging in this public repo is available at `docs/research/local-config/workspace/` and is gitignored.

### DevContainer Testing (Recommended)

Test in a real Ubuntu container with systemd:

```bash
# In devcontainer
./test-deploy.sh --check   # Dry-run
./test-deploy.sh           # Deploy
make test-deploy           # Alternative
```

### Molecule Testing

Molecule provides isolated Docker-based testing:

```bash
# Create test environment
molecule create

# Apply playbook
molecule converge

# Run verification tests
molecule verify

# Destroy test environment
molecule destroy

# Full test cycle
molecule test
```

### Comparison

| Feature | DevContainer | Molecule | Production |
|---------|-------------|----------|------------|
| **Environment** | Container with systemd | Clean container per test | Real VM |
| **Speed** | Fast (~2 min) | Medium (~5 min) | Varies |
| **Persistence** | Keeps state | Destroyed after test | Permanent |
| **Use Case** | Development & debugging | Validation & CI/CD | Actual deployment |

## Testing

Molecule provides automated testing:

```bash
# Create test environment
molecule create

# Apply playbook
molecule converge

# Run verification tests
molecule verify

# Destroy test environment
molecule destroy

# Full test cycle
molecule test
```

## Deployment Workflow

1. Create VM snapshot: `ssh windows-host "powershell.exe Checkpoint-VM -Name OpenClaw-VM"`
2. Test in Molecule: `molecule test`
3. Dry-run on VM: `./scripts/deploy.sh --check -vv` or `./scripts/deploy-windows.ps1 -Check`
4. Deploy: `./scripts/deploy.sh` or `./scripts/deploy-windows.ps1`
5. Verify: SSH to VM and check services

## Maintenance

```bash
# Update OpenClaw
ansible-playbook site.yml --tags openclaw

# Update upstream firewall rules (if enabled)
ansible-playbook site.yml --tags firewall

# Restart services
ansible openclaw_vms -i inventory/hosts.yml -a "systemctl restart openclaw" --become
```

## Troubleshooting

**Ansible can't connect:**

```bash
# Test SSH directly
ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10

# Check inventory
ansible-inventory -i inventory/hosts.yml --list
```

**1Password secrets not working:**

```bash
# Verify 1Password access on VM (token comes from ansible-vault variable)
op vault list

# Test inject syntax against a reference
printf 'TEST=op://OpenClaw/Service Account Auth Token/credential\n' | op inject
```

**Molecule tests failing:**

```bash
# Check Docker
docker ps

# View container logs
docker logs <container_id>

# Login to test container
molecule login
```

## Security Notes

- SSH keys should have 0600 permissions
- Never commit secrets to git
- Use ansible-vault for sensitive variables
- 1Password service account token is read from `vault_openclaw_op_service_account_token`
- UFW is configured by upstream submodule tasks when `vendor_firewall_enabled` is true
- OpenClaw port exposure depends on upstream firewall rules
