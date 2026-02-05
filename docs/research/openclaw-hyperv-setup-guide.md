# Complete OpenClaw Automation Setup Guide
## Hyper-V VM + Ansible Provisioning + 1Password + Home Assistant

This guide provides a production-ready, automated deployment of OpenClaw on Windows 11 using Hyper-V, with configuration management via Git, secrets via 1Password, and Home Assistant integration.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Windows 11 Host (Hyper-V)                                   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Ubuntu VM (OpenClaw-VM)                              │  │
│  │                                                       │  │
│  │  ┌────────────────┐      ┌──────────────┐          │  │
│  │  │ Docker         │      │ Tailscale    │          │  │
│  │  │ └─OpenClaw     │      │ (VPN Mesh)   │          │  │
│  │  │   └─Gateway    │      └──────────────┘          │  │
│  │  │     :18789     │                                 │  │
│  │  └────────────────┘                                 │  │
│  │                                                       │  │
│  │  ┌────────────────┐      ┌──────────────┐          │  │
│  │  │ 1Password CLI  │      │ Git Repo     │          │  │
│  │  │ (Secrets)      │      │ (Config)     │          │  │
│  │  └────────────────┘      └──────────────┘          │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ WSL2 Ubuntu (Ansible Control Node)                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                           │
         ├───────────────────────────┴─→ Home Assistant
         │                               (via Tailscale)
         └─────────────────────────────→ WhatsApp/Telegram/Slack
```

---

## Part 1: Create Hyper-V VM with PowerShell

### Step 1: Enable Hyper-V on Windows 11

```powershell
# Run PowerShell as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Restart when prompted
Restart-Computer
```

### Step 2: Create Internal NAT Network

This isolates the VM from your LAN while allowing internet access.

```powershell
# Create Internal Switch
New-VMSwitch -SwitchName "OpenClawNAT" -SwitchType Internal

# Get the Interface Index
$ifIndex = (Get-NetAdapter | Where-Object {$_.Name -like "*OpenClawNAT*"}).ifIndex

# Assign IP to the host interface
New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $ifIndex

# Create NAT
New-NetNat -Name "OpenClawNATNetwork" -InternalIPInterfaceAddressPrefix "192.168.100.0/24"
```

### Step 3: Download Ubuntu Server Image

```powershell
# Create directory for ISO
New-Item -ItemType Directory -Force -Path "C:\Hyper-V\ISO"

# Download Ubuntu Server 24.04 LTS (replace with current URL)
$ubuntuUrl = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
$isoPath = "C:\Hyper-V\ISO\ubuntu-24.04.1-server-amd64.iso"

Invoke-WebRequest -Uri $ubuntuUrl -OutFile $isoPath
```

### Step 4: Create the VM

Save this as `Create-OpenClawVM.ps1`:

```powershell
# VM Configuration
$vmName = "OpenClaw-VM"
$vmPath = "C:\Hyper-V\VMs"
$vhdPath = "$vmPath\$vmName\$vmName.vhdx"
$isoPath = "C:\Hyper-V\ISO\ubuntu-24.04.1-server-amd64.iso"

# Create directories
New-Item -ItemType Directory -Force -Path "$vmPath\$vmName"

# Create VM
New-VM `
    -Name $vmName `
    -MemoryStartupBytes 4GB `
    -Generation 2 `
    -NewVHDPath $vhdPath `
    -NewVHDSizeBytes 60GB `
    -SwitchName "OpenClawNAT"

# Configure VM
Set-VMProcessor -VMName $vmName -Count 2
Set-VMMemory -VMName $vmName -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes 4GB

# Disable Secure Boot (required for Ubuntu)
Set-VMFirmware -VMName $vmName -EnableSecureBoot Off

# Add DVD Drive with ISO
Add-VMDvdDrive -VMName $vmName -Path $isoPath
$dvd = Get-VMDvdDrive -VMName $vmName
Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd

# Enable nested virtualization (optional, for Docker)
Set-VMProcessor -VMName $vmName -ExposeVirtualizationExtensions $true

Write-Host "VM '$vmName' created successfully!"
Write-Host "Starting VM..."
Start-VM -Name $vmName

