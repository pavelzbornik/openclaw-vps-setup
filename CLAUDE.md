# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Maintenance

When implementing any new feature, role, playbook, or variable, **always update the following docs as part of the same task** — do not wait to be asked:

| File | Update when |
|------|-------------|
| `README.md` | New role, capability, or feature flag added |
| `ansible/README.md` | New role (directory tree + Roles section + 1Password table if applicable) |
| `ansible/QUICKSTART.md` | New 1Password item required, new post-deploy verification step, or new optional setup step |
| `CLAUDE.md` — Playbook Execution Order | New role added to `site.yml` |
| `CLAUDE.md` — 1Password Item Structure | New 1Password vault item added |
| `CLAUDE.md` — Common Commands | New deploy tag or one-time setup command added |
| `docs/firewall.md` | New ports opened by UFW |
| `Justfile` | New recipe added to task runner |

## Project Purpose

Infrastructure-as-Code for automated provisioning and deployment of the OpenClaw AI agent (a Node.js autonomous assistant) on Ubuntu VPS or Hyper-V VMs. Uses Ansible with an upstream `openclaw-ansible` git submodule for the base Node.js/Tailscale/firewall stack.

## Common Commands

All task-runner commands use `just` from the repo root (no `cd ansible/` needed):

```bash
# Install just (if not yet available)
sudo apt-get install -y just        # Ubuntu/Debian
# or: curl -sSL https://just.systems/install.sh | bash -s -- --to ~/.local/bin

# Install Ansible and dependencies (first-time setup)
just install

# Install Ansible Galaxy collections only
just galaxy

# Run Molecule tests (Docker required)
just test

# Lint playbooks
just lint

# Dry-run deployment
just check

# Deploy to production VM
just deploy

# Deploy only specific roles (use tags)
just deploy tags=openclaw
just deploy tags=common
just deploy tags=vendor
just deploy tags=samba

# Deploy to DevContainer test target
just test-deploy
just test-deploy check=true   # dry-run

# Create OpenClaw Runtime SA item in OpenClaw Admin vault (run once before first deploy)
# Replace ops_runtime-token with the actual Runtime SA token from 1Password Settings
op item create --vault "OpenClaw Admin" --category login \
  --title "OpenClaw Runtime SA" credential="ops_runtime-token-here"

# Create Samba 1Password item (run once before first samba deploy)
op item create --vault OpenClaw --category login \
  --title "Samba" credential="$(op generate-password)"

# Deploy daily S3 backup cron job (run once after provisioning)
just backup

# Restore from S3 backup (one-shot migration/restore)
just restore s3://my-bucket/openclaw/openclaw-TIMESTAMP.tgz.enc

# Provision Discord server channels (run once before first Ansible deploy)
cd terraform/discord && terraform init && terraform apply

# Add server_id to discord 1Password item (run once before terraform apply)
op item edit discord --vault OpenClaw "server_id[text]=YOUR_DISCORD_SERVER_ID"

# Provision S3 backup bucket + IAM user and write credentials to 1Password (run once)
# Requires: OP_SERVICE_ACCOUNT_TOKEN, OpenClaw Admin / AWS Admin item in 1Password
cd terraform/aws && cp terraform.tfvars.example terraform.tfvars  # fill in bucket_name + backup_passphrase
cd terraform/aws && terraform init && terraform apply

# Pre-commit hooks
pre-commit run --all-files        # Run all hooks
pre-commit run ansible-lint       # Run only ansible-lint

# Cut a release (automated via release-please)
# 1. Merge the open "chore(main): release X.Y.Z" PR created by release-please
# 2. release-please tags the commit and publishes a GitHub release automatically
# To trigger: just merge to main — release-please opens the PR on the next push
```

## Architecture

### Playbook Execution Order (`ansible/site.yml`)

1. **`openclaw_vendor_base`** — wraps the upstream `ansible/vendor/openclaw-ansible` submodule; installs Node.js, configures Tailscale and firewall
2. **`common`** — base packages, timezone, locale
3. **`onepassword`** — 1Password CLI installation
4. **`openclaw_config`** — deploys `openclaw.json`, `.env` (via `op inject`), systemd service, and logrotate
5. **`openclaw_gateway_proxy`** — optional Nginx HTTPS reverse proxy for LAN access
6. **`openclaw_samba`** — optional Samba share exposing `/home/openclaw/uploads/` to the LAN subnet

### Standalone Playbooks

- **`ansible/backup.yml`** — deploys a daily cron job that encrypts `.openclaw` and uploads to S3 via 1Password secrets; run once after provisioning
- **`ansible/restore.yml`** — one-shot migration/restore: downloads from S3, decrypts, and restores `.openclaw`

### Key Variable Files

- `ansible/group_vars/all.yml` — global vars (timezone, Node.js version, openclaw user, port, feature flags)
- `ansible/group_vars/vault.yml` — Ansible Vault encrypted secrets (created from `vault.example.yml`)
- `ansible/inventory/hosts.yml` — production VM inventory
- `ansible/inventory/test-container.yml` — DevContainer test target

### Upstream Submodule

`ansible/vendor/` contains the official `openclaw-ansible` submodule. The `openclaw_vendor_base` role invokes its tasks. The `ansible.cfg` roles path includes both `roles:vendor/openclaw-ansible/roles`. Always `git submodule update --init --recursive` after cloning.

