# Hyper-V VM Setup (Windows 11)

Automated one-command VM provisioning using [fdcastel/Hyper-V-Automation](https://github.com/fdcastel/Hyper-V-Automation).

## Prerequisites

- Windows 11 with Hyper-V enabled
- Admin PowerShell session
- OpenSSH Client (built-in on Windows 11)
- `winget` (built-in on Windows 11) — used to auto-install `qemu-img` if needed

No other tools to install manually. The script handles the rest.

## One-Command VM Creation

Open an **elevated PowerShell** at the repository root and run:

```powershell
# First time only: initialise submodules
git submodule update --init --recursive

# Static IP — recommended, matches default inventory (192.168.1.x LAN)
.\powershell\New-OpenClawVM.ps1 -IPAddress 192.168.1.151/24 -Gateway 192.168.1.1

# DHCP — IP is printed at the end; update ansible/inventory/hosts.yml afterwards
.\powershell\New-OpenClawVM.ps1
```

The script automatically:

1. Installs `qemu-img` via winget if not already present
2. Downloads and caches the Ubuntu 24.04 server cloud image (~600 MB, one-time)
3. Creates a Gen 2 Hyper-V VM (4 GB RAM, 2 vCPU, 32 GB disk)
4. Injects your SSH public key via cloud-init (auto-generates a key pair if absent)
5. Waits for SSH to become available
6. Creates the `claw` user with passwordless sudo
7. Prints the exact commands to run next

## Choosing a Virtual Switch

| Switch type | Use when |
| --- | --- |
| `Default Switch` *(default)* | VM only needs internet; accessed from this host only |
| External switch (e.g. `Home Network`) | VM needs a real LAN IP reachable from other devices |

To use an external switch:

```powershell
.\powershell\New-OpenClawVM.ps1 -SwitchName "Home Network" -IPAddress 192.168.1.151/24 -Gateway 192.168.1.1
```

List available switches: `Get-VMSwitch | Select-Object Name, SwitchType`

## After VM Creation

The inventory (`ansible/inventory/hosts.yml`) is pre-configured for `192.168.1.151`.
If you used DHCP, update `ansible_host` with the printed IP, then deploy:

```powershell
cd ansible
.\scripts\deploy-windows.ps1 -Check    # dry run
.\scripts\deploy-windows.ps1           # deploy
```

See [ansible/QUICKSTART.md](../ansible/QUICKSTART.md) for full deployment instructions.

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-VmName` | `OpenClaw-VM` | Hyper-V VM name |
| `-VmUser` | `claw` | Linux user created for Ansible |
| `-SwitchName` | `Default Switch` | Hyper-V virtual switch |
| `-IPAddress` | *(DHCP)* | Static IP in CIDR notation, e.g. `192.168.1.151/24` |
| `-Gateway` | *(none)* | Default gateway (required with `-IPAddress`) |
| `-MemoryStartupBytes` | `4 GB` | VM RAM |
| `-ProcessorCount` | `2` | vCPU count |
| `-VHDXSizeBytes` | `32 GB` | Disk size |
| `-ImageCachePath` | `C:\HyperV\OpenClaw\_images` | Directory for the cached Ubuntu cloud image |
| `-SshPublicKeyPath` | `~/.ssh/openclaw_vm_ansible.pub` | SSH public key; auto-generated if absent |

## Existing / Manual VMs

For VMs provisioned without this script (e.g. installed from ISO), run the SSH setup helper instead:

```powershell
.\ansible\scripts\setup-ssh.ps1 -VmAddress 192.168.1.151 -VmUser claw
```
