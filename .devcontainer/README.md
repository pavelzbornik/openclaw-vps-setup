# DevContainer Testing Guide

This devcontainer provides a complete, isolated environment for testing the OpenClaw Ansible deployment without affecting your local PC.

## What's Included

### Control Node (Your Dev Environment)

- Ubuntu 24.04 with full Ansible stack
- Pre-installed tools:
  - Ansible 2.x
  - Molecule (testing framework)
  - ansible-lint
  - Docker-in-Docker
  - Python 3 with pip
  - All required Ansible collections

### Target Node (Simulated VM)

- Ubuntu 24.04 container with systemd
- Mimics your actual Hyper-V VM
- Reachable from inside the devcontainer as: `ubuntu-target`
- SSH enabled (host port is random by default)
- Pre-configured for Ansible access

### VS Code Extensions

- Ansible language support
- YAML validation
- Python tools
- Docker integration
- Spell checker

## Quick Start

### 1. Open in DevContainer

1. Install VS Code extension: "Dev Containers" (ms-vscode-remote.remote-containers)
2. Open this repository in VS Code
3. Press F1 → "Dev Containers: Reopen in Container"
4. Wait for container build (first time ~5 minutes)

### 2. Verify Setup

The post-creation script should have configured everything. Verify:

```bash
# Check Ansible version
ansible --version

# Test connectivity to target container
ansible all -i inventory/test-container.yml -m ping

# Expected output: ubuntu-target | SUCCESS
```

### 3. Test Deployment

#### Option A: Use the Helper Script

```bash
# Dry-run (see what would change)
./test-deploy.sh --check

# Deploy for real
./test-deploy.sh

# Deploy with verbose output
./test-deploy.sh -vv
```

#### Option B: Manual Deployment

```bash
# Test connectivity
ansible all -i inventory/test-container.yml -m ping

# Run playbook (dry-run)
ansible-playbook -i inventory/test-container.yml site.yml --check

# Deploy
ansible-playbook -i inventory/test-container.yml site.yml

# Deploy specific role
ansible-playbook -i inventory/test-container.yml site.yml --tags nodejs
```

### 4. Access the Target Container

#### Via SSH

```bash
# SSH into the target container
ssh -i ~/.ssh/id_ed25519 root@ubuntu-target

# Or exec into it (Compose-managed container name)
docker exec -it $(docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1) bash
```

#### Via Ansible Ad-Hoc Commands

```bash
# Run commands
ansible all -i inventory/test-container.yml -m shell -a "systemctl status openclaw"

# Check OpenClaw installation
ansible all -i inventory/test-container.yml -m shell -a "which openclaw"

# View logs
ansible all -i inventory/test-container.yml -m shell -a "journalctl -u openclaw -n 20"
```

### 5. Run Molecule Tests

```bash
# Full test cycle
molecule test

# Individual steps
molecule create      # Create test container
molecule converge    # Apply playbook
molecule verify      # Run tests
molecule destroy     # Clean up
```

## Container Network Details

```
┌─────────────────────────────────────────┐
│ Host PC (Windows)                       │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │ VS Code                            │ │
│  └───────────────────────────────────┘ │
│           │                             │
│           ├─ Forward Port 18789        │
│           └─ SSH Port (random by default)│
└─────────────────────────────────────────┘
           │
           │ Docker Network (auto-assigned)
           │
    ┌──────┴──────────────────────────────┐
    │                                      │
    │  ┌────────────────────────────┐    │
    │  │ ansible-control            │    │
    │  │ (Dev Environment)          │    │
    │  └────────────────────────────┘    │
    │            │                        │
    │            │ Ansible SSH            │
    │            ▼                        │
    │  ┌────────────────────────────┐    │
    │  │ ubuntu-target              │    │
    │  │ (Simulated VM)             │    │
    │  │ Port 22 → Host:(random)    │    │
    │  │ Port 18789 → Host:(random) │    │
    │  └────────────────────────────┘    │
    └────────────────────────────────────┘
```

## Common Tasks

### View OpenClaw Logs

```bash
# Via Ansible
ansible all -i inventory/test-container.yml -m shell -a "journalctl -u openclaw -f"

# Direct container access
docker exec $(docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1) journalctl -u openclaw -f
```

### Check Service Status

```bash
ansible all -i inventory/test-container.yml -m shell -a "systemctl status openclaw"
```

### Restart OpenClaw

```bash
ansible all -i inventory/test-container.yml -m shell -a "systemctl restart openclaw"
```

### Reset Target Container

```bash
# Destroy and recreate
cd .devcontainer
docker-compose down -v
docker-compose up -d ubuntu-target

# (Optional) Use fixed host ports if you want (and they're free):
#   OPENCLAW_SSH_PORT=2222 OPENCLAW_GATEWAY_PORT=18789 docker-compose up -d ubuntu-target

# Re-run post-create script
bash post-create.sh
```

