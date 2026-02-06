Great question! Let me explain OpenClaw's folder structure and show you exactly what to sync to git (and what NOT to).

## OpenClaw Directory Structure

```
~/.openclaw/                          # Main state directory
├── openclaw.json                     # Main configuration file ✅ GIT
├── credentials/                      # API keys, tokens ❌ NEVER GIT
│   ├── anthropic.json
│   ├── telegram.json
│   └── whatsapp-auth.json
├── workspace/                        # Agent workspace ✅ GIT (mostly)
│   ├── AGENTS.md                     # Agent behavior/instructions ✅ GIT
│   ├── SOUL.md                       # Agent personality ✅ GIT
│   ├── TOOLS.md                      # Tool documentation ✅ GIT
│   ├── IDENTITY.md                   # Agent identity ✅ GIT
│   ├── USER.md                       # User preferences ✅ GIT
│   ├── MEMORY.md                     # Long-term memory ⚠️ CAREFUL
│   └── skills/                       # Custom skills ✅ GIT
│       ├── homeassistant/
│       │   └── SKILL.md
│       └── custom-skill/
│           └── SKILL.md
├── sessions/                         # Chat history ❌ NEVER GIT
│   └── session-*.json
├── logs/                             # Log files ❌ NEVER GIT
│   └── openclaw-2026-02-06.log
└── skills/                           # Global skills (shared) ✅ GIT
    └── shared-skill/
        └── SKILL.md
```

---

## What to Backup to Git

### ✅ ALWAYS Commit (Configuration & Customization)

```
openclaw-config/                    # Your git repository
├── openclaw.json.template          # Config with secret references
├── workspace/
│   ├── AGENTS.md                   # Agent instructions
│   ├── SOUL.md                     # Personality
│   ├── TOOLS.md                    # Tool docs
│   ├── IDENTITY.md                 # Identity
│   ├── USER.md                     # User preferences
│   └── skills/                     # Custom skills
│       ├── homeassistant/SKILL.md
│       └── my-skill/SKILL.md
├── skills/                         # Shared skills
└── README.md                       # Your documentation
```

### ❌ NEVER Commit (Secrets & Private Data)

```
DO NOT COMMIT:
├── credentials/                    # Has actual API keys
├── sessions/                       # Private chat history
├── logs/                          # May contain sensitive info
├── openclaw.json                  # Has real secrets (use .template)
├── MEMORY.md                      # May contain personal info
└── *.token, *.key, *.secret      # Any credential files
```

---

## Step-by-Step Git Sync Setup

### 1. Create Your Config Repository

```bash
# On your dev machine or in WSL2
mkdir -p ~/openclaw-config
cd ~/openclaw-config

# Initialize git
git init
git branch -M main
```

### 2. Create Proper Structure

```bash
# Create directories
mkdir -p workspace/skills
mkdir -p skills

# Create .gitignore FIRST (very important!)
cat > .gitignore << 'EOF'
# Secrets - NEVER commit these
credentials/
*.token
*.key
*.secret
.env
secrets.yml
openclaw.json

# Session data - contains private conversations
sessions/
*.session

# Logs - may contain sensitive info
logs/
*.log

# Memory - may contain personal information
MEMORY.md

# Temporary files
*.tmp
*.swp
*~
.DS_Store

# Keep directory structure
!credentials/.gitkeep
!sessions/.gitkeep
!logs/.gitkeep
EOF
```

### 3. Create Config Template with Secret References

```bash
# Create openclaw.json.template
cat > openclaw.json.template << 'EOF'
{
  "agent": {
    "model": "anthropic/claude-opus-4-5"
  },
  "gateway": {
    "bind": "tailnet",
    "auth": {
      "mode": "token",
      "token": "op://OpenClaw-Secrets/Gateway/token"
    }
  },
  "channels": {
    "telegram": {
      "token": "op://OpenClaw-Secrets/API-Keys/telegram_token",
      "dmPolicy": "pairing",
      "groups": {
        "*": {
          "requireMention": true
        }
      }
    },
    "whatsapp": {
      "enabled": true,
      "dmPolicy": "pairing"
    }
  },
  "models": {
    "providers": {
      "anthropic": {
        "apiKey": "op://OpenClaw-Secrets/API-Keys/anthropic"  # pragma: allowlist secret
      },
      "openai": {
        "apiKey": "op://OpenClaw-Secrets/API-Keys/openai"  # pragma: allowlist secret
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "sandbox": {
        "mode": "non-main"
      }
    }
  }
}
EOF
```

