# OpenClaw Ansible Provisioning

This directory contains Ansible playbooks and roles for automated provisioning of OpenClaw on Ubuntu VMs.

## Prerequisites

### For Production Deployment

- WSL2 with Ubuntu 24.04 (Windows) or a Linux host
- Ansible core 2.14+ (recommended)
- Python 3.10+
- SSH access to target VM
- Optional: Molecule for testing

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

### 1. Install Dependencies

```bash
# In WSL2
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Install Python dependencies for testing
pip3 install molecule molecule-plugins[docker] ansible-lint

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml
```

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

### 4. Configure Secrets

Set up 1Password service account token:

```bash
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"
```

Or add to `group_vars/all.yml` (encrypted with ansible-vault).

### 5. Test with Molecule

```bash
# Run tests in Docker container
cd ansible
molecule test
```

### 6. Deploy to VM

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
│   ├── openclaw/           # OpenClaw installation
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
- **openclaw_git**: Config repo sync and migration
- **openclaw**: OpenClaw config templating and systemd unit for unattended deploys

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

```

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
3. Dry-run on VM: `ansible-playbook site.yml --check`
4. Deploy: `ansible-playbook site.yml`
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
# Verify service account
export OP_SERVICE_ACCOUNT_TOKEN="ops_xxx"
op vault list

# Test secret read
op read "op://OpenClaw-Secrets/OpenClaw API Keys/ANTHROPIC_API_KEY"
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
- 1Password service account token should be environment variable
- UFW is configured by upstream submodule tasks when `vendor_firewall_enabled` is true
- OpenClaw port exposure depends on upstream firewall rules
