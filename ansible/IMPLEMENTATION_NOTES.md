# OpenClaw Ansible Implementation - Important Notes

## 🚨 Critical Configuration Required

### 1. OpenClaw Installation

OpenClaw is installed via **pnpm** (upstream default) using `pnpm install -g openclaw@latest`.
The installation is handled by the upstream `openclaw` role task, delegated through `vendor_base`.

The installation mode is controlled by `openclaw_install_mode` in `group_vars/all.yml`:

- `release` (default): `pnpm install -g openclaw@latest`
- `development`: Git clone + `pnpm build` + link globally

---

## 📋 What Was Implemented

### Directory Structure

```
ansible/
├── inventory/
│   └── hosts.yml                    # VM connection details
├── group_vars/
│   └── all.yml                      # Global configuration variables
├── roles/
│   ├── common/                      # Base system setup
│   ├── openclaw_vendor_base/        # Wrapper around the official openclaw-ansible submodule
│   ├── openclaw_git/                # Config repo sync and migration
│   ├── openclaw/                    # OpenClaw installation & systemd unit
│   └── onepassword/                 # 1Password CLI setup
├── molecule/
│   └── default/                     # Molecule testing framework
├── scripts/
│   ├── deploy.sh                    # Main deployment script
│   └── setup-ssh.sh                 # SSH access setup
├── site.yml                         # Main playbook
├── requirements.yml                 # Ansible Galaxy dependencies
├── ansible.cfg                      # Ansible configuration
├── Makefile                         # Convenience commands
├── README.md                        # Full documentation
├── QUICKSTART.md                    # Step-by-step guide
├── TROUBLESHOOTING.md               # Problem solutions
└── secrets-EXAMPLE.yml              # Secrets template

```

### Roles Breakdown

#### 1. Common Role

- Updates system packages
- Installs extra packages (python3-pip, acl)
- Sets timezone and locale

#### 2. Upstream Submodule (Official)

This workspace includes the official playbook as a git submodule at <https://github.com/openclaw/openclaw-ansible> and extends it via the `openclaw_vendor_base` role:

- Node.js + pnpm install (upstream)
- Tailscale install (upstream)

This avoids duplicating community work while keeping OpenClaw-specific configuration, systemd service, and 1Password integration local.
See `ansible/UPSTREAM_OPENCLAW_ANSIBLE.md` for details.

#### 3. OpenClaw Role

- Deploys configuration templates (openclaw.json, .env)
- Sets up systemd service
- Configures log rotation
- Optional onboarding and doctor commands

#### 4. 1Password Role

- Downloads and installs 1Password CLI
- Tests connection to 1Password vaults
- Enables secret lookup in playbooks

#### 5. OpenClaw Git Role

- Clones a separate OpenClaw config repo
- Writes a safe `.gitignore` if missing
- Generates `openclaw.json.template` for initial setup
- Optionally migrates workspace content

### Testing with Molecule

Molecule provides Docker-based testing **before** deploying to your actual VM:

1. **Create**: Spins up Ubuntu 24.04 container with systemd
2. **Converge**: Applies the playbook
3. **Verify**: Runs validation tests
4. **Destroy**: Cleans up

This lets you validate the playbook safely!

---

## ⚙️ Configuration Points

### Required Customization

1. **VM IP Address**: Update `inventory/hosts.yml` if not using 192.168.100.10

2. **Secrets**: Choose one approach:
   - Environment variables
   - Edit `group_vars/all.yml`
   - Use 1Password (set `OP_SERVICE_ACCOUNT_TOKEN`)
   - Use ansible-vault: `ansible-vault encrypt secrets.yml`

3. **Gateway Token**: Set `OPENCLAW_GATEWAY_TOKEN` env var (mandatory, no default)

### Optional Customization

- **Timezone**: Change in `group_vars/all.yml` → `timezone`
- **Upstream Submodule**: Enable/disable Node.js, Tailscale, Docker, firewall via `vendor_*` flags
- **Node.js Version**: Change in `group_vars/all.yml` → `nodejs_version`
- **OpenClaw Configuration**: Edit template in `roles/openclaw_app/templates/openclaw.json.j2` (used for config repo template)

---

## 🔐 Security Considerations

### What's Implemented

✅ OpenClaw runs as non-root user (`openclaw`)  
✅ UFW firewall with restrictive rules (via upstream firewall tasks when enabled)  
✅ SSH with key-based authentication  
✅ fail2ban for SSH brute-force protection  
✅ Automatic security updates enabled  
✅ Port 3000 restricted by upstream firewall rules (when enabled)  
✅ SMB/NetBIOS ports blocked (when upstream firewall is enabled)  
✅ systemd service hardening (NoNewPrivileges, ProtectSystem, etc.)

### What's NOT Implemented

