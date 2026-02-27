# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Infrastructure-as-Code for automated provisioning and deployment of the OpenClaw AI agent (a Node.js autonomous assistant) on Ubuntu VPS or Hyper-V VMs. Uses Ansible with an upstream `openclaw-ansible` git submodule for the base Node.js/Tailscale/firewall stack.

## Common Commands

All Ansible commands run from the `ansible/` directory (or use `make` targets which handle this):

```bash
# Run Molecule tests (Docker required)
cd ansible && molecule test

# Lint playbooks
cd ansible && ansible-lint site.yml

# Dry-run deployment
cd ansible && make check

# Deploy to production VM
cd ansible && make deploy

# Deploy only specific roles (use tags)
cd ansible && make deploy TAGS=openclaw
cd ansible && make deploy TAGS=common
cd ansible && make deploy TAGS=vendor

# Deploy to DevContainer test target
cd ansible && make test-deploy
# or from repo root:
./test-deploy.sh --check

# Install Ansible Galaxy collections (required before first run)
cd ansible && ansible-galaxy collection install -r requirements.yml

# Deploy daily S3 backup cron job (run once after provisioning)
ansible-playbook -i ansible/inventory/hosts.yml ansible/backup.yml

# Restore from S3 backup (one-shot migration/restore)
ansible-playbook -i ansible/inventory/hosts.yml ansible/restore.yml \
  -e openclaw_restore_s3_path=s3://my-bucket/openclaw/openclaw-TIMESTAMP.tgz.enc

# Pre-commit hooks
pre-commit run --all-files        # Run all hooks
pre-commit run ansible-lint       # Run only ansible-lint
```

## Architecture

### Playbook Execution Order (`ansible/site.yml`)

1. **`openclaw_vendor_base`** — wraps the upstream `ansible/vendor/openclaw-ansible` submodule; installs Node.js, configures Tailscale and firewall
2. **`common`** — base packages, timezone, locale
3. **`onepassword`** — 1Password CLI installation
4. **`openclaw_config`** — deploys `openclaw.json`, `.env` (via `op inject`), systemd service, and logrotate
5. **`openclaw_gateway_proxy`** — optional Nginx HTTPS reverse proxy for LAN access

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

The following vaults are available in this environment. Always use the **OpenClaw** vault for project secrets:

When reading or writing secrets with the `op` CLI, target the OpenClaw vault explicitly:

```bash
op item get "item-name" --vault OpenClaw
op item create --vault OpenClaw ...
```

### 1Password Item Structure

All items live in the **OpenClaw** vault. Single-secret items use the `credential` field.
Multi-value items use descriptive field names.

| Item | Fields | Purpose |
|------|--------|---------|
| `discord` | `credential`, `allowlist`, `guilds` | Discord bot token; comma-separated user allowlist and guild IDs |
| `OpenClaw` | `identity_md`, `user_md`, `vscode_ssh_key` | Agent identity (IDENTITY.md), user context (USER.md), and developer SSH public key for VS Code Remote SSH |
| `OpenClaw Gateway` | `credential` | Auto-generated gateway API token |
| `AWS Backup` | `access_key_id`, `secret_access_key`, `s3_bucket`, `passphrase` | S3 credentials and backup encryption passphrase |
| `Tailscale` | `credential` | Tailscale VPN auth key |
| `OpenAI` | `credential` | OpenAI API key |
| `OpenRouter API Credentials` | `credential` | OpenRouter API key |
| `Telegram Bot` | `credential` | Telegram bot token |
| `Service Account Auth Token` | `credential` | 1Password service account token for CI/CD |

**Naming rules:**
- Item names match the service they represent (e.g. `discord`, `Tailscale`, `OpenAI`)
- OpenClaw-specific items are prefixed with `OpenClaw` or are named `OpenClaw`
- Multi-value items group logically related fields (e.g. all Discord config in `discord`, all AWS/backup in `AWS Backup`)
- Single-secret items always use the `credential` field name
