# Official Ansible Submodule (openclaw/openclaw-ansible)

This repo originally implemented a full OpenClaw VM provisioning playbook under `ansible/`.
The official installer playbook lives at <https://github.com/openclaw/openclaw-ansible>.

To avoid reinventing the wheel (and to make it easy to track upstream improvements), this workspace includes the official playbook as a git submodule:

- `ansible/vendor/openclaw-ansible`

## What's reused today

This workspace uses the upstream submodule tasks as the baseline via the `openclaw_vendor_base` role:

- Node.js + pnpm install via `openclaw:nodejs`
- Tailscale install via `openclaw:tailscale-linux`
- Docker install via `openclaw:docker-linux`
- Firewall (UFW + fail2ban + unattended-upgrades) via `openclaw:firewall-linux`

This is controlled by vendor-base variables in `group_vars/all.yml`:

- `vendor_nodejs_enabled`, `vendor_tailscale_enabled`, `vendor_docker_enabled`, `vendor_firewall_enabled`

## How it works

- `ansible/site.yml` runs `openclaw_vendor_base` first.
- `openclaw_vendor_base` includes upstream role task files using `include_role: name=openclaw tasks_from=...`.
- Scripts export `ANSIBLE_ROLES_PATH` so vendored roles are discoverable even when Ansible ignores `ansible.cfg`.

## Intentional differences (still local)

Some areas are intentionally kept local because upstream's goal and execution model differ:

- OpenClaw config templating (`roles/openclaw/templates/openclaw.json.j2`, `.env`, systemd unit) — upstream leaves config to `openclaw onboard`; local role pre-bakes it for unattended deploys
- 1Password CLI integration (`roles/onepassword`) — not in upstream
- Git sync + migration (`roles/openclaw_git`) — not in upstream
- Security hardening choices (fail2ban, unattended-upgrades in `roles/common`) — now also covered by upstream `firewall-linux` when `vendor_firewall_enabled=true`

## Overlap with upstream (potential simplification)

The following areas are now handled by upstream and could be removed from local roles:

- **User creation + sudoers** — upstream `user.yml` creates the openclaw user with scoped sudo, SSH keys, `.bash_profile`, DBus/XDG runtime. Local `common` role duplicates user creation and sudoers.
- **fail2ban + unattended-upgrades** — upstream `firewall-linux.yml` now includes both. Local `common` role guards these with `when: not vendor_firewall_enabled`, so there is no conflict, but the local versions could be removed if `vendor_firewall_enabled` is always `true`.
- **System packages** — upstream `system-tools-linux.yml` installs git, curl, vim, htop, build-essential, etc. Local `base_packages` only adds `python3-pip`, `acl`, `rsync` which are not in upstream.
