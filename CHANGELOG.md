# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [0.2.0](https://github.com/pavelzbornik/openclaw-vps-setup/compare/v0.1.0...v0.2.0) (2026-02-28)


### Added

* add CI/CD pipeline with pre-commit, ansible-lint, and molecule ([4a4f30a](https://github.com/pavelzbornik/openclaw-vps-setup/commit/4a4f30a76b5ac388f30a202b58c88b9472397034))
* add CI/CD pipeline with pre-commit, ansible-lint, and molecule ([1816e03](https://github.com/pavelzbornik/openclaw-vps-setup/commit/1816e0329fa867b2719eb58965fd954033c64ebf))
* add installation of Claude Code CLI in post-create script ([3a10896](https://github.com/pavelzbornik/openclaw-vps-setup/commit/3a10896ce6a8a24b9313202d49e9c28b6ecdffe2))
* add OpenClaw git sync and migration role with configuration options ([b9b5726](https://github.com/pavelzbornik/openclaw-vps-setup/commit/b9b5726baa3022e530b01d96bf051d30b98a7341))
* harden OpenClaw automation and private config sync ([4798769](https://github.com/pavelzbornik/openclaw-vps-setup/commit/4798769a08edf83e4d82def9b1fcd4b6f007d845))
* harden OpenClaw automation and private config sync ([8cb42a4](https://github.com/pavelzbornik/openclaw-vps-setup/commit/8cb42a4ae8b9dfbdf72f28e03447a7c7d6ad180c))
* migrate secrets to 1Password and improve VM provisioning ([8b09c1d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/8b09c1d9002ef6b5eb27f056307a64cee0295e18))
* **openclaw_config:** align config template with production schema and bootstrap workspace ([9cf3742](https://github.com/pavelzbornik/openclaw-vps-setup/commit/9cf374261600c24c99e9e67ca4f7ad2a82a6e40b))
* **powershell:** replace custom Hyper-V script with fdcastel/Hyper-V… ([#7](https://github.com/pavelzbornik/openclaw-vps-setup/issues/7)) ([d74d264](https://github.com/pavelzbornik/openclaw-vps-setup/commit/d74d26408decc7871229a36fcafa40e5facd0cd9))
* **samba:** add Samba LAN file-drop share ([#11](https://github.com/pavelzbornik/openclaw-vps-setup/issues/11)) ([3123c62](https://github.com/pavelzbornik/openclaw-vps-setup/commit/3123c621e65e0fbd62a68bffee93a7a7ee360c84))
* **security:** harden gateway, SSH, alerts and tighten pre-commit hooks ([068f304](https://github.com/pavelzbornik/openclaw-vps-setup/commit/068f304cdc542c68d01df1af4655f37e6d578550))
* **skills:** add openclaw-expert skill ([cb44f89](https://github.com/pavelzbornik/openclaw-vps-setup/commit/cb44f89d5adb43ceeee7d6bd4e8da75a75b300b5))
* **skills:** add openclaw-workspace-setup skill for agent identity configuration ([920842d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/920842db7328da68ad1a27162f323699ea0e5659))
* **ssh:** VS Code Remote SSH access for openclaw user ([#12](https://github.com/pavelzbornik/openclaw-vps-setup/issues/12)) ([291c2a3](https://github.com/pavelzbornik/openclaw-vps-setup/commit/291c2a3c5404b3475e7a57fe3311314bd528cfad))
* sync upstream openclaw-ansible submodule to latest (b75be9f → badcb65) ([e3a46a8](https://github.com/pavelzbornik/openclaw-vps-setup/commit/e3a46a84d272bbc451476853d40599865663893c))
* sync upstream openclaw-ansible submodule to latest (b75be9f → badcb65) ([992deb6](https://github.com/pavelzbornik/openclaw-vps-setup/commit/992deb609e395829e24e52c4c622e6a65a1688f6))
* **terraform:** add AWS S3 backup bucket provisioning module ([#14](https://github.com/pavelzbornik/openclaw-vps-setup/issues/14)) ([26c4ed4](https://github.com/pavelzbornik/openclaw-vps-setup/commit/26c4ed435ad0292c6b1cf59cf3126f7dce872f19))


### Fixed

* address all PR review comments - security hardening, CI fixes, correctness ([70e1694](https://github.com/pavelzbornik/openclaw-vps-setup/commit/70e1694311845d68640f6c56b0509f082028c75b))
* address PR review comments ([d7a7923](https://github.com/pavelzbornik/openclaw-vps-setup/commit/d7a792382b2cd031f1916134ee11b3cc7d83688c))
* address PR review comments — security hardening, CI fixes, correctness ([642958d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/642958d6906f477eac41b2878cdddfb4092f7fd2))
* address PR review comments — security, docs, and correctness ([848b6be](https://github.com/pavelzbornik/openclaw-vps-setup/commit/848b6be913d20e0ddddb6384c433e5d1b2efb096))
* address remaining review findings — numbering, permissions, verify, logrotate ([a69b40f](https://github.com/pavelzbornik/openclaw-vps-setup/commit/a69b40ff596e4451797d54051fc86fcd36bb0d8a))
* address remaining review findings — stale docs, molecule compat, verify hardening ([08fc26d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/08fc26d3e0fe77dd6f9621fef84e90bbae9530c8))
* address review findings in molecule, roles, and docs ([8f51da4](https://github.com/pavelzbornik/openclaw-vps-setup/commit/8f51da47b23b3ab37b9a1cf71ebbacf76cb97fc2))
* **ansible:** add community.crypto collection dependency ([7dd38fa](https://github.com/pavelzbornik/openclaw-vps-setup/commit/7dd38facd434d10b5b0aae87cf7ab07633a2adcb))
* **ci:** harden bootstrap scripts and pass pre-commit+molecule ([667d877](https://github.com/pavelzbornik/openclaw-vps-setup/commit/667d8770552d479fdfc22a4c1dfe05c92b78406a))
* **config:** add missing gateway.tailscale defaults to all.yml ([7f8d280](https://github.com/pavelzbornik/openclaw-vps-setup/commit/7f8d280106e77a3575e16ed1de82261160d389e3))
* correct gateway port and harden test-deploy for Docker environment ([741126a](https://github.com/pavelzbornik/openclaw-vps-setup/commit/741126aa4ec30c12fd5138f02a2f6bdf9a849018))
* disable SSH hardening in molecule test container ([81f3141](https://github.com/pavelzbornik/openclaw-vps-setup/commit/81f3141b7cc8e787ec65856b5d17fe08f2092948))
* harden setup scripts and ansible runtime behavior ([a687f6d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/a687f6d53fbf9380231bcf327463270be97ba05f))
* **molecule:** map container to openclaw_vms group and disable DinD vendor flags ([81f64ec](https://github.com/pavelzbornik/openclaw-vps-setup/commit/81f64ec28e6c51debee95bbf535689037342c858))
* **molecule:** resolve role collision, vendor var precedence, and lint violations ([4dae537](https://github.com/pavelzbornik/openclaw-vps-setup/commit/4dae537b49cedfd877565e48f221d9fe77f43022))
* move .ansible-lint to repo root so pre-commit finds it ([890109f](https://github.com/pavelzbornik/openclaw-vps-setup/commit/890109f0d4f350bcc7edb55fac4b11c2ef15a3ea))
* resolve all ansible-lint violations and enable it in pre-commit ([b6b4cd1](https://github.com/pavelzbornik/openclaw-vps-setup/commit/b6b4cd17b837eb3b7a1f3b75f303675ebe0f5332))
* resolve all pre-commit check issues ([e73ffba](https://github.com/pavelzbornik/openclaw-vps-setup/commit/e73ffba95b1363d19bc3ddadf94dfd5c9d2788bd))
* skip 1Password token assert in ci_test mode ([f48c44a](https://github.com/pavelzbornik/openclaw-vps-setup/commit/f48c44a8eef142c17a75dce86b04149c45d9fc55))
* update subproject commit reference for openclaw-ansible ([13c392f](https://github.com/pavelzbornik/openclaw-vps-setup/commit/13c392fa82cc61e9c88b7d0dfcb0a759e931e47f))
* update subproject commit reference for openclaw-ansible ([f83221d](https://github.com/pavelzbornik/openclaw-vps-setup/commit/f83221d87eeaef4a0c1869117a764794e1ac8e38))


### Changed

* align all docs with refactor and add backup/restore guide ([654dd2f](https://github.com/pavelzbornik/openclaw-vps-setup/commit/654dd2f7d74b1386f083289698d60014fee29aba))
* comprehensive documentation expansion ([#16](https://github.com/pavelzbornik/openclaw-vps-setup/issues/16)) ([21fb197](https://github.com/pavelzbornik/openclaw-vps-setup/commit/21fb1975694ed3dea734326ab778614ee7c68b79))
* **readme:** fix outdated content and broken links ([b90499c](https://github.com/pavelzbornik/openclaw-vps-setup/commit/b90499ca39418c977c9cba7911f8af45eec2f454))
* remove Code of Conduct section from CONTRIBUTING.md ([3fdb2cc](https://github.com/pavelzbornik/openclaw-vps-setup/commit/3fdb2ccd793273dfd3ff428dc45fe5a3cf1d5d0d))
* remove duplication with upstream, align concepts to source of truth ([1e0acdb](https://github.com/pavelzbornik/openclaw-vps-setup/commit/1e0acdbfed76121daf9de3fd36f2fb7ad84cc205))
* remove known limitations and future enhancements sections from README ([3dce7b8](https://github.com/pavelzbornik/openclaw-vps-setup/commit/3dce7b8c8d0faf70170b989dbaa07b3ab6cb4fdf))
* remove openclaw_git, rename openclaw_app→openclaw_config, a… ([#5](https://github.com/pavelzbornik/openclaw-vps-setup/issues/5)) ([4a4e2af](https://github.com/pavelzbornik/openclaw-vps-setup/commit/4a4e2afb270863af6fe848d06fb252b5def5b447))
* **secrets:** consolidate 1Password vault items ([#10](https://github.com/pavelzbornik/openclaw-vps-setup/issues/10)) ([f79ebfe](https://github.com/pavelzbornik/openclaw-vps-setup/commit/f79ebfe8adce4d4917c9345f31c063410129493e))
* **secrets:** implement two-vault 1Password model with scoped runtime tokens ([#13](https://github.com/pavelzbornik/openclaw-vps-setup/issues/13)) ([a54bf77](https://github.com/pavelzbornik/openclaw-vps-setup/commit/a54bf77ba1db1f0bc01c7ac00a11de4409184a37))

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