### 4. Create Workspace Files

```bash
# Create AGENTS.md (agent instructions)
cat > workspace/AGENTS.md << 'EOF'
# Agent Instructions

## Core Behavior
- You are a helpful personal AI assistant
- You have access to Home Assistant to control smart home devices
- Always confirm before making changes to home automation

## Home Control Rules
- When user says "turn on/off X", map to appropriate Home Assistant entity
- For climate control, confirm target temperature before changing
- Never disable security systems without explicit confirmation

## Tool Usage
- Browser: Use for web automation when specifically requested
- Shell: Only for safe, non-destructive commands
- Home Assistant: Available for all home control requests
EOF

# Create SOUL.md (personality)
cat > workspace/SOUL.md << 'EOF'
# Agent Personality

You are a helpful, efficient home automation assistant. You:
- Speak concisely but friendly
- Confirm before taking actions that affect the physical world
- Explain what you're doing when controlling smart home devices
- Never make assumptions about user intent for home control
EOF

# Create USER.md (user preferences)
cat > workspace/USER.md << 'EOF'
# User Preferences

## Communication Style
- Prefer brief responses
- Use emojis sparingly

## Home Automation Defaults
- Evening mode: dim lights to 40%
- Movie mode: lights off, TV on
- Bedtime: lock doors, lights off, temperature to 68°F

## Timezone
America/New_York
EOF

# Create IDENTITY.md
cat > workspace/IDENTITY.md << 'EOF'
# Agent Identity

Name: HomeBot
Emoji: 🏠
Theme: Home automation assistant
EOF
```

### 5. Create README

