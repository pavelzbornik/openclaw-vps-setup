# Firewall and Network Controls

This repo relies on the official `openclaw-ansible` submodule tasks for firewall setup when `vendor_firewall_enabled` is true (default).

## Default Behavior

- The `openclaw_vendor_base` role can install Docker, configure UFW, and apply upstream firewall rules from the submodule.
- Firewall tasks come from the upstream `clawdbot` role and are enabled via `vendor_firewall_enabled`.
- OpenClaw itself runs natively; Docker is installed only because upstream firewall tasks integrate with Docker.

## Configuration

Edit these values in [ansible/group_vars/all.yml](../ansible/group_vars/all.yml):

- `vendor_firewall_enabled`: enables upstream firewall tasks
- `vendor_docker_enabled`: must be true if firewall is enabled

If you want to manage UFW rules locally instead of upstream:

1. Set `vendor_firewall_enabled: false`
2. Add your own firewall tasks or roles
3. Re-run the playbook

## Quick Checks on the VM

```bash
sudo ufw status verbose
sudo journalctl -u ufw -n 100 --no-pager
sudo ss -tulnp | grep 18789
```

## Notes

- If UFW is disabled in a test container, Molecule and devcontainer tests may skip firewall validation.
- Tailscale access is installed by the upstream submodule tasks when `vendor_tailscale_enabled` is true.
