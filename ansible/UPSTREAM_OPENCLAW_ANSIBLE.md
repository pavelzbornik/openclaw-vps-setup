# Official Ansible Submodule (openclaw/openclaw-ansible)

This repo includes the official OpenClaw installer playbook as a git submodule:

- `ansible/vendor/openclaw-ansible`

Upstream is the **source of truth** for all base provisioning. Local roles only add
deployment-specific features that upstream intentionally does not cover.

## What upstream provides (via `vendor_base`)

The `openclaw_vendor_base` role selectively includes upstream task files:

| Task file | What it does | Control variable |
|---|---|---|
| `system-tools` | System packages, vim, git config | `vendor_system_tools_enabled` |
| `user` | User creation, sudoers, SSH keys, .bash_profile, DBus/XDG | `vendor_user_enabled` |
| `tailscale-linux` | Tailscale VPN | `vendor_tailscale_enabled` |
| `docker-linux` | Docker Engine | `vendor_docker_enabled` |
| `firewall-linux` | UFW, fail2ban, unattended-upgrades | `vendor_firewall_enabled` |
| `nodejs` | Node.js + pnpm via corepack | `vendor_nodejs_enabled` |
| `openclaw` | pnpm dirs, pnpm install, .bashrc PATH | `vendor_openclaw_install_enabled` |

## What local roles add (not in upstream)

| Local role | Purpose |
|---|---|
| `common` | apt dist-upgrade, timezone, locale, extra packages (`python3-pip`, `acl`) |
| `onepassword` | 1Password CLI installation |
| `openclaw_config` | `openclaw.json`, `.env` (via `op inject`), systemd service, logrotate |
| `openclaw_gateway_proxy` | Optional Nginx HTTPS reverse proxy for LAN access |

Upstream expects users to run `openclaw onboard --install-daemon` manually.
The `openclaw_config` role pre-installs the systemd service and config files so
the deployment is fully automated without interactive steps.

## How it works

- `ansible/site.yml` runs `openclaw_vendor_base` first, then local roles.
- `openclaw_vendor_base` includes upstream task files using `include_role: name=openclaw tasks_from=...`.
- `ansible.cfg` sets `roles_path = roles:vendor/openclaw-ansible/roles` so vendored roles are discoverable.
- `deploy.sh` also exports `ANSIBLE_ROLES_PATH` for script-based runs.

## Variable alignment

Local `group_vars/all.yml` uses the same variable names as upstream `defaults/main.yml`:

- `openclaw_user`, `openclaw_home`, `openclaw_config_dir`, `openclaw_port`
- `nodejs_version`, `openclaw_install_mode`, `openclaw_ssh_keys`
- `tailscale_enabled`, `ci_test`

This means upstream defaults are overridden only where explicitly needed.