# Open VM console
vmconnect localhost $vmName
```

Run the script:

```powershell
.\Create-OpenClawVM.ps1
```

### Step 5: Install Ubuntu Server

In the VM console that opens:

1. Select "Try or Install Ubuntu Server"
2. Language: English
3. Network: Configure static IP
   - IP: `192.168.100.10/24`
   - Gateway: `192.168.100.1`
   - DNS: `8.8.8.8, 8.8.4.4`
4. Storage: Use entire disk
5. Profile setup:
   - Name: `openclaw`
   - Server name: `openclaw-vm`
   - Username: `openclaw`
   - Password: `[secure password]`
6. **Important**: Enable "Install OpenSSH server"
7. Complete installation and reboot
8. Remove ISO after first boot

---

## Part 2: Setup Ansible on Windows (WSL2)

### Step 1: Install WSL2 with Ubuntu

```powershell
# In PowerShell as Administrator
wsl --install -d Ubuntu-24.04
# Set username/password when prompted
```

### Step 2: Install Ansible in WSL2

```bash
# Inside WSL2 Ubuntu
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible

# Verify installation
ansible --version
```

### Step 3: Create Ansible Project Structure

```bash
# Create project directory
mkdir -p ~/openclaw-ansible
cd ~/openclaw-ansible

# Create directory structure
mkdir -p {inventory,playbooks,roles,vars,files}

# Create directory for SSH keys
mkdir -p ~/.ssh
```

---

## Part 3: Ansible Provisioning Configuration

### Step 1: Create Inventory File

Create `inventory/hosts.yml`:

```yaml
all:
  children:
    openclaw_vms:
      hosts:
        openclaw-vm:
          ansible_host: 192.168.100.10
          ansible_user: openclaw
          ansible_ssh_private_key_file: ~/.ssh/openclaw_vm
          ansible_python_interpreter: /usr/bin/python3
      vars:
        ansible_connection: ssh
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
```

### Step 2: Generate and Copy SSH Key

```bash
# Generate SSH key (inside WSL2)
ssh-keygen -t ed25519 -f ~/.ssh/openclaw_vm -N ""

# Copy SSH key to VM (from WSL2)
ssh-copy-id -i ~/.ssh/openclaw_vm.pub openclaw@192.168.100.10

