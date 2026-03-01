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

**7 OBSOLETE, 2 PARTIALLY OBSOLETE, 1 STILL RELEVANT, 8 NEEDS RETHINKING.**

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
survives: the Justfile concept (retooled), the 1Password two-vault model
(with different boundaries — runtime vs. Claude Code/Terraform),
backup/restore (redelivered as scripts), the Discord Terraform module,
the DevContainer concept (repurposed for Claude Code isolation), and
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

Nanoclaw introduces **three distinct security contexts** that need
separate secret scoping:

1. **Nanoclaw orchestrator** — the runtime process needs bot tokens and
   LLM API keys to function. These are production secrets.
2. **Claude Code** — the development tool used to customize/modify the
   Nanoclaw fork. It needs its own Anthropic API key and possibly a
   GitHub PAT. It should NOT have access to production bot tokens.
3. **Terraform/provisioning** — AWS Admin credentials for S3 bucket
   provisioning. High-privilege, used infrequently.

The two-vault model survives but with **different boundaries**:

| Vault | Purpose | Who accesses it |
|-------|---------|-----------------|
| **Nanoclaw** (runtime) | Bot tokens, LLM API keys for the orchestrator, backup credentials | Nanoclaw process via `op run` |
| **Nanoclaw Admin** (operator) | Claude Code API key, GitHub PAT, AWS Admin credentials, Terraform state | Developer/Claude Code, Terraform |

**Why two vaults, not one:**

- **Least privilege**: The Nanoclaw runtime token should only access bot
  tokens and API keys — not development credentials or AWS admin keys.
  If the orchestrator process is compromised (e.g., via a messaging
  library vulnerability), the blast radius is limited to runtime secrets.
- **Claude Code isolation**: Claude Code modifies the Nanoclaw codebase.
  It should have its own API key but not production bot tokens. A
  compromised or hallucinating Claude Code session should not be able to
  exfiltrate Discord/Telegram credentials.
- **Terraform isolation**: AWS Admin credentials can provision/destroy
  infrastructure. They should never be accessible to the runtime process
  or to Claude Code.

**Two-token model changes:**

The current model distributes tokens via Ansible (admin token fetches
runtime token at deploy time, writes it to the VM). With local execution,
this indirection simplifies — both tokens are stored locally on the Win11
host, and each context uses its own token via `op run`.

- **Ansible Vault eliminated** — no encrypted group vars to manage
- **`op run`** replaces `op inject` — no secrets written to disk at all

**Vault item migration:**

| Current item | Vault | Action |
|--------------|-------|--------|
| `discord` | Runtime | Keep — bot token, server_id, allowlist, guilds |
| `Telegram Bot` | Runtime | Keep — bot token |
| `Anthropic` | Runtime | **Add** — Nanoclaw uses Claude natively for orchestrator LLM |
| `AWS Backup` | Runtime | Keep if S3 backup continues |
| `OpenAI` | Runtime | Review — keep only if Nanoclaw uses OpenAI |
| `OpenRouter API Credentials` | Runtime | Review — keep if Nanoclaw uses OpenRouter |
| `OpenClaw` | — | Remove — identity_md/user_md/vscode_ssh_key are OpenClaw-specific |
| `OpenClaw Gateway` | — | Remove — no gateway |
| `Tailscale` | — | Remove unless Tailscale used for Win11 host management |
| `Samba` | — | Remove |
| `Claude Code` | Admin | **Add** — Anthropic API key for Claude Code development tool |
| `github-cli` | Admin | Keep — GitHub PAT for fork management |
| `AWS Admin` | Admin | Keep if Terraform provisions S3 bucket |
| `Nanoclaw Runtime SA` | Admin | **Add** — runtime SA token (replaces `OpenClaw Runtime SA`) |

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

### 4.10 DevContainer and Molecule Testing — NEEDS RETHINKING

**Current:** Docker Compose with control node + Ubuntu target, simulating
Ansible-over-SSH deployment. Molecule tests role convergence in Docker.

**With Nanoclaw:** Molecule and the Ansible-specific DevContainer config are
obsolete. However, the **DevContainer concept itself may survive** — it could
be repurposed as an isolated Claude Code development environment for
modifying the Nanoclaw fork (see section 6.3). The DevContainer would
provide a reproducible environment with only the Admin vault token,
ensuring Claude Code cannot access runtime secrets.

Molecule testing has no equivalent need — there are no Ansible roles to
converge-test.

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

Nanoclaw does not natively support 1Password. Two separate integration
points are needed — one for the **runtime orchestrator** and one for
**Claude Code** development.

### 6.1 Runtime Orchestrator (Nanoclaw vault)

The Nanoclaw process needs bot tokens and API keys at startup. Use `op run`
with a reference file so no secrets are written to disk:

```bash
# nanoclaw.env.op (1Password references — no actual secrets)
ANTHROPIC_API_KEY=op://Nanoclaw/Anthropic/credential
DISCORD_BOT_TOKEN=op://Nanoclaw/discord/credential
TELEGRAM_BOT_TOKEN=op://Nanoclaw/Telegram Bot/credential
```

**For systemd (WSL2):**

```ini
[Service]
ExecStart=/usr/bin/op run --env-file=/home/nanoclaw/nanoclaw.env.op -- node src/index.ts
Environment=OP_SERVICE_ACCOUNT_TOKEN=<runtime-token>
```

