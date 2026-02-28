# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- `SECURITY.md` — security policy, vulnerability reporting process, and security
  design notes (two-token 1Password model, UFW posture, SSH hardening)
- `CHANGELOG.md` — this file, seeded from project git history
- `docs/architecture.md` — C4 context and container diagrams for the full system
- `terraform/aws/` — Terraform module to provision an S3 backup bucket and scoped IAM
  user; writes credentials to the `OpenClaw Admin` 1Password vault
- `ansible/restore.yml` — one-shot playbook to download, decrypt, and restore
  `.openclaw` from S3

### Changed

- Expanded `CONTRIBUTING.md` with commit-message conventions, branch naming, role
  authoring guide, documentation checklist, and testing requirements
- Expanded `docs/README.md` with persona-based reading paths and per-link descriptions
- Expanded `docs/firewall.md` with a full port-matrix table and UFW posture notes
- Expanded `docs/discord-terraform.md` with conceptual overview of Discord-as-interface
- Added table of contents to `ansible/README.md`, `ansible/TROUBLESHOOTING.md`, and
  `.devcontainer/README.md`

---

## [2026-02-14]

### Added

- `openclaw_samba` role — Samba LAN file-drop share at `/home/openclaw/uploads/`;
  restricted to `openclaw_lan_subnet`; password stored in `OpenClaw/Samba` 1Password
  item; UFW rules for TCP 139/445 from LAN subnet only (`#11`)
- VS Code Remote SSH access for the `openclaw` user — public key stored in
  `OpenClaw/OpenClaw/vscode_ssh_key` 1Password field and deployed by
  `openclaw_config` (`#12`)

### Changed

- Consolidated 1Password vault items: merged previously separate items into the
  two-vault model (`OpenClaw` for runtime, `OpenClaw Admin` for operator); updated
  all `op://` references in templates (`#10`)
- Updated `openclaw-ansible` submodule to latest commit; removed duplicated workspace
  directory (`a53b35d`)

---

## [2026-01-31]

### Added

- Full 1Password secrets management: runtime secrets injected via `op inject` on the
  VM; two-token model (admin SA token for deploy runner, runtime SA token scoped to
  `OpenClaw` vault written to VM) (`8b09c1d`)
- `ansible/backup.yml` — daily cron job that encrypts `.openclaw` and uploads to S3
  using 1Password-sourced credentials
- `openclaw_gateway_proxy` role — optional Nginx HTTPS reverse proxy with LAN IP
  allowlist and UFW rules for ports 80/443; gateway port locked to loopback
- `openclaw_config` role — deploys `openclaw.json`, `.env` (via `op inject`), systemd
  service, and logrotate configuration

### Changed

- Renamed `openclaw_app` role to `openclaw_config` for clarity; removed `openclaw_git`
  role (app now installed via pnpm, not git clone) (`#5`)
- Fixed broken links and outdated content throughout README docs (`b90499c`)

---

## [2026-01-15]

### Added

- `powershell/vendor/` — `fdcastel/Hyper-V-Automation` submodule replacing custom
  Hyper-V provisioning scripts (`#7`)
- `openclaw-expert` Claude skill — expert knowledge base for OpenClaw deployment
  questions (`cb44f89`)
- `openclaw-workspace-setup` Claude skill — interactive guided setup for agent
  identity files (`920842d`)

### Changed

- Aligned `openclaw.json` config template with production schema; added workspace
  bootstrap step (`9cf3742`)
- Added `community.crypto` Ansible Galaxy collection dependency (`7dd38fa`)

### Fixed

- Hardened CI bootstrap scripts; resolved pre-commit and Molecule failures (`667d877`)
- Added missing `gateway.tailscale` defaults to `all.yml` (`7f8d280`)
- SSH hardening skipped in Molecule test container to prevent lock-out (`81f3141`)
- Gateway port corrected; `test-deploy.sh` hardened for Docker environments (`741126a`)

### Security

- Hardened gateway configuration, SSH settings, and pre-commit hooks (`068f304`)
- 1Password service account token asserted at runtime, not in CI test mode (`f48c44a`)

---

## [2026-01-01]

### Added

- Initial project structure: Ansible playbooks and roles for provisioning OpenClaw on
  Ubuntu VPS/Hyper-V VMs
- `openclaw_vendor_base` role wrapping the upstream `openclaw-ansible` git submodule
  (Node.js, Tailscale, UFW firewall)
- `common` role for base packages, timezone, and locale
- `onepassword` role for 1Password CLI installation
- DevContainer environment with `ansible-control` and `ubuntu-target` containers for
  local testing
- Molecule test suite with Docker-based isolated testing
- Pre-commit hooks: `shellcheck`, `yamllint`, `markdownlint`, `ansible-lint`,
  `detect-secrets`, Conventional Commits enforcement, and Molecule pre-push
- GitHub Actions CI pipeline: pre-commit stage + Molecule stage
- Terraform Discord provisioning: bot-managed channel layout for OpenClaw's
  communication interface (`terraform/discord/`)
