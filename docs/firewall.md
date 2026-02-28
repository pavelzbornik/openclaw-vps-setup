# Firewall and Network Controls

This repo relies on the official `openclaw-ansible` submodule tasks for firewall setup
when `vendor_firewall_enabled` is true (default).

## Default Behavior

- The `openclaw_vendor_base` role can install Docker, configure UFW, and apply upstream
  firewall rules from the submodule.
- Firewall tasks come from the upstream `clawdbot` role and are enabled via
  `vendor_firewall_enabled`.
- OpenClaw itself runs natively; Docker is installed only because upstream firewall
  tasks integrate with Docker.

## UFW Posture

UFW is configured with a **default-deny inbound** policy. Only the ports listed in the
table below are explicitly opened. All other inbound connections are dropped silently.

**Tailscale** operates as an encrypted overlay network. SSH and other management
traffic can be routed over Tailscale rather than the public interface, reducing the
attack surface on the host firewall. When `vendor_tailscale_enabled: true`, the
upstream submodule installs Tailscale and configures it to start on boot; the
Tailscale interface (`tailscale0`) is trusted by UFW.

## Port Matrix

The columns below describe what is open in a **fully-featured production deployment**
(all optional roles enabled). Roles that are disabled do not open their ports.

| Service | Port | Protocol | Direction | Scope | Role |
|---------|------|----------|-----------|-------|------|
| SSH | 22 | TCP | Inbound | LAN / Tailscale | `openclaw_vendor_base` (upstream) |
| HTTP (Nginx redirect) | 80 | TCP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_gateway_proxy` |
| HTTPS (Nginx proxy) | 443 | TCP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_gateway_proxy` |
| OpenClaw gateway | `openclaw_port` (default: 3000) | TCP | Inbound | **Loopback only** (`127.0.0.1`) | `openclaw_gateway_proxy` |
| OpenClaw gateway (denied externally) | `openclaw_port` (default: 3000) | TCP | Inbound | **Denied** from all other interfaces | `openclaw_gateway_proxy` |
| NetBIOS (Samba) | 139 | TCP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_samba` |
| SMB (Samba) | 445 | TCP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_samba` |
| NetBIOS-NS (Samba) | 137 | UDP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_samba` |
| NetBIOS-DGM (Samba) | 138 | UDP | Inbound | LAN subnet (`openclaw_lan_subnet`) | `openclaw_samba` |
| Tailscale (WireGuard) | 41641 | UDP | Inbound | Internet | `openclaw_vendor_base` (upstream) |

### Notes

- **OpenClaw gateway** (`openclaw_port`, default `3000`): the process binds to
  `127.0.0.1` only. The `openclaw_gateway_proxy` role explicitly adds a UFW deny rule
  for this port on all other interfaces, and an allow rule for loopback. LAN clients
  reach OpenClaw through Nginx on port 443.
- **Samba ports** are only opened when `openclaw_samba_enabled: true`. They are
  restricted to `openclaw_lan_subnet` (configured in `group_vars/all.yml`).
- **HTTP (port 80)** is opened by `openclaw_gateway_proxy` only to redirect to HTTPS;
  it is not needed if the proxy role is disabled.
- **SSH (port 22)**: exact UFW rule depends on the upstream submodule configuration.
  If Tailscale is enabled, SSH access over Tailscale is recommended and the public
  SSH port can be tightened further.

## Configuration

Edit these values in [ansible/group_vars/all.yml](../ansible/group_vars/all.yml):

- `vendor_firewall_enabled`: enables upstream firewall tasks
- `vendor_docker_enabled`: must be true if firewall is enabled (upstream requirement)
- `openclaw_port`: port the gateway process listens on (default: `3000`)
- `openclaw_lan_subnet`: CIDR for LAN rules (Nginx allowlist, Samba)
- `openclaw_samba_enabled`: enable/disable the Samba role and its UFW rules
- `openclaw_gateway_proxy_enabled`: enable/disable the Nginx proxy role and its UFW rules

If you want to manage UFW rules locally instead of upstream:

1. Set `vendor_firewall_enabled: false`
2. Add your own firewall tasks or roles
3. Re-run the playbook

## Quick Checks on the VM

```bash
sudo ufw status verbose
sudo journalctl -u ufw -n 100 --no-pager
sudo ss -tulnp | grep 3000
```

## Notes

- If UFW is disabled in a test container, Molecule and devcontainer tests may skip
  firewall validation.
- Tailscale access is installed by the upstream submodule tasks when
  `vendor_tailscale_enabled` is true.
