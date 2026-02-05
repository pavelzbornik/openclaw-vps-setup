# OpenClaw Ansible Troubleshooting Guide

Common issues and solutions when deploying OpenClaw with Ansible.

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

### "Package 'nodejs' has no installation candidate"

**Problem**: NodeSource repository not properly configured

**Solutions**:

1. Manually configure NodeSource (on VM):

   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt update
   ```

2. Re-run nodejs role:

   ```bash
   make deploy TAGS=nodejs
   ```

### "Failed to install openclaw via npm"

**Problem**: npm package doesn't exist or name is wrong

**Solutions**:

1. Check the actual package name and update `group_vars/all.yml`:

   ```yaml
   openclaw_npm_package: "@openclaw/openclaw"  # Or actual package name
   ```

2. If OpenClaw isn't published to npm, install from git:

   ```yaml
   # In openclaw role tasks
   - name: Install OpenClaw from GitHub
     npm:
       name: "https://github.com/openclaw/openclaw"
       global: yes
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
   ssh openclaw@192.168.100.10 "ls -la ~/.npm-global/bin/openclaw"
   ```

3. Test OpenClaw manually:

   ```bash
   ssh openclaw@192.168.100.10
   export PATH=~/.npm-global/bin:$PATH
   openclaw --help
   ```

4. Check environment variables:

   ```bash
   ssh openclaw@192.168.100.10 "cat ~/.openclaw/.env"
   ```

## Firewall Issues

### "UFW command failed"

**Problem**: UFW not available in test container

**Solutions**:

1. For Molecule tests, UFW is disabled by default (see `molecule/default/molecule.yml`)

2. For VM deployment, ensure UFW is installed:

   ```bash
   ssh openclaw@192.168.100.10 "sudo apt install -y ufw"
   ```

### "Port 18789 not accessible"

**Problem**: Firewall blocking or service not listening

**Solutions**:

1. Check if service is listening:

   ```bash
   ssh openclaw@192.168.100.10 "sudo ss -tulnp | grep 18789"
   ```

2. Check UFW rules:

   ```bash
   ssh openclaw@192.168.100.10 "sudo ufw status verbose"
   ```

3. Temporarily allow all traffic for testing:

   ```bash
   ssh openclaw@192.168.100.10 "sudo ufw allow 18789/tcp"
   ```

4. Check Tailscale connectivity:

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

**Problem**: 1Password lookups failing

**Solutions**:

1. Set token before deployment:

   ```bash
   export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token"
   make deploy
   ```

2. Or skip 1Password and use environment variables directly:

   ```bash
   make deploy SKIP_TAGS=onepassword
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
   ssh openclaw@192.168.100.10 "npm uninstall -g @openclaw/openclaw"
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