`powershell/vendor/` contains the `fdcastel/Hyper-V-Automation` submodule for Windows VM provisioning.

### DevContainer Testing

`.devcontainer/` runs two containers via Docker Compose:
- **control node** — Ubuntu 24.04 with Ansible installed
- **ubuntu-target** — simulated VM with systemd enabled

The `post-create.sh` script installs dependencies, configures pre-commit, and imports SSH keys automatically.

## Pre-commit Hooks

Three stages are enforced:

| Stage | Hooks |
|-------|-------|
| `pre-commit` | shellcheck, yamllint (max 160 chars), markdownlint, ansible-lint, detect-secrets, file checks |
| `commit-msg` | Conventional Commits (`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`, `perf`, `revert`) |
| `pre-push` | Molecule tests (skipped gracefully if Docker unavailable) |

The `ansible-lint` hook uses `language: system` — ansible-lint must be installed in PATH before pre-commit runs. The `.claude/` directory is excluded from all hooks.

## CI Pipeline

Two sequential GitHub Actions jobs (`.github/workflows/ci.yml`):
1. **pre-commit** — runs all pre-commit hooks; requires ansible-lint and ansible-core pre-installed
2. **molecule** — runs `molecule test` from `ansible/`; needs `submodules: recursive` checkout

Pinned versions: `ansible-lint==25.6.1`, `ansible-core==2.18.4` (avoid ansible-core 2.19 loader bug).

Triggers: push to `main`, `claude/**`, `feature/**`; PRs targeting `main`.

## Ansible-lint Configuration

`.ansible-lint` profile is `basic`. Excluded paths: `ansible/vendor/`, `.cache/`, `ansible/molecule/`. Skipped rules: `yaml[line-length]`, `deprecated-command-syntax`.

## Secrets Management

- Ansible Vault: `ansible/group_vars/vault.yml` (encrypted; `vault.example.yml` is the template)
- 1Password CLI (`op inject`) used for runtime secrets on the VM
- `.secrets.baseline` tracks allowed secrets for `detect-secrets`
- Terraform Discord resources excluded from secrets scanning

### 1Password Vaults

Two vaults are in use. Use the correct vault for each context:

| Vault | Purpose |
|-------|---------|
| **`OpenClaw`** | All runtime secrets used by the OpenClaw agent and Ansible playbooks |
| **`OpenClaw Admin`** | High-privilege operator credentials (Terraform provisioning only; never deployed to the VM) |

```bash
op item get "item-name" --vault OpenClaw
op item create --vault OpenClaw ...
op item get "item-name" --vault "OpenClaw Admin"
```

### 1Password Item Structure

#### `OpenClaw` vault (runtime secrets)

Single-secret items use the `credential` field. Multi-value items use descriptive field names.

| Item | Fields | Purpose |
|------|--------|---------|
| `discord` | `credential`, `server_id`, `allowlist`, `guilds` | Discord bot token, server ID, and comma-separated user allowlist and guild IDs |
| `OpenClaw` | `identity_md`, `user_md`, `vscode_ssh_key` | Agent identity (IDENTITY.md), user context (USER.md), and developer SSH public key for VS Code Remote SSH |
| `OpenClaw Gateway` | `credential` | Auto-generated gateway API token |
| `AWS Backup` | `access_key_id`, `secret_access_key`, `s3_bucket`, `passphrase` | Scoped IAM credentials (written by `terraform/aws`); S3 bucket name; backup encryption passphrase |
| `Tailscale` | `credential` | Tailscale VPN auth key |
| `OpenAI` | `credential` | OpenAI API key |
| `OpenRouter API Credentials` | `credential` | OpenRouter API key |
| `Telegram Bot` | `credential` | Telegram bot token |
| `Samba` | `credential` | Samba share password for the openclaw user |

#### `OpenClaw Admin` vault (operator/Terraform secrets)

| Item | Fields | Purpose |
|------|--------|---------|
| `AWS Admin` | `access_key_id`, `secret_access_key` | High-privilege AWS credentials used by `terraform/aws` to provision the S3 bucket and IAM user; never deployed to the VM |
| `OpenClaw Runtime SA` | `credential` | 1Password service account token scoped to `OpenClaw` vault (read/write); written to the VM at deploy time; used by `op inject` and the backup cron |

> **Two-token model:** The deploy runner uses an *admin* service account token (`OP_SERVICE_ACCOUNT_TOKEN` env var / `vault_openclaw_op_service_account_token`) that has access to both vaults. At deploy time Ansible reads `OpenClaw Admin/OpenClaw Runtime SA/credential` with the admin token and writes that narrower runtime token to the VM. The VM's backup cron and `op inject` calls use only the runtime token, which is scoped exclusively to the `OpenClaw` vault.

Items in the **OpenClaw Admin** vault:

| Item | Fields | Purpose |
|------|--------|---------|
| `github-cli` | `credential` | GitHub fine-grained PAT for `gh` CLI in devcontainer (repo + PR + workflow access) |

**Naming rules:**
- Item names match the service they represent (e.g. `discord`, `Tailscale`, `OpenAI`)
- OpenClaw-specific items are prefixed with `OpenClaw` or are named `OpenClaw`
- Multi-value items group logically related fields (e.g. all Discord config in `discord`, all AWS/backup in `AWS Backup`)
- Single-secret items always use the `credential` field name