❌ **Docker isolation**  

- OpenClaw runs natively on the VM
- Docker may still be installed by upstream baseline tasks if enabled

❌ **SSL/TLS termination**  

- No Nginx reverse proxy
- Direct connection to OpenClaw on port 3000
- Add Nginx later if needed

❌ **Auto-rotation of secrets**  

- Secrets are static in config/env files
- Use 1Password for better secret management

---

## 🚀 Deployment Workflow

### Recommended First-Time Deployment

```bash
# 1. Setup SSH access
cd ansible
chmod +x scripts/*.sh
./scripts/setup-ssh.sh

# 2. Test connectivity
ansible all -i inventory/hosts.yml -m ping

# 3. Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# 4. Test in Docker (optional but recommended)
molecule test

# 5. Dry-run on actual VM
./scripts/deploy.sh --check -vv

# 6. Deploy for real
./scripts/deploy.sh

# 7. SSH to VM and complete setup
ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10
sudo tailscale up                    # Authenticate Tailscale
nano ~/.openclaw/.env                # Add API keys
sudo systemctl start openclaw        # Start service
sudo journalctl -u openclaw -f       # Watch logs
```

### Using Makefile (Easier)

```bash
make ssh-setup    # Setup SSH
make test         # Run Molecule tests
make check        # Dry-run deployment
make deploy       # Deploy to VM
make logs         # View logs
make status       # Check service
```

---

## 🐛 Known Limitations & TODOs

### Limitations

1. **No Docker isolation**
   - OpenClaw runs directly on VM
   - Trade-off for simpler setup per requirements

2. **Manual Tailscale authentication**
   - Requires SSH to VM and running `tailscale up`
   - Could be automated with auth key

3. **Static secrets**
   - Secrets in files or environment variables
   - 1Password integration partially implemented

### Future Enhancements

- [ ] Auto-configure Tailscale with auth key
- [ ] Add Nginx reverse proxy role
- [ ] Implement SSL/TLS with Let's Encrypt
- [ ] Add monitoring role (Prometheus/Grafana)
- [ ] Create backup/restore playbooks
- [ ] Add CI/CD pipeline integration
- [ ] Support multiple OpenClaw instances
- [ ] Add Discord/Telegram channel provisioning
- [ ] Integrate with Home Assistant

---

## 📚 Documentation Index

- **README.md**: Complete documentation with architecture, roles, and usage
- **QUICKSTART.md**: Step-by-step guide for first-time deployment
- **TROUBLESHOOTING.md**: Common issues and solutions
- **molecule/README.md**: Testing framework documentation
- **This file**: Implementation notes and critical configurations

---

## 🔄 Updating OpenClaw

```bash
# Re-run OpenClaw role to update
make deploy TAGS=openclaw

# Or manually on VM
ssh openclaw@192.168.100.10
pnpm update -g openclaw@latest
sudo systemctl restart openclaw
```

---

## 💾 Backup Strategy

### VM Snapshots (Recommended)

```powershell
# On Windows host - create snapshot before deployment
Checkpoint-VM -Name "OpenClaw-VM" -SnapshotName "pre-deploy-$(Get-Date -Format 'yyyyMMdd-HHmm')"

# Restore if needed
Restore-VMSnapshot -VMName "OpenClaw-VM" -Name "pre-deploy-20260205-1015"
```

### Configuration Backups

```bash
# Backup OpenClaw config
ssh openclaw@192.168.100.10 "tar -czf ~/openclaw-backup-$(date +%Y%m%d).tar.gz .openclaw/"

# Copy to local
scp -i ~/.ssh/openclaw_vm openclaw@192.168.100.10:~/openclaw-backup-*.tar.gz ./backups/
```

---

## 🤝 Contributing

If you find issues or make improvements:

1. Update the relevant role in `roles/`
2. Test with `molecule test`
3. Update documentation
4. Commit changes

---

## 📞 Support

**Where to get help:**

1. Check `TROUBLESHOOTING.md` for common issues
2. Review logs: `make logs`
3. Test connectivity: `make ping`
4. Run diagnostics: `ansible openclaw_vms -i inventory/hosts.yml -m setup`
5. Re-read `QUICKSTART.md` for step-by-step guidance

---

## ✅ Pre-Deployment Checklist

Before running deployment:

- [ ] VM is running and accessible
- [ ] SSH key setup completed (`./scripts/setup-ssh.sh`)
- [ ] Connectivity test passed (`make ping`)
- [ ] Inventory file updated with correct IP
- [ ] Secrets configured (environment vars or 1Password)
- [ ] OpenClaw pnpm package verified
- [ ] VM snapshot created (optional but recommended)
- [ ] Molecule tests passed (optional)

---

**Good luck with your OpenClaw deployment! 🚀**
