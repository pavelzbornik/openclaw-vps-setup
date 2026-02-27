# Security Policy

## Scope

This security policy applies to the **openclaw-vps-setup** repository — the Ansible
playbooks, Terraform configurations, and supporting scripts used to provision and deploy
the OpenClaw AI agent on Ubuntu VPS or Hyper-V VMs.

### In scope

- Secrets leaking into the repository (committed tokens, passwords, keys)
- Vulnerabilities in Ansible roles or Terraform code that could lead to privilege
  escalation or unauthorized access on provisioned VMs
- Misconfigured firewall rules that unintentionally expose services to the internet
- Insecure default configurations deployed to production VMs
- Supply-chain issues in the `openclaw-ansible` git submodule or Ansible Galaxy
  collections used by this project

### Out of scope

- Vulnerabilities in the OpenClaw application itself — report those to the
  [openclaw/openclaw](https://github.com/openclaw/openclaw) repository
- Vulnerabilities in third-party tools (Ansible, Terraform, 1Password CLI, Tailscale)
  — report those upstream
- Issues that only affect development/test environments (DevContainer, Molecule)
- Purely theoretical vulnerabilities with no practical exploitation path

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Use one of the following private channels:

1. **GitHub private security advisory** (preferred): Open a
   [private advisory](../../security/advisories/new) via the "Security" tab of this
   repository. GitHub will keep it confidential until a fix is released.

2. **Email**: If you cannot use GitHub advisories, contact the maintainer directly
   via the email address listed on their GitHub profile.

### What to include

- A clear description of the vulnerability and its impact
- Steps to reproduce or a proof-of-concept (even partial)
- Which files, roles, or configurations are affected
- Your suggested fix (optional but appreciated)

---

## What to Expect

| Stage | Timeline |
|-------|----------|
| Initial acknowledgement | Within **48 hours** |
| Triage and severity assessment | Within **7 days** |
| Fix or workaround available | Within **30 days** for critical/high; best-effort for lower severity |
| Public disclosure | After the fix is merged and released, coordinated with the reporter |

We follow coordinated disclosure: we ask reporters to keep details private until a fix
is available. We will credit reporters in the release notes unless they prefer
anonymity.

---

## Security Design

### Secrets management

- **No plaintext secrets are ever committed to this repository.** Sensitive values are
  stored in Ansible Vault (`group_vars/vault.yml`, encrypted at rest) or in 1Password.
- Runtime secrets (API tokens, bot tokens, passwords) are injected on the VM at deploy
  time using `op inject` from the 1Password CLI. The rendered `.env` file is written to
  `/home/openclaw/.openclaw/.env` with `0600` permissions and is never echoed to logs.
- The `detect-secrets` pre-commit hook scans every commit for accidental secret
  inclusion. Allowed exceptions are tracked in `.secrets.baseline`.

### Two-token 1Password model

Deployment uses two separate 1Password service account tokens with different privilege
levels:

| Token | Scope | Where used |
|-------|-------|------------|
| **Admin SA token** | `OpenClaw` + `OpenClaw Admin` vaults | Deploy runner only (`OP_SERVICE_ACCOUNT_TOKEN` env var / `vault_openclaw_op_service_account_token`) |
| **Runtime SA token** | `OpenClaw` vault only | Written to the VM at deploy time; used by `op inject` and the backup cron |

The VM's runtime token cannot read the `OpenClaw Admin` vault (which contains
high-privilege AWS and Terraform credentials). A compromised VM therefore cannot
escalate to admin-level cloud access.

See [docs/architecture.md](docs/architecture.md) for a full secrets-flow diagram.

### Network posture

- UFW defaults to **deny all inbound** traffic; only explicitly allowed ports are open.
- The OpenClaw gateway process binds to `127.0.0.1` (loopback only) by default.
  LAN access is provided through the optional Nginx reverse proxy role
  (`openclaw_gateway_proxy`), which terminates TLS and enforces an IP allowlist.
- Tailscale provides an encrypted overlay network for operator SSH and remote access.
  Tailscale authentication keys are stored in 1Password and never committed.
- See [docs/firewall.md](docs/firewall.md) for the full port matrix.

### SSH access

- The provisioned VM accepts SSH key authentication only; password authentication is
  disabled by the upstream `openclaw-ansible` base role.
- The Ansible deploy user (`openclaw`) requires passwordless `sudo` for provisioning,
  but post-deploy the `sudo` requirement can be tightened.
- VS Code Remote SSH access for developers uses a separate public key stored in the
  `OpenClaw/OpenClaw/vscode_ssh_key` 1Password field.

### Supply chain

- The `openclaw-ansible` submodule is pinned to a specific commit hash; update it
  deliberately via `git submodule update`.
- Ansible Galaxy collections are declared in `ansible/requirements.yml` with pinned
  versions.
- Pre-commit hooks run `ansible-lint`, `shellcheck`, and `yamllint` on every commit.
  The CI pipeline repeats these checks and runs full Molecule integration tests.
