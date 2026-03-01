# Nanoclaw Infrastructure Fitness Analysis

Analysis of which `openclaw-vps-setup` components remain fit for purpose
if [Nanoclaw](https://nanoclaw.net/) replaces OpenClaw on a Windows 11 Server.

## 1. Purpose and Scope

This document evaluates every component of the `openclaw-vps-setup` repository
against the architectural differences between OpenClaw and Nanoclaw. The target
deployment is a **Windows 11 Server** running multiple services, where OpenClaw
currently runs inside a **Hyper-V Ubuntu VM** for isolation.

**Assumptions:**

- Nanoclaw fully replaces OpenClaw (not side-by-side)
- Existing Discord and Telegram bots transfer to Nanoclaw (same tokens/channels)
- 1Password remains the secrets management layer
- Ansible is evaluated for replacement, not assumed to continue

**Classification key:**

| Label | Meaning |
|-------|---------|
| **OBSOLETE** | Completely unnecessary with Nanoclaw |
| **NEEDS RETHINKING** | The underlying need exists but the current approach is wrong |
| **STILL RELEVANT** | Needed even with Nanoclaw, as-is or with minor changes |
| **PARTIALLY OBSOLETE** | Some aspects survive, others do not |

## 2. Executive Summary

**8 OBSOLETE, 2 PARTIALLY OBSOLETE, 1 STILL RELEVANT, 7 NEEDS RETHINKING.**

The Hyper-V VM was a justified security control for OpenClaw but is
over-engineering for Nanoclaw. Nanoclaw eliminates OpenClaw's largest attack
vectors (HTTP gateway, optional sandboxing, mDNS discovery) and mandates
container isolation for all agent execution. A lighter isolation boundary —
a dedicated **WSL2 distro** or a **Docker container** — provides sufficient
protection for the reduced threat model while eliminating most of the
infrastructure management overhead (Ansible, systemd, UFW, Nginx, SSH
hardening) that the full VM required.

The entire Ansible stack, both upstream submodules, the DevContainer/Molecule
testing infrastructure, and the Nginx/Samba roles become obsolete. What
survives: the Justfile concept (retooled), 1Password integration (simplified),
backup/restore (redelivered as scripts), the Discord Terraform module, and
some pre-commit hooks.

## 3. Security and Isolation Deep Dive

### 3.1 Why the Hyper-V VM Was Justified for OpenClaw

OpenClaw has a substantial attack surface that warranted full VM isolation:

| Threat vector | Detail |
|---------------|--------|
| **HTTP gateway** | Listens on 3 ports (18789 gateway, 18791 CDP, 18793 canvas) |
| **Known RCEs** | CVE-2026-25253 (CVSS 8.8) — critical remote code execution |
| **Mass exposure** | 21,000–135,000+ misconfigured instances found exposed online |
| **Infostealer targeting** | Malware specifically targets `~/.openclaw/` config files |
| **Optional sandboxing** | `sandbox.mode: "non-main"` — off by default for DMs |
| **mDNS discovery** | Broadcasts presence on LAN unless explicitly disabled |
| **Supply chain** | ~500K LOC, 70+ dependencies — large npm attack surface |
| **Cleartext secrets** | API keys stored unencrypted in `.env` and `openclaw.json` |

On a multi-service Win11 Server, the Hyper-V VM contained all of these
risks inside a hardware-isolated boundary. **This was not over-engineering.**

### 3.2 Nanoclaw's Reduced Attack Surface

| Threat vector | OpenClaw | Nanoclaw |
|---------------|----------|----------|
| Inbound network listener | 3 ports | **None** — outbound only |
| Known RCEs | CVE-2026-25253 | None known |
| Infostealer targeting | Actively targeted | Not targeted (small user base) |
| Agent sandbox | Optional | **Mandatory** for all agents |
| Codebase size | ~500K LOC, 70+ deps | Small, minimal dependencies |
| mDNS/discovery | Enabled by default | None |
| Cleartext secrets | `.env`, `openclaw.json` | `.env` — same risk, smaller scope |

Nanoclaw eliminates the three biggest risk vectors: network-listening gateway,
optional sandboxing, and the large dependency surface.

### 3.3 Nanoclaw's Container Isolation Architecture

Nanoclaw's isolation is **partial by design** — the orchestrator runs on the
host while only agent code execution is containerized:

| Component | Where it runs | Containerized? |
|-----------|--------------|----------------|
| Node.js orchestrator (main process) | Host | No |
| Messaging connections (discord.js, etc.) | Host | No |
| SQLite database | Host | No |
| Task scheduler | Host | No |
| Agent bash/tool execution | Docker container | **Yes** |
| Agent file operations | Docker container | **Yes** |

The host-resident orchestrator is a smaller attack surface than OpenClaw's
gateway but is not zero. A supply chain attack on a messaging library
dependency would compromise the host process.

### 3.4 Tiered Isolation Options

| Level | Method | Protects against | Overhead | Verdict |
|-------|--------|-----------------|----------|---------|
| 0 | Bare host | Nothing | Zero | Insufficient — orchestrator has full host access |
| 1 | **Docker container** (entire Nanoclaw) | Filesystem, network, resources | Low | Sufficient — outbound-only networking, mapped volumes |
| 2 | **WSL2 distro** | Kernel isolation, filesystem, network namespace | Low | **Recommended** — near-VM isolation, Docker works inside |
| 3 | Hyper-V VM (current) | Full hardware isolation | High | Over-engineering for this threat model |

**Recommendation: Level 2 (WSL2) or Level 1 (Docker).**

WSL2 is the sweet spot because:

- It already runs inside a lightweight Hyper-V utility VM (kernel isolation)
- Docker Desktop or Docker CE runs natively inside WSL2
- Filesystem is separated from the Windows host
- Network namespace provides isolation
- Management overhead is a fraction of a full VM (no SSH, no systemd, no
  Ansible, no UFW, no Nginx)

Docker (Level 1) is simpler but lacks kernel isolation — a container escape
would reach the host. On a multi-service Win11 Server, WSL2's extra layer
is worth the minimal additional overhead.

### 3.5 Verdict

The Hyper-V VM was justified for OpenClaw's threat model. Nanoclaw's
fundamentally smaller attack surface (no gateway, mandatory containerization,
minimal dependencies) means that a full VM is no longer necessary. A
dedicated WSL2 distro provides equivalent practical security with far less
infrastructure overhead.

## 4. Component-by-Component Analysis

### 4.1 Hyper-V VM Provisioning (PowerShell) — NEEDS RETHINKING

**Current:** `powershell/New-OpenClawVM.ps1` creates a full Hyper-V Ubuntu VM
using the `fdcastel/Hyper-V-Automation` submodule.

**With Nanoclaw:** A full VM is over-engineering. Replace with either:

- **WSL2 setup script**: `wsl --install -d Ubuntu-24.04` + initial
  configuration (Docker, Node.js, 1Password CLI, git clone nanoclaw)
- **Docker Compose**: A `docker-compose.yml` that runs Nanoclaw with
  restricted networking and volume mounts

The `Hyper-V-Automation` submodule becomes obsolete. The PowerShell script
could be replaced with a much simpler WSL2 provisioning script.

### 4.2 Ansible and the IaC Model — NEEDS RETHINKING

**Current:** 6 Ansible roles, upstream submodule, Molecule testing, Galaxy
collections, DevContainer with control + target nodes.

**With Nanoclaw:** The entire Ansible stack is solving a problem that
largely disappears. A full VM required:

- SSH access management
- systemd service configuration
- UFW firewall rules
- Package management across the network
- Idempotent convergence testing (Molecule)

WSL2 or Docker eliminates most of these. Replace with:

| Ansible component | Replacement |
|-------------------|-------------|
| Playbook execution | Shell script or Dockerfile |
| Role convergence | `docker build` or setup script |
| Molecule testing | Docker build CI step |
| Galaxy collections | Not needed |
| Inventory management | Not needed (local execution) |
| Ansible Vault | 1Password `op run` directly |

**Recommended replacement:** A single setup script (for WSL2) or Dockerfile
(for Docker) plus a Justfile for day-to-day operations. Nanoclaw's own
`/setup` skill handles application-level configuration.

### 4.3 Ansible Roles

#### openclaw_vendor_base — OBSOLETE

Wraps the upstream `openclaw-ansible` submodule to install Node.js, pnpm,
Tailscale, UFW, Docker, and OpenClaw itself. Every task is either
OpenClaw-specific (wrong application) or handled differently in the new
model (Node.js via Dockerfile/setup script, Docker already present in
WSL2/host).

#### common — NEEDS RETHINKING

Base packages (acl, rsync, python3-cryptography), timezone, locale, SSH
hardening. The *concepts* partially survive:

- **Timezone/locale**: Relevant in WSL2 (set via `wsl.conf` or script)
- **SSH hardening**: Irrelevant — no SSH into WSL2/Docker
- **Extra packages**: Some may be needed in the Nanoclaw environment

Delivery mechanism changes entirely (setup script or Dockerfile, not Ansible).

#### onepassword — NEEDS RETHINKING

1Password CLI installation. **Still needed** (user wants 1Password) but
delivered differently:

- **WSL2**: `op` installed via apt repository in setup script
- **Docker**: `op` baked into the Docker image
- No Ansible role required

#### openclaw_config — NEEDS RETHINKING

Deploys `openclaw.json`, `.env` via `op inject`, systemd service, logrotate,
IDENTITY.md/USER.md. Nanoclaw has no `openclaw.json`, but the underlying
needs partially survive:

| Need | OpenClaw approach | Nanoclaw approach |
|------|-------------------|-------------------|
| Process management | systemd unit | systemd user unit, or Docker `restart: unless-stopped` |
| API keys | `.env.op` + `op inject` | `op run --env-file` at process start |
| Agent identity | `IDENTITY.md`, `USER.md` | Per-group `CLAUDE.md` files |
| Log management | logrotate | Docker log rotation or journal |

The role is obsolete but the *concepts* reappear in a simpler form.

#### openclaw_gateway_proxy (Nginx) — OBSOLETE

Nginx HTTPS reverse proxy with self-signed TLS, rate limiting, UFW rules.
Nanoclaw has **no HTTP gateway** — zero inbound network exposure. There is
nothing to proxy.

#### openclaw_samba — OBSOLETE

Samba share exposing `/home/openclaw/uploads/` to the LAN. With Nanoclaw
on WSL2, the Windows filesystem is accessible via `/mnt/c/` — no network
file sharing needed. Files are local to the device.

### 4.4 Secrets Management / 1Password — NEEDS RETHINKING

**Current model:**

- Two vaults (`OpenClaw` runtime, `OpenClaw Admin` operator)
- Two-token architecture (admin SA token deploys, runtime SA token on VM)
- 11+ 1Password items
- Ansible Vault for encrypted group vars
- `op inject` on the VM to populate `.env`

**With Nanoclaw:**

The two-token model was solving a **remote deployment** problem — the admin
token fetches the runtime token at deploy time and writes it to the VM.
With local execution, this indirection is unnecessary.

**Simplified model:**

- **Single vault** (`Nanoclaw` or reuse `OpenClaw`)
- **Single token** — runtime SA token, used locally via `op run`
- **`op run`** replaces `op inject` — no secrets written to disk at all
- **Ansible Vault eliminated** — no encrypted vars to manage

**Vault item changes:**

| Item | Action |
|------|--------|
| `discord` | Keep — bot token, server_id, allowlist, guilds |
| `Telegram Bot` | Keep — bot token |
| `OpenAI` | Keep or remove (depends on Nanoclaw's LLM provider) |
| `Anthropic` | **Add** — Nanoclaw uses Claude natively |
| `AWS Backup` | Keep if S3 backup continues |
| `OpenClaw` | Remove — identity_md/user_md/vscode_ssh_key are OpenClaw-specific |
| `OpenClaw Gateway` | Remove — no gateway |
| `OpenRouter API Credentials` | Review — keep if Nanoclaw uses OpenRouter |
| `Tailscale` | Remove unless Tailscale used for Win11 host management |
| `Samba` | Remove |
| `OpenClaw Runtime SA` (Admin vault) | Simplify — single token replaces two-token model |
| `AWS Admin` (Admin vault) | Keep if Terraform provisions S3 bucket |

### 4.5 Backup and Restore — NEEDS RETHINKING

**Current:** Ansible-deployed cron job → tar + GPG encrypt → S3 upload via
awscli. Ansible-deployed restore playbook.

**With Nanoclaw:**

- **Data to back up changes**: SQLite database + `groups/*/CLAUDE.md` per-group
  memory files (not `~/.openclaw/`)
- **S3 mechanism is still valid** if cloud backup is desired
- **Delivery mechanism changes**: Simple shell script instead of Ansible
  playbook. Could be a cron job in WSL2 or a scheduled task in Windows.
- **1Password integration**: `op run` injects AWS credentials and passphrase
  at backup time (same concept, simpler execution)

The `terraform/aws` module that provisions the S3 bucket and IAM user
remains useful.

### 4.6 Terraform Modules

#### terraform/aws — PARTIALLY OBSOLETE

S3 bucket + IAM user + lifecycle rules for backups. The infrastructure is
still valid if cloud backups continue. The 1Password credential auto-write
may need adjustment for the simplified single-token model.

#### terraform/discord — STILL RELEVANT

Discord channel provisioning (categories, channels). User keeps Discord.
Bot token stays in 1Password. Channel structure may need Nanoclaw-specific
adjustments but the Terraform module concept is sound.

### 4.7 Networking Layer — PARTIALLY OBSOLETE

| Component | Verdict | Rationale |
|-----------|---------|-----------|
| **UFW firewall** | OBSOLETE | No inbound ports to protect. WSL2/Docker handle network isolation natively |
| **Tailscale** | NEEDS RETHINKING | Was for remote VPS management. May still be useful for Win11 host remote access, but not Nanoclaw-specific infrastructure |
| **Nginx reverse proxy** | OBSOLETE | No HTTP gateway to front |
| **Self-signed TLS** | OBSOLETE | No HTTPS endpoint |

### 4.8 Justfile and Task Runner — NEEDS RETHINKING

**Current:** 25+ recipes targeting Ansible, SSH, VM management (`deploy`,
`test`, `check`, `ssh`, `logs`, `status`, `restart`, `backup`, `restore`,
`ping`, `snapshot`, etc.).

**With Nanoclaw:** The task runner concept is valuable, but every recipe
changes:

| Current recipe | Nanoclaw equivalent |
|----------------|---------------------|
| `just deploy` | `just setup` (run setup script/docker build) |
| `just test` | `just test` (different test framework) |
| `just logs` | `just logs` (docker logs or journal) |
| `just status` | `just status` (process/container status) |
| `just backup` | `just backup` (run backup script) |
| `just restore` | `just restore s3://...` (run restore script) |
| `just ssh` | Not needed (local execution) |
| `just lint` | Keep if repo has lintable files |

### 4.9 CI/CD Pipeline — PARTIALLY OBSOLETE

**Current:** Two GitHub Actions jobs — pre-commit hooks + Molecule test.

**With Nanoclaw:**

- **Pre-commit job**: Survives but hooks change (drop ansible-lint, molecule)
- **Molecule job**: Obsolete (tests Ansible role convergence)
- **New**: Could add Docker build test, shellcheck for setup scripts,
  Terraform validation

### 4.10 DevContainer and Molecule Testing — OBSOLETE

**Current:** Docker Compose with control node + Ubuntu target, simulating
Ansible-over-SSH deployment. Molecule tests role convergence in Docker.

**With Nanoclaw:** Both exist to test Ansible playbooks against a simulated
VM. Without Ansible and without a VM, neither has a purpose. If the repo
retains a Dockerfile or setup scripts, testing becomes a simple
`docker build` in CI.

### 4.11 Pre-commit Hooks — PARTIALLY OBSOLETE

| Hook | Verdict |
|------|---------|
| shellcheck | Keep (setup scripts) |
| yamllint | Keep if YAML files remain (Terraform, CI config) |
| markdownlint | Keep |
| ansible-lint | OBSOLETE |
| detect-secrets | Keep |
| conventional commits | Keep |
| molecule (pre-push) | OBSOLETE |

### 4.12 Upstream Submodule Dependencies — OBSOLETE

| Submodule | Verdict |
|-----------|---------|
| `ansible/vendor/openclaw-ansible` | OBSOLETE — installs OpenClaw, wrong application |
| `powershell/vendor/Hyper-V-Automation` | OBSOLETE — no full VM provisioning needed |

## 5. Discord and Telegram: Migration Path

Nanoclaw is WhatsApp-native but supports additional platforms via "Skills" —
Claude Code transformation modules that modify user forks. To migrate the
existing Discord and Telegram bots:

1. **Bot tokens**: Transfer from 1Password — same `DISCORD_BOT_TOKEN` and
   `TELEGRAM_BOT_TOKEN` env vars
2. **Platform support**: Add Discord and Telegram Skills to the Nanoclaw
   fork (Claude Code-assisted modification of the codebase)
3. **Discord channels**: `terraform/discord` module continues to manage
   channel structure
4. **Allowlists/guilds**: Migrate from 1Password `discord` item fields to
   Nanoclaw's equivalent configuration (likely code-based in the fork)
5. **Telegram DM policy**: Configure in Nanoclaw's fork code (replaces
   `openclaw.json` channel config)

Key difference: OpenClaw configures channels declaratively in
`openclaw.json`. Nanoclaw configures them in code via fork modifications.

## 6. 1Password Integration for Nanoclaw

Nanoclaw does not natively support 1Password. Integration approach:

**Startup wrapper using `op run`:**

```bash
# .env.op (1Password reference file — no actual secrets)
ANTHROPIC_API_KEY=op://Nanoclaw/Anthropic/credential
DISCORD_BOT_TOKEN=op://Nanoclaw/discord/credential
TELEGRAM_BOT_TOKEN=op://Nanoclaw/Telegram Bot/credential

# Start Nanoclaw with secrets injected (nothing written to disk)
op run --env-file=.env.op -- node src/index.ts
```

**For systemd (WSL2):**

```ini
[Service]
ExecStart=/usr/bin/op run --env-file=/home/nanoclaw/.env.op -- node src/index.ts
Environment=OP_SERVICE_ACCOUNT_TOKEN=<token>
```

**For Docker:**

```yaml
services:
  nanoclaw:
    environment:
      - OP_SERVICE_ACCOUNT_TOKEN
    entrypoint: ["op", "run", "--env-file=.env.op", "--", "node", "src/index.ts"]
```

This is **simpler** than the current two-step `op inject` approach and avoids
writing secrets to disk entirely.

## 7. What Replaces Ansible?

Three options evaluated:

| Option | Pros | Cons |
|--------|------|------|
| **Dockerfile + Compose** | Idempotent by nature, portable, testable in CI | Docker-in-Docker complexity for agent containers |
| **WSL2 setup script + Justfile** | Simple, no abstraction layer, Nanoclaw `/setup` handles app config | Not idempotent without effort, harder to test |
| **Keep Ansible (refactored)** | Mature, idempotent, testable | Massive overhead for simple local setup, user wants to move away |

**Recommendation: WSL2 setup script + Justfile.**

The provisioning is simple enough that Ansible's overhead is not justified:

1. Install Docker, Node.js, git, 1Password CLI in WSL2
2. Clone Nanoclaw fork
3. Run Nanoclaw's `/setup` skill via Claude Code
4. Configure systemd user unit with `op run` wrapper

A ~50-line bash script replaces 6 Ansible roles, an upstream submodule,
Molecule tests, and the DevContainer infrastructure.

## 8. The Meta-Question: Does This Repo Survive?

**In its current form, no.** The repo is purpose-built to deploy OpenClaw on
a remote VM via Ansible. Switching to Nanoclaw on WSL2/Docker eliminates both
the application and the deployment model.

**What a `nanoclaw-setup` equivalent would contain:**

```
nanoclaw-setup/
├── setup.sh                 # WSL2 provisioning (Docker, Node.js, op CLI)
├── .env.op                  # 1Password secret references
├── nanoclaw.service          # systemd user unit with op run wrapper
├── backup.sh                 # S3 encrypted backup script
├── restore.sh                # S3 restore script
├── Justfile                  # start, stop, logs, backup, restore, update
├── terraform/
│   ├── discord/              # Discord channel provisioning (reused)
│   └── aws/                  # S3 backup bucket (reused)
├── .github/workflows/ci.yml  # Lint + Terraform validate
└── docs/
```

This is roughly **10 files** replacing the current repository's **60+**.

The Terraform modules (`discord/`, `aws/`) could be carried forward directly.
Everything else would be rewritten from scratch — not refactored.

## Appendix: Full Classification Summary

| # | Component | Verdict | Key reason |
|---|-----------|---------|------------|
| 1 | Hyper-V VM (full) | OBSOLETE | WSL2 provides sufficient isolation for Nanoclaw's smaller attack surface |
| 2 | PowerShell VM scripts | NEEDS RETHINKING | Replace with WSL2 distro setup or Docker Compose |
| 3 | `openclaw_vendor_base` role | OBSOLETE | Installs OpenClaw — wrong application |
| 4 | `common` role | NEEDS RETHINKING | Concepts survive (timezone, packages) but delivery changes entirely |
| 5 | `onepassword` role | NEEDS RETHINKING | 1Password stays; installation via setup script, not Ansible |
| 6 | `openclaw_config` role | NEEDS RETHINKING | No `openclaw.json`; process management and env vars still needed |
| 7 | `openclaw_gateway_proxy` role | OBSOLETE | No HTTP gateway in Nanoclaw |
| 8 | `openclaw_samba` role | OBSOLETE | Files local to device; no network share needed |
| 9 | Backup/restore playbooks | NEEDS RETHINKING | Different data, same need; deliver as shell scripts |
| 10 | `terraform/aws` | PARTIALLY OBSOLETE | S3 infra valid; 1Password wiring may simplify |
| 11 | `terraform/discord` | STILL RELEVANT | Discord stays; channel provisioning unchanged |
| 12 | 1Password two-token model | NEEDS RETHINKING | Simplify to single token + `op run` |
| 13 | Justfile | NEEDS RETHINKING | Concept valuable; every recipe changes |
| 14 | CI pipeline | PARTIALLY OBSOLETE | Lint survives; Molecule/ansible-lint steps obsolete |
| 15 | DevContainer / Molecule | OBSOLETE | Tests Ansible-over-SSH; no equivalent need |
| 16 | Pre-commit hooks | PARTIALLY OBSOLETE | General checks survive; Ansible-specific hooks obsolete |
| 17 | Upstream submodules | OBSOLETE | Both submodules serve obsolete purposes |
| 18 | UFW firewall | OBSOLETE | No inbound ports; WSL2/Docker handle isolation |
| 19 | Tailscale | NEEDS RETHINKING | Not Nanoclaw-specific; may still serve Win11 host management |
| 20 | Nginx reverse proxy | OBSOLETE | No gateway to proxy |

**Totals: 8 OBSOLETE, 2 PARTIALLY OBSOLETE, 1 STILL RELEVANT, 7 NEEDS RETHINKING (2 unaffected)**