```bash
cat > README.md << 'EOF'
# OpenClaw Configuration

Private configuration repository for my OpenClaw instance.

## Setup

1. Clone this repository to the VM
2. Use 1Password to inject secrets:
   ```bash
   op inject -i openclaw.json.template -o ~/.openclaw/openclaw.json
   ```
3. Symlink workspace files:
   ```bash
   ln -sf ~/openclaw-config/workspace/* ~/.openclaw/workspace/
   ```

## Files

- `openclaw.json.template` - Config with 1Password secret references
- `workspace/` - Agent personality and instructions
- `workspace/skills/` - Custom skills

## Secrets

All secrets are stored in 1Password vault "OpenClaw-Secrets":
- API keys
- Channel tokens
- Home Assistant token

Never commit actual secrets to this repository!
EOF
```

### 6. Connect to GitHub

```bash
# Create repository on GitHub (private!)
# Then push

git add .
git commit -m "Initial OpenClaw configuration"
git remote add origin git@github.com:yourusername/openclaw-config.git
git push -u origin main
```

---

## Automated Sync Script

Create `sync-openclaw-config.sh` on the VM:

```bash
#!/bin/bash
# Sync OpenClaw configuration to git
# Run this script periodically or after making changes

set -e

CONFIG_REPO="$HOME/openclaw-config"
OPENCLAW_DIR="$HOME/.openclaw"

cd "$CONFIG_REPO"

# Pull latest changes first
git pull

# Copy workspace files TO git repo (backup)
echo "Backing up workspace files..."
rsync -av --exclude='MEMORY.md' \
    "$OPENCLAW_DIR/workspace/" "$CONFIG_REPO/workspace/"

# Copy global skills
if [ -d "$OPENCLAW_DIR/skills" ]; then
    echo "Backing up global skills..."
    rsync -av "$OPENCLAW_DIR/skills/" "$CONFIG_REPO/skills/"
fi

# Create template from current config (strip secrets)
echo "Creating config template..."
if [ -f "$OPENCLAW_DIR/openclaw.json" ]; then
    # Replace actual secrets with 1Password references
    # This is a placeholder - adjust based on your actual secrets
    jq 'walk(if type == "string" and (startswith("sk-") or startswith("xox")) then "op://OpenClaw-Secrets/..." else . end)' \
        "$OPENCLAW_DIR/openclaw.json" > "$CONFIG_REPO/openclaw.json.template"
fi

# Check for changes
if [ -n "$(git status --porcelain)" ]; then
    echo "Changes detected, committing..."
    git add .
    git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
    git push
    echo "✅ Configuration synced to git"
else
    echo "No changes to sync"
fi
```

Make it executable:

```bash
chmod +x sync-openclaw-config.sh
```

---

## Automated Daily Backup

Create a systemd timer for automatic backups:

### Create service file

```bash
sudo tee /etc/systemd/system/openclaw-backup.service << 'EOF'
[Unit]
Description=Backup OpenClaw configuration to git

[Service]
Type=oneshot
User=openclaw
WorkingDirectory=/home/openclaw/openclaw-config
ExecStart=/home/openclaw/sync-openclaw-config.sh
EOF
```

### Create timer file

```bash
sudo tee /etc/systemd/system/openclaw-backup.timer << 'EOF'
[Unit]
Description=Daily OpenClaw configuration backup

[Timer]
OnCalendar=daily
OnBootSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

### Enable the timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw-backup.timer
sudo systemctl start openclaw-backup.timer

# Check status
systemctl status openclaw-backup.timer
```

---

## Manual Sync Commands

```bash
# Quick backup to git
cd ~/openclaw-config
./sync-openclaw-config.sh

# Deploy from git to OpenClaw
cd ~/openclaw-config
git pull
op inject -i openclaw.json.template -o ~/.openclaw/openclaw.json
ln -sf ~/openclaw-config/workspace/* ~/.openclaw/workspace/
docker restart openclaw
```

---

## Complete Ansible Playbook Task

Add this to your Ansible playbook:

```yaml
    - name: Setup git configuration sync
      become_user: "{{ ansible_user }}"
      block:
        - name: Clone configuration repository
          git:
            repo: "{{ openclaw_config_repo }}"
            dest: /home/{{ ansible_user }}/openclaw-config
            version: main
            key_file: /home/{{ ansible_user }}/.ssh/github_deploy_key

        - name: Create sync script
          copy:
            dest: /home/{{ ansible_user }}/sync-openclaw-config.sh
            mode: '0755'
            content: |
              #!/bin/bash
              # [paste script from above]

        - name: Inject secrets from 1Password
          shell: |
            export OP_SERVICE_ACCOUNT_TOKEN="{{ op_service_account_token }}"
            op inject -i openclaw.json.template -o ~/.openclaw/openclaw.json
          args:
            chdir: /home/{{ ansible_user }}/openclaw-config

        - name: Symlink workspace files
          file:
            src: "/home/{{ ansible_user }}/openclaw-config/workspace"
            dest: "/home/{{ ansible_user }}/.openclaw/workspace"
            state: link
            force: yes

        - name: Setup backup timer
          copy:
            dest: /etc/systemd/system/openclaw-backup.service
            content: |
              # [service file from above]

        - name: Enable backup timer
          systemd:
            name: openclaw-backup.timer
            enabled: yes
            state: started
            daemon_reload: yes
```

---

## What Gets Synced When

| File/Folder | Git Sync | Why |
|-------------|----------|-----|
| `openclaw.json.template` | ✅ Yes | Config structure (secrets as references) |
| `openclaw.json` | ❌ No | Contains actual secrets |
| `workspace/AGENTS.md` | ✅ Yes | Your agent customizations |
| `workspace/SOUL.md` | ✅ Yes | Personality definition |
| `workspace/USER.md` | ✅ Yes | User preferences |
| `workspace/MEMORY.md` | ⚠️ Maybe | May contain personal info - be careful |
| `workspace/skills/` | ✅ Yes | Your custom skills |
| `credentials/` | ❌ Never | API keys and tokens |
| `sessions/` | ❌ Never | Private chat history |
| `logs/` | ❌ Never | May leak sensitive data |

---

## Recovery Procedure

**If you lose your VM or need to restore:**

```bash
# 1. Clone your config
git clone git@github.com:yourusername/openclaw-config.git ~/openclaw-config

# 2. Inject secrets from 1Password
cd ~/openclaw-config
export OP_SERVICE_ACCOUNT_TOKEN="ops_xxxx"
op inject -i openclaw.json.template -o ~/.openclaw/openclaw.json

# 3. Link workspace
ln -sf ~/openclaw-config/workspace ~/.openclaw/workspace

# 4. Start OpenClaw
docker compose up -d
```

**Everything is restored!** (Except session history, which is ephemeral anyway)

This setup gives you version-controlled configuration with zero secrets in git. Perfect balance of safety and recoverability!
