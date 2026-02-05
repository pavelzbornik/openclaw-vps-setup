# Upstream Ansible Reuse (openclaw/openclaw-ansible)

This repo originally implemented a full OpenClaw VM provisioning playbook under `ansible/`.
There is also an upstream installer playbook at https://github.com/openclaw/openclaw-ansible.

To avoid reinventing the wheel (and to make it easy to track upstream improvements), this workspace vendors the upstream repo as a git submodule:

- `ansible/vendor/openclaw-ansible`

## What’s reused today

This workspace uses the vendored upstream tasks as the baseline via the `openclaw_vendor_base` role:

- Node.js + pnpm install via `clawdbot:nodejs`
- Tailscale install via `clawdbot:tailscale`

This is controlled by vendor-base variables in `group_vars/all.yml`:

- `vendor_nodejs_enabled`, `vendor_tailscale_enabled`, `vendor_docker_enabled`, `vendor_firewall_enabled`

## How it works

- `ansible/site.yml` runs `openclaw_vendor_base` first.
- `openclaw_vendor_base` includes upstream role task files using `include_role: name=clawdbot tasks_from=...`.
- Scripts export `ANSIBLE_ROLES_PATH` so vendored roles are discoverable even when Ansible ignores `ansible.cfg`.

## Intentional differences (still local)

Some areas are intentionally kept local because upstream’s goal and execution model differ:

- OpenClaw config templating (`roles/openclaw/templates/openclaw.json.j2`, `.env`, systemd unit)
- 1Password CLI integration (`roles/onepassword`)
- UFW rules tuned for “Tailscale-only gateway” access (`roles/firewall`)
- Security hardening choices (fail2ban, unattended-upgrades in `roles/common`)

## Next candidates to port (if you want)

Upstream has some valuable security posture you may want to cherry-pick later:

- UFW + Docker isolation patterns (DOCKER-USER chain / `daemon.json`)
- Additional systemd user-service environment hardening (DBus/XDG runtime patterns)

Those are not enabled by default here to avoid surprising behavior changes on servers.