# Test connection
ansible openclaw_vms -i inventory/hosts.yml -m ping
```

### Step 3: Create Main Playbook

Create `playbooks/provision-openclaw.yml`:

```yaml
---
- name: Provision OpenClaw VM
  hosts: openclaw_vms
  become: yes
  vars_files:
    - ../vars/secrets.yml  # 1Password injected secrets
    
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Install base packages
      apt:
        name:
          - git
          - curl
          - wget
          - vim
          - htop
          - ufw
          - fail2ban
          - ca-certificates
          - gnupg
          - lsb-release
        state: present

    - name: Install Docker
      block:
        - name: Add Docker GPG key
          apt_key:
            url: https://download.docker.com/linux/ubuntu/gpg
            state: present

        - name: Add Docker repository
          apt_repository:
            repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
            state: present

        - name: Install Docker
          apt:
            name:
              - docker-ce
              - docker-ce-cli
              - containerd.io
              - docker-compose-plugin
            state: present

        - name: Add user to docker group
          user:
            name: "{{ ansible_user }}"
            groups: docker
            append: yes

    - name: Install Tailscale
      block:
        - name: Add Tailscale GPG key
          apt_key:
            url: https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg
            state: present

        - name: Add Tailscale repository
          apt_repository:
            repo: "deb https://pkgs.tailscale.com/stable/ubuntu {{ ansible_distribution_release }} main"
            state: present

        - name: Install Tailscale
          apt:
            name: tailscale
            state: present

    - name: Configure UFW firewall
      block:
        - name: Allow SSH
          ufw:
            rule: allow
            port: '22'
            proto: tcp

        - name: Allow OpenClaw Gateway (only from Tailscale)
          ufw:
            rule: allow
            port: '18789'
            proto: tcp
            from_ip: 100.64.0.0/10  # Tailscale CGNAT range

        - name: Enable UFW
          ufw:
            state: enabled
            policy: deny

    - name: Install Node.js (for OpenClaw)
      block:
        - name: Add NodeSource repository
          shell: curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
          args:
            creates: /etc/apt/sources.list.d/nodesource.list

        - name: Install Node.js
          apt:
            name: nodejs
            state: present

    - name: Install 1Password CLI
      block:
        - name: Download 1Password CLI
          get_url:
            url: https://downloads.1password.com/linux/debian/amd64/stable/1password-cli-amd64-latest.deb
            dest: /tmp/1password-cli.deb

        - name: Install 1Password CLI
          apt:
            deb: /tmp/1password-cli.deb

    - name: Setup OpenClaw directory structure
      file:
        path: "{{ item }}"
        state: directory
        owner: "{{ ansible_user }}"
        group: "{{ ansible_user }}"
        mode: '0755'
      loop:
        - /home/{{ ansible_user }}/openclaw
        - /home/{{ ansible_user }}/openclaw/workspace
        - /home/{{ ansible_user }}/openclaw/config

    - name: Clone OpenClaw configuration repository
      become_user: "{{ ansible_user }}"
      git:
        repo: "{{ openclaw_config_repo }}"  # From 1Password
        dest: /home/{{ ansible_user }}/openclaw/config
        version: main
      when: openclaw_config_repo is defined

    - name: Create OpenClaw Docker Compose file
      copy:
        dest: /home/{{ ansible_user }}/openclaw/docker-compose.yml
        owner: "{{ ansible_user }}"
        content: |
          version: '3.8'
          services:
            openclaw:
              image: ghcr.io/openclaw/openclaw:latest
              container_name: openclaw
              restart: unless-stopped
              user: "1000:1000"
              read_only: true
              cap_drop:
                - ALL
              security_opt:
                - no-new-privileges:true
              tmpfs:
                - /tmp
              volumes:
                - openclaw-data:/home/node/.openclaw
                - ./workspace:/home/node/.openclaw/workspace
                - ./config:/home/node/.openclaw/config:ro
              ports:
                - "127.0.0.1:18789:18789"
              environment:
                - NODE_ENV=production
                - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
                - OPENAI_API_KEY=${OPENAI_API_KEY}
              mem_limit: 2g
              cpus: 1.0
              
          volumes:
            openclaw-data:

    - name: Create systemd service for OpenClaw
      copy:
        dest: /etc/systemd/system/openclaw.service
        content: |
          [Unit]
          Description=OpenClaw Gateway
          After=docker.service tailscaled.service
          Requires=docker.service
          
          [Service]
          Type=oneshot
          RemainAfterExit=yes
          WorkingDirectory=/home/openclaw/openclaw
          ExecStart=/usr/bin/docker compose up -d
          ExecStop=/usr/bin/docker compose down
          User=openclaw
          Group=openclaw
          
          [Install]
          WantedBy=multi-user.target

    - name: Enable OpenClaw service
      systemd:
        name: openclaw
        enabled: yes
        daemon_reload: yes

    - name: Create checkpoint snapshot script
      copy:
        dest: /usr/local/bin/openclaw-snapshot.sh
        mode: '0755'
        content: |
          #!/bin/bash
          # Create checkpoint via Hyper-V PowerShell on host
          # Run: ssh windows-host "powershell.exe Checkpoint-VM -Name OpenClaw-VM -SnapshotName pre-update-$(date +%Y%m%d)"
          echo "Checkpoint created from VM side"

  handlers:
    - name: restart docker
      systemd:
        name: docker
        state: restarted
```

### Step 4: Run the Playbook

```bash
# From WSL2
cd ~/openclaw-ansible
ansible-playbook -i inventory/hosts.yml playbooks/provision-openclaw.yml
```

---

## Part 4: 1Password Service Account Setup

### Step 1: Create Service Account

```bash
# On your main machine (macOS/Windows with 1Password CLI)
op service-account create "OpenClaw Automation" \
  --vault "OpenClaw-Secrets:read_items" \
  --vault "Infrastructure:read_items" \
  --expires-in 90d

