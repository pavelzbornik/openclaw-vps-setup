# OpenClaw Ansible Troubleshooting Guide

Common issues and solutions when deploying OpenClaw with Ansible.

## Table of Contents

- [Connection Issues](#connection-issues)
  - ["Failed to connect to the host via ssh"](#failed-to-connect-to-the-host-via-ssh)
  - ["Permission denied (publickey)"](#permission-denied-publickey)
- [Deployment Issues](#deployment-issues)
  - ["docker: command not found" (Windows deploy)](#docker-command-not-found-windows-deploy)
  - ["Mount denied" or volume sharing errors](#mount-denied-or-volume-sharing-errors-windows-deploy)
  - ["Missing sudo password"](#missing-sudo-password)
  - ["Package 'nodejs' has no installation candidate"](#package-nodejs-has-no-installation-candidate)
  - ["Failed to install openclaw via pnpm"](#failed-to-install-openclaw-via-pnpm)
  - ["Service failed to start"](#service-failed-to-start)
- [Firewall Issues](#firewall-issues)
  - ["UFW command failed"](#ufw-command-failed)
  - ["Port 3000 not accessible"](#port-3000-not-accessible)
- [1Password Issues](#1password-issues)
  - ["op command not found"](#op-command-not-found)
  - ["OP_SERVICE_ACCOUNT_TOKEN not set"](#op_service_account_token-not-set)
  - ["OPENCLAW_GATEWAY_TOKEN missing"](#openclaw_gateway_token-missing)
- [Molecule Issues](#molecule-issues)
  - ["Docker not found"](#docker-not-found)
  - ["Container creation failed"](#container-creation-failed)
  - ["Verify stage fails"](#verify-stage-fails)
- [Performance Issues](#performance-issues)
  - ["Deployment is very slow"](#deployment-is-very-slow)
  - ["VM is slow after deployment"](#vm-is-slow-after-deployment)
- [Tailscale Issues](#tailscale-issues)
  - ["Tailscale not authenticated"](#tailscale-not-authenticated)
- [Recovery Procedures](#recovery-procedures)
  - ["Deployment broke everything"](#deployment-broke-everything)
  - ["Start fresh"](#start-fresh)
- [Getting More Help](#getting-more-help)

---

## Connection Issues

### "Failed to connect to the host via ssh"

**Problem**: Ansible can't reach the VM

**Solutions**:

1. Test SSH manually:

   ```bash
   ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10
   ```

2. Check VM is running:

   ```powershell
   # On Windows host
   Get-VM -Name "OpenClaw-VM" | Select Name, State
   ```

3. Verify network connectivity:

   ```bash
   ping 192.168.100.10
   ```

4. Check inventory file:

   ```bash
   cat inventory/hosts.yml
   ```

### "Permission denied (publickey)"

**Problem**: SSH key authentication failing

**Solutions**:

1. Re-run SSH setup:

   ```bash
   ./scripts/setup-ssh.sh
   ```

   ```powershell
   .\scripts\setup-ssh.ps1 -VmAddress 192.168.1.151 -VmUser claw -SshKeyPath "$HOME\.ssh\openclaw_vm_ansible"
   ```

2. Check SSH key permissions:

   ```bash
   chmod 600 ~/.ssh/openclaw_vm
   chmod 644 ~/.ssh/openclaw_vm.pub
   ```

3. Verify key is on VM:

   ```bash
   ssh openclaw@192.168.100.10 "cat ~/.ssh/authorized_keys"
   ```

## Deployment Issues

### "docker: command not found" (Windows deploy)

**Problem**: `deploy-windows.ps1` cannot start because Docker CLI is unavailable.

**Solutions**:

1. Install Docker Desktop and reopen PowerShell.
2. Verify Docker is running:

   ```powershell
   docker version
   ```

3. Re-run deploy:

   ```powershell
   .\scripts\deploy-windows.ps1 -Check
   .\scripts\deploy-windows.ps1
   ```

### "Mount denied" or volume sharing errors (Windows deploy)

**Problem**: Docker cannot mount repository or SSH directory.

**Solutions**:

1. In Docker Desktop, enable file sharing for the drive containing the repo and `%USERPROFILE%\.ssh`.
2. Ensure the repo is under a local drive path (for example `C:\Github\...`).
3. Retry from `ansible/` directory:

   ```powershell
   .\scripts\deploy-windows.ps1
   ```

### "Missing sudo password"

**Problem**: Ansible `become` requires interactive sudo input.

**Solutions**:

1. Configure passwordless sudo for the automation user on VM.
2. Validate from VM shell:

   ```bash
   sudo -n true && echo SUDO_OK
   ```

### "Package 'nodejs' has no installation candidate"

**Problem**: NodeSource repository not properly configured by the upstream base tasks

**Solutions**:

1. Manually configure NodeSource (on VM):

   ```bash
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
   sudo apt update
   ```

2. Re-run the upstream submodule Node.js tasks:

   ```bash
   make deploy TAGS=nodejs
   ```

### "Failed to install openclaw via pnpm"

**Problem**: pnpm package doesn't exist or install fails

**Solutions**:

1. Install manually as the openclaw user:

   ```bash
   sudo su - openclaw
   pnpm install -g openclaw@latest
   ```

2. If OpenClaw isn't published to npm, install from git:

   ```bash
   sudo su - openclaw
   pnpm install -g "https://github.com/openclaw/openclaw"
   ```

### "Service failed to start"

**Problem**: OpenClaw service crashes on startup

**Solutions**:

1. Check logs on VM:

   ```bash
   ssh openclaw@192.168.100.10 "sudo journalctl -u openclaw -n 50 --no-pager"
   ```

2. Check if OpenClaw binary exists:

   ```bash
   ssh openclaw@192.168.100.10 "ls -la ~/.local/bin/openclaw"
   ```

3. Test OpenClaw manually:

   ```bash
   ssh openclaw@192.168.100.10
   export PATH=~/.local/bin:$PATH
   openclaw --help
   ```

4. Check environment variables:

   ```bash
   ssh openclaw@192.168.100.10 "cat ~/.openclaw/.env"
   ```

## Firewall Issues

### "UFW command failed"

**Problem**: UFW not available in test container or upstream firewall tasks require Docker

**Solutions**:

1. For Molecule tests, UFW may be disabled by default (see `molecule/default/molecule.yml`)

2. For VM deployment, ensure UFW is installed:

   ```bash
   ssh openclaw@192.168.100.10 "sudo apt install -y ufw"
   ```

3. If using upstream firewall tasks, confirm Docker is enabled:

   ```yaml
   vendor_firewall_enabled: true
   vendor_docker_enabled: true
   ```

### "Port 3000 not accessible"

**Problem**: Expected with secure defaults. Gateway binds to loopback and is not exposed directly to LAN.

**Solutions**:

1. Check if service is listening:

   ```bash
   ssh openclaw@192.168.100.10 "sudo ss -tulnp | grep 3000"
   ```

2. Check Nginx is the LAN ingress:

   ```bash
   ssh openclaw@192.168.100.10 "sudo systemctl status nginx --no-pager"
   ssh openclaw@192.168.100.10 "sudo ss -tulpen | grep -E ':(80|443)'"
   ```

3. Check UFW rules:

   ```bash
   ssh openclaw@192.168.100.10 "sudo ufw status verbose"
   ```

4. Test via HTTPS endpoint instead of direct gateway port:

   ```bash
   curl -kI https://openclaw.lan
   ```

5. Check Tailscale connectivity:

   ```bash
   tailscale ping <vm-tailscale-ip>
   ```

## 1Password Issues

### "op command not found"

**Problem**: 1Password CLI not installed

**Solutions**:

1. Re-run onepassword role:

   ```bash
   make deploy TAGS=onepassword
   ```

2. Manual installation on VM:

   ```bash
   ssh openclaw@192.168.100.10
   curl -sS https://downloads.1password.com/linux/debian/amd64/stable/1password-cli-amd64-latest.deb -o /tmp/op.deb
   sudo dpkg -i /tmp/op.deb
   ```

### "OP_SERVICE_ACCOUNT_TOKEN not set"

**Problem**: 1Password inject step fails because service account token is missing

**Solutions**:

1. Ensure vaulted variable is present:

   ```yaml
   # group_vars/vault.yml
   vault_openclaw_op_service_account_token: "ops_your_token"
   ```

2. Re-encrypt and rerun deploy:

   ```powershell
   docker run --rm -v "${PWD}:/work" -w /work python:3.11-bookworm bash -lc "python -m pip install --quiet ansible-core && ansible-vault encrypt group_vars/vault.yml --vault-password-file .vault_pass.txt"
   .\scripts\deploy-windows.ps1 -VaultPasswordFile .\.vault_pass.txt
   ```

### "OPENCLAW_GATEWAY_TOKEN missing"

**Problem**: OpenClaw service fails because gateway token was not injected from 1Password.

**Solutions**:

1. Verify 1Password item exists:

   - Vault: `OpenClaw`
   - Item: `OpenClaw Gateway`
   - Field: `credential`

2. Confirm rendered environment includes token key on VM:

   ```bash
   ssh openclaw@192.168.100.10 "sudo grep '^OPENCLAW_GATEWAY_TOKEN=' /home/openclaw/.openclaw/.env"
   ```

3. Re-run config-related tags:

   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --tags onepassword,openclaw,app,gateway,nginx,lan
   ```

## Molecule Issues

### "Docker not found"

**Problem**: Docker not installed or not running

**Solutions**:

1. Install Docker:

   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. Start Docker service:

   ```bash
   sudo systemctl start docker
   ```

### "Container creation failed"

**Problem**: Docker container won't start

**Solutions**:

1. Check Docker logs:

   ```bash
   docker logs <container_id>
   ```

2. Try with different image:

   ```yaml
   # In molecule/default/molecule.yml
   platforms:
     - name: openclaw-test
       image: ubuntu:24.04  # Use official Ubuntu image
   ```

3. Clean up and retry:

   ```bash
   molecule destroy
   docker system prune -f
   molecule test
   ```

### "Verify stage fails"

**Problem**: Verification tasks failing in tests

**Solutions**:

1. Check which test failed:

   ```bash
   molecule verify
   ```

2. Login to container for debugging:

   ```bash
   molecule login
   ```

3. Skip verify for initial testing:

   ```bash
   molecule converge  # Only converge, skip verify
   ```

## Performance Issues

### "Deployment is very slow"

**Solutions**:

1. Enable pipelining (already in ansible.cfg)

2. Reduce fact gathering:

   ```yaml
   # In site.yml
   gather_facts: no  # For specific plays
   ```

3. Use strategy plugin:

   ```yaml
   # In site.yml
   strategy: free  # Run tasks as fast as possible
   ```

### "VM is slow after deployment"

**Solutions**:

1. Check VM resources:

   ```powershell
   Get-VM -Name "OpenClaw-VM" | Select CPUUsage, MemoryAssigned
   ```

2. Increase VM resources if needed:

   ```powershell
   Set-VMMemory -VMName "OpenClaw-VM" -DynamicMemoryEnabled $true -MaximumBytes 4GB
   Set-VMProcessor -VMName "OpenClaw-VM" -Count 2
   ```

## Tailscale Issues

### "Tailscale not authenticated"

**Problem**: Tailscale installed but not connected

**Solutions**:

1. SSH to VM and authenticate:

   ```bash
   ssh openclaw@192.168.100.10
   sudo tailscale up
   ```

2. Use auth key for automation:

   ```bash
   # Get auth key from https://login.tailscale.com/admin/settings/keys
   ssh openclaw@192.168.100.10 "sudo tailscale up --auth-key=tskey-auth-..."
   ```

3. Check Tailscale status:

   ```bash
   ssh openclaw@192.168.100.10 "tailscale status"
   ```

## Recovery Procedures

### "Deployment broke everything"

1. **Restore from snapshot**:

   ```powershell
   # On Windows host
   Get-VMSnapshot -VMName "OpenClaw-VM"
   Restore-VMSnapshot -VMName "OpenClaw-VM" -Name "pre-deploy-20260205"
   ```

2. **Or rollback specific changes**:

   ```bash
   # Stop service
   ssh openclaw@192.168.100.10 "sudo systemctl stop openclaw"

   # Uninstall OpenClaw
   ssh openclaw@192.168.100.10 "pnpm remove -g openclaw"
   ```

### "Start fresh"

1. Create new VM or restore to clean state
2. Re-run complete deployment:

   ```bash
   make deploy
   ```

## Getting More Help

1. **Enable debug mode**:

   ```bash
   make deploy VERBOSE=-vvv
   ```

2. **Check specific role**:

   ```bash
   ansible-playbook site.yml --tags nodejs --check -vv
   ```

3. **Manual verification**:

   ```bash
   ssh openclaw@192.168.100.10
   # Check each component manually
   ```

4. **Check Ansible logs**:

   ```bash
   # Usually in /var/log/ansible.log or systemd journal
   ```

5. **Test individual tasks**:

   ```bash
   ansible openclaw_vms -i inventory/hosts.yml -m shell -a "node --version"
   ```