### Run Specific Roles

```bash
# Only install Node.js
ansible-playbook -i inventory/test-container.yml site.yml --tags nodejs

# Only configure firewall
ansible-playbook -i inventory/test-container.yml site.yml --tags firewall

# Multiple tags
ansible-playbook -i inventory/test-container.yml site.yml --tags "nodejs,openclaw"
```

## Differences from Production VM

| Aspect | DevContainer | Production VM |
|--------|-------------|---------------|
| **OS** | Ubuntu 24.04 container | Ubuntu 24.04 VM |
| **Host** | `ubuntu-target` (Docker DNS) | 192.168.100.10 |
| **User** | root (for testing) | openclaw |
| **UFW** | Disabled (container limitation) | Enabled |
| **Tailscale** | Disabled (not needed) | Enabled |
| **systemd** | Full support | Full support |
| **Isolation** | Container isolation | VM isolation |

**Note**: UFW firewall is disabled in the test container because it doesn't work properly in Docker. This is fine for testing the Ansible logic, but remember that UFW **will** be enabled on your real VM.

## Troubleshooting

### Container won't start

```bash
# Check container logs
docker-compose -f .devcontainer/docker-compose.yml logs ubuntu-target

# Restart containers
docker-compose -f .devcontainer/docker-compose.yml restart
```

### SSH connection fails

```bash
# Copy SSH key manually
TARGET_ID=$(docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1)
docker exec "$TARGET_ID" mkdir -p /root/.ssh
docker cp ~/.ssh/id_ed25519.pub "$TARGET_ID":/root/.ssh/authorized_keys
docker exec "$TARGET_ID" chmod 600 /root/.ssh/authorized_keys

# Test connection
ssh -i ~/.ssh/id_ed25519 root@ubuntu-target
```

### Ansible can't connect

```bash
# Test DNS/connectivity
ping ubuntu-target

# Check inventory
cat inventory/test-container.yml

# Test with verbose output
ansible all -i inventory/test-container.yml -m ping -vvv
```

### Molecule tests fail

```bash
# Clean up and retry
molecule destroy
docker system prune -f
molecule test
```

### OpenClaw won't install

This is expected if the npm package name is wrong (see [IMPLEMENTATION_NOTES.md](../ansible/IMPLEMENTATION_NOTES.md)). The OpenClaw package name needs to be verified from the official repository.

## Development Workflow

### 1. Make Changes

Edit roles, playbooks, or configuration in VS Code

### 2. Test Changes

```bash
# Quick test of syntax
ansible-playbook -i inventory/test-container.yml site.yml --syntax-check

# Lint the playbook
ansible-lint site.yml

# Dry-run
./test-deploy.sh --check
```

### 3. Deploy to Container

```bash
./test-deploy.sh
```

### 4. Verify Results

```bash
# SSH to container
ssh -i ~/.ssh/id_ed25519 root@ubuntu-target

# Check installation
which openclaw
systemctl status openclaw
```

### 5. Run Full Tests

```bash
molecule test
```

### 6. Deploy to Real VM

Once everything works in the container:

```bash
# Exit devcontainer and use production inventory
ansible-playbook -i inventory/hosts.yml site.yml
```

## Performance Tips

### Speed up container start

The first build takes ~5 minutes. Subsequent starts are instant.

### Keep containers running

Containers stay running between sessions by default. Use:

```bash
# Stop containers (saves resources)
docker-compose -f .devcontainer/docker-compose.yml stop

# Start containers
docker-compose -f .devcontainer/docker-compose.yml start
```

### Clean up old images

```bash
# Remove unused images
docker system prune -a
```

## Accessing from Host

### SSH to Target

```bash
# Find the published SSH port (run in WSL / where docker runs)
docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 22

# Then connect from Windows host (PowerShell)
ssh -p <published-port> -i path\to\ssh\key root@localhost
```

### OpenClaw Gateway

Find the published Gateway port (run in WSL / where docker runs):

```bash
docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 18789
```

After deployment, access: `http://localhost:<published-port>`

## Benefits of DevContainer Testing

✅ **Isolated**: Won't affect your PC or production VM  
✅ **Fast**: Create/destroy test environments in seconds  
✅ **Reproducible**: Same environment every time  
✅ **Safe**: Test destructive changes without risk  
✅ **Complete**: Full systemd, SSH, and Ansible support  
✅ **Portable**: Share the exact same environment with team  

## Limitations

⚠️ **UFW doesn't work** in containers (tested on real VM)  
⚠️ **Tailscale not enabled** (not needed for local testing)  
⚠️ **Root user** instead of `openclaw` user (simplified for testing)  
⚠️ **Network isolation different** than production Hyper-V NAT

For production deployment, always test on the actual VM after container testing.

---

**Happy testing! 🚀**