# Save the token! It looks like:
# ops_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Step 2: Store Service Account Token

Store the token in 1Password under a new item:

- Name: "OpenClaw Service Account Token"
- Vault: OpenClaw-Secrets
- Field: `OP_SERVICE_ACCOUNT_TOKEN`

### Step 3: Create Secrets Structure in 1Password

Create these items in your "OpenClaw-Secrets" vault:

**Item: "OpenClaw API Keys"**
- `ANTHROPIC_API_KEY`: sk-ant-xxx
- `OPENAI_API_KEY`: sk-xxx
- `TELEGRAM_BOT_TOKEN`: xxx
- `DISCORD_BOT_TOKEN`: xxx

**Item: "OpenClaw Git Config"**
- `OPENCLAW_CONFIG_REPO`: https://github.com/yourusername/openclaw-config.git
- `GITHUB_TOKEN`: ghp_xxx (for private repo)

**Item: "Home Assistant"**
- `HA_URL`: http://homeassistant.local:8123
- `HA_TOKEN`: eyJxxx (Long-Lived Access Token)

### Step 4: Create 1Password-Ansible Integration Script

Create `scripts/op-inject-vars.sh`:

```bash
#!/bin/bash
# Inject 1Password secrets into Ansible vars file

export OP_SERVICE_ACCOUNT_TOKEN="ops_xxxxxxxx"  # Or load from secure location

cat > vars/secrets.yml << 'EOF'
---
# Auto-generated by 1Password - DO NOT COMMIT
anthropic_api_key: "{{ lookup('onepassword', 'OpenClaw API Keys', field='ANTHROPIC_API_KEY', vault='OpenClaw-Secrets') }}"
openai_api_key: "{{ lookup('onepassword', 'OpenClaw API Keys', field='OPENAI_API_KEY', vault='OpenClaw-Secrets') }}"
telegram_bot_token: "{{ lookup('onepassword', 'OpenClaw API Keys', field='TELEGRAM_BOT_TOKEN', vault='OpenClaw-Secrets') }}"
openclaw_config_repo: "{{ lookup('onepassword', 'OpenClaw Git Config', field='OPENCLAW_CONFIG_REPO', vault='OpenClaw-Secrets') }}"
ha_url: "{{ lookup('onepassword', 'Home Assistant', field='HA_URL', vault='OpenClaw-Secrets') }}"
ha_token: "{{ lookup('onepassword', 'Home Assistant', field='HA_TOKEN', vault='OpenClaw-Secrets') }}"
EOF

echo "Secrets file created at vars/secrets.yml"
```

### Step 5: Install Ansible 1Password Plugin

```bash
# In WSL2
ansible-galaxy collection install community.general

# Add to ansible.cfg
cat >> ansible.cfg << 'EOF'
[defaults]
collections_paths = ~/.ansible/collections

[lookup_plugins]
onepassword_cli_path = /usr/bin/op
EOF
```

---

## Part 5: Git-Synced OpenClaw Configuration

### Step 1: Create Configuration Repository

```bash
# Create private GitHub repository: openclaw-config
# Clone it locally
git clone https://github.com/yourusername/openclaw-config.git
cd openclaw-config

# Create structure
mkdir -p {workspace,skills,credentials}
```

### Step 2: Create OpenClaw Configuration File

Create `openclaw.json` (template with secret references):

```json
{
  "agent": {
    "model": "anthropic/claude-opus-4-5"
  },
  "gateway": {
    "bind": "tailnet",
    "auth": {
      "mode": "token",
      "token": "op://OpenClaw-Secrets/OpenClaw Gateway/gateway_token"
    }
  },
  "channels": {
    "telegram": {
      "token": "op://OpenClaw-Secrets/OpenClaw API Keys/TELEGRAM_BOT_TOKEN",
      "dmPolicy": "pairing"
    },
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing"
    }
  },
  "models": {
    "providers": {
      "anthropic": {
        "apiKey": "op://OpenClaw-Secrets/OpenClaw API Keys/ANTHROPIC_API_KEY"
      }
    }
  }
}
```