**For Docker:**

```yaml
services:
  nanoclaw:
    environment:
      - OP_SERVICE_ACCOUNT_TOKEN  # runtime token — Nanoclaw vault only
    entrypoint: ["op", "run", "--env-file=nanoclaw.env.op", "--", "node", "src/index.ts"]
```

The runtime SA token is scoped to the **Nanoclaw vault only** — it cannot
access Claude Code credentials or AWS Admin keys.

### 6.2 Claude Code Development (Nanoclaw Admin vault)

Claude Code needs its own Anthropic API key (for the AI that modifies the
fork) and possibly a GitHub PAT. These come from the Admin vault, using
a separate SA token:

```bash
# claude-code.env.op (Admin vault references)
ANTHROPIC_API_KEY=op://Nanoclaw Admin/Claude Code/credential
GITHUB_TOKEN=op://Nanoclaw Admin/github-cli/credential
```

The Admin SA token has access to the Admin vault (and optionally the runtime
vault for read-only operations like viewing config). Claude Code never sees
production bot tokens.

### 6.3 Claude Code Environment Options

Where Claude Code runs relative to Nanoclaw affects secret scoping and
isolation:

| Option | How it works | Isolation | Complexity |
|--------|-------------|-----------|------------|
| **Same WSL2 instance** | Claude Code runs alongside Nanoclaw in the same distro. Different `op run` env files scope secrets. | Low — process-level only. Both share filesystem. | Simplest |
| **Separate WSL2 distro** | Dedicated WSL2 distro for development. Claude Code pushes changes to Nanoclaw's distro via git. | Medium — filesystem isolation, separate token. | Moderate |
| **DevContainer** | Claude Code runs inside a VS Code DevContainer with its own secrets. Changes pushed via git or volume mount. | High — container boundary, scoped secrets, reproducible env. | Higher setup, but familiar pattern |

**Trade-offs:**

- **Same WSL2**: Simplest operationally. The Nanoclaw fork lives in one
  place. Risk: if Claude Code has filesystem access, it could read
  Nanoclaw's runtime `.env.op` references (though not the resolved
  secrets, since `op run` never writes them to disk). The two SA tokens
  provide the real isolation — even with filesystem access, Claude Code's
  token cannot resolve runtime vault references.

- **Separate WSL2**: Natural boundary. Claude Code works on a clone of
  the fork, pushes changes. Nanoclaw's distro pulls and restarts. More
  git workflow overhead but cleaner separation. Mirrors the current
  control-node → target-VM pattern in a lighter form.

- **DevContainer**: Strongest isolation. The DevContainer provides a
  reproducible development environment with only the Admin vault token.
  This is conceptually similar to the current DevContainer setup but for
  Nanoclaw fork development rather than Ansible playbook testing. The
  current `.devcontainer/` infrastructure could be **repurposed** (not
  obsolete after all) — rewritten for a Nanoclaw development context
  instead of an Ansible control node.

**Recommendation**: Start with **same WSL2 instance** (simplest). The
two-token vault model provides adequate secret scoping even without
filesystem isolation. If the threat model demands stronger separation,
the DevContainer option reuses a familiar pattern from this repo.

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
├── setup.sh                  # WSL2 provisioning (Docker, Node.js, op CLI)
├── nanoclaw.env.op           # 1Password runtime secret references
├── claude-code.env.op        # 1Password admin secret references (Claude Code)
├── nanoclaw.service          # systemd user unit with op run wrapper
├── backup.sh                 # S3 encrypted backup script
├── restore.sh                # S3 restore script
├── Justfile                  # start, stop, logs, backup, restore, update
├── .devcontainer/            # Optional: isolated Claude Code dev environment
│   └── devcontainer.json     # DevContainer with Admin vault token only
├── terraform/
│   ├── discord/              # Discord channel provisioning (reused)
│   └── aws/                  # S3 backup bucket (reused)
├── .github/workflows/ci.yml  # Lint + Terraform validate
└── docs/
```

This is roughly **12–15 files** replacing the current repository's **60+**.

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
| 12 | 1Password two-vault/token model | NEEDS RETHINKING | Two vaults survive (runtime + admin) with different boundaries; orchestrator vs Claude Code vs Terraform |
| 13 | Justfile | NEEDS RETHINKING | Concept valuable; every recipe changes |
| 14 | CI pipeline | PARTIALLY OBSOLETE | Lint survives; Molecule/ansible-lint steps obsolete |
| 15 | DevContainer / Molecule | NEEDS RETHINKING | Molecule obsolete; DevContainer concept may be repurposed for Claude Code isolation (see 6.3) |
| 16 | Pre-commit hooks | PARTIALLY OBSOLETE | General checks survive; Ansible-specific hooks obsolete |
| 17 | Upstream submodules | OBSOLETE | Both submodules serve obsolete purposes |
| 18 | UFW firewall | OBSOLETE | No inbound ports; WSL2/Docker handle isolation |
| 19 | Tailscale | NEEDS RETHINKING | Not Nanoclaw-specific; may still serve Win11 host management |
| 20 | Nginx reverse proxy | OBSOLETE | No gateway to proxy |

**Totals: 7 OBSOLETE, 2 PARTIALLY OBSOLETE, 1 STILL RELEVANT, 8 NEEDS RETHINKING**