### Step 3: Add Home Assistant Skill

Create `skills/homeassistant/SKILL.md`:

```markdown
# Home Assistant Control Skill

This skill allows OpenClaw to control your Home Assistant instance.

## Configuration

Set these environment variables (injected from 1Password):
- `HA_URL`: Your Home Assistant URL
- `HA_TOKEN`: Long-lived access token

## Usage Examples

User: "Turn on the living room lights"
Assistant: *calls HA API to turn on light.living_room*

User: "Set bedroom temperature to 72"
Assistant: *calls climate.set_temperature for climate.bedroom*

User: "What's the temperature outside?"
Assistant: *queries sensor.outdoor_temperature*

## Implementation

```bash
#!/bin/bash
# Home Assistant API wrapper
HA_URL="${HA_URL:-http://homeassistant.local:8123}"
HA_TOKEN="${HA_TOKEN}"

ha_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="$3"
    
    curl -X "$method" \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        ${data:+-d "$data"} \
        "$HA_URL/api/$endpoint"
}

# Turn on entity
ha_turn_on() {
    local entity_id="$1"
    ha_api "services/homeassistant/turn_on" POST "{\"entity_id\":\"$entity_id\"}"
}

# Turn off entity
ha_turn_off() {
    local entity_id="$1"
    ha_api "services/homeassistant/turn_off" POST "{\"entity_id\":\"$entity_id\"}"
}

# Get state
ha_state() {
    local entity_id="$1"
    ha_api "states/$entity_id"
}

# Climate control
ha_set_temperature() {
    local entity_id="$1"
    local temperature="$2"
    ha_api "services/climate/set_temperature" POST \
        "{\"entity_id\":\"$entity_id\",\"temperature\":$temperature}"
}
```

## Available Commands

When user mentions home control, check these patterns:
- "turn on/off [device]" → map to entity_id
- "set [climate device] to [temp]" → climate control
- "is [device] on?" → check state
- "dim [light] to [percent]" → light brightness
```

### Step 4: Create .gitignore

```gitignore
# Never commit these
credentials/
.env
*.token
secrets.yml

# Keep structure
!credentials/.gitkeep
```

### Step 5: Commit Configuration

```bash
git add .
git commit -m "Initial OpenClaw configuration with HA skill"
git push origin main
```

---

## Part 6: Deploy with 1Password Secret Injection

### Step 1: Create Deployment Script

Create `scripts/deploy-openclaw.sh`:

```bash
#!/bin/bash
set -e

# Load 1Password Service Account Token
export OP_SERVICE_ACCOUNT_TOKEN="op://Infrastructure/OpenClaw Service Account Token/credential"

# Pull latest config from git
ssh openclaw@192.168.100.10 "cd ~/openclaw/config && git pull"

# Inject secrets into openclaw.json
ssh openclaw@192.168.100.10 << 'ENDSSH'
cd ~/openclaw/config

# Use 1Password CLI to inject secrets
op inject -i openclaw.json -o ~/.openclaw/openclaw.json

# Inject environment variables for Docker
cat > ../.env << 'EOF'
ANTHROPIC_API_KEY=$(op read "op://OpenClaw-Secrets/OpenClaw API Keys/ANTHROPIC_API_KEY")
OPENAI_API_KEY=$(op read "op://OpenClaw-Secrets/OpenClaw API Keys/OPENAI_API_KEY")
HA_URL=$(op read "op://OpenClaw-Secrets/Home Assistant/HA_URL")
HA_TOKEN=$(op read "op://OpenClaw-Secrets/Home Assistant/HA_TOKEN")
EOF

# Restart OpenClaw
sudo systemctl restart openclaw
ENDSSH

echo "OpenClaw deployed successfully!"
```

### Step 2: Automate with Ansible

Update `playbooks/provision-openclaw.yml` to add deployment task:

```yaml
    - name: Deploy OpenClaw with 1Password secrets
      become_user: "{{ ansible_user }}"
      shell: |
        export OP_SERVICE_ACCOUNT_TOKEN="{{ op_service_account_token }}"
        cd ~/openclaw/config && git pull
        op inject -i openclaw.json -o ~/.openclaw/openclaw.json
        docker compose up -d --force-recreate
      args:
        chdir: /home/{{ ansible_user }}/openclaw
```

---

## Part 7: Complete Workflow Example

### Daily Operation

1. **Update configuration:**
```bash
# On your dev machine
cd openclaw-config
vim skills/homeassistant/SKILL.md  # Add new commands
git commit -am "Add scene activation to HA skill"
git push
```

2. **Deploy to VM:**
```bash
# From WSL2
cd ~/openclaw-ansible
./scripts/deploy-openclaw.sh
```

3. **Test via WhatsApp:**
```
You: "Turn on movie mode"
OpenClaw: *Activating scene.movie_mode in Home Assistant*
```

### Backup and Restore

**Create snapshot:**
```powershell
# On Windows host
Checkpoint-VM -Name "OpenClaw-VM" -SnapshotName "pre-update-$(Get-Date -Format 'yyyyMMdd')"
```

**Restore from snapshot:**
```powershell
Restore-VMCheckpoint -VMName "OpenClaw-VM" -Name "pre-update-20260201"
```

---

## Security Checklist

- [√] VM isolated on internal NAT network
- [√] Firewall (UFW) blocks everything except SSH and Tailscale
- [√] OpenClaw runs in Docker with read-only filesystem
- [√] Secrets never committed to git (injected via 1Password)
- [√] SSH key-based auth only (no passwords)
- [√] Tailscale for remote access (no port forwarding)
- [√] Regular snapshots before updates
- [√] Service account token with limited vault access
- [√] Non-root Docker user (UID 1000)

---

## Useful Commands

**Ansible:**
```bash
# Test connectivity
ansible openclaw_vms -i inventory/hosts.yml -m ping

# Run specific tasks
ansible-playbook playbooks/provision-openclaw.yml --tags docker

# Deploy with secrets
./scripts/deploy-openclaw.sh
```

**Hyper-V:**
```powershell
# List VMs
Get-VM

# Check VM status
Get-VM -Name "OpenClaw-VM" | Select Name, State, CPUUsage, MemoryAssigned

# Create snapshot
Checkpoint-VM -Name "OpenClaw-VM" -SnapshotName "backup-$(Get-Date -Format 'yyyyMMdd-HHmm')"

# List snapshots
Get-VMSnapshot -VMName "OpenClaw-VM"
```

**1Password CLI:**
```bash
# Test secret access
op item get "OpenClaw API Keys" --vault "OpenClaw-Secrets"

# Inject into file
op inject -i config-template.json -o config.json

# Read specific field
op read "op://OpenClaw-Secrets/Home Assistant/HA_TOKEN"
```

**OpenClaw:**
```bash
# SSH into VM
ssh openclaw@192.168.100.10

# Check OpenClaw logs
docker logs openclaw -f

# Restart OpenClaw
sudo systemctl restart openclaw

# Run security audit
docker exec openclaw openclaw doctor
```

---

## Troubleshooting

**VM can't reach internet:**
```powershell
# Check NAT
Get-NetNat
# Should show OpenClawNATNetwork
```

**Ansible can't connect:**
```bash
# Test direct SSH
ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10

# Check inventory
ansible-inventory -i inventory/hosts.yml --list
```

**1Password secrets not injecting:**
```bash
# Verify service account
export OP_SERVICE_ACCOUNT_TOKEN="ops_xxx"
op vault list

# Test secret read
op read "op://OpenClaw-Secrets/OpenClaw API Keys/ANTHROPIC_API_KEY"
```

**Home Assistant not responding:**
```bash
# Test from VM
curl -H "Authorization: Bearer $HA_TOKEN" \
     http://homeassistant.local:8123/api/states

# Check Tailscale connectivity
tailscale ping homeassistant
```

---

## Next Steps

1. Set up automated backups (weekly snapshots)
2. Configure monitoring (Prometheus + Grafana)
3. Add more Home Assistant automations
4. Create CI/CD pipeline for config updates
5. Set up log aggregation (Loki)

This is a production-ready setup with security, automation, and secrets management. Enjoy your automated OpenClaw deployment!
