# Hyper-V VM Setup (Windows 11)

Automated one-command VM provisioning using [fdcastel/Hyper-V-Automation](https://github.com/fdcastel/Hyper-V-Automation).

## Prerequisites

- Windows 11 with Hyper-V enabled
- Admin PowerShell session
- OpenSSH Client (built-in on Windows 11, or install via *Settings → Optional Features*)
- Docker Desktop (for running Ansible — see [ansible/QUICKSTART.md](../ansible/QUICKSTART.md))

## One-Command VM Creation

Run from the **repository root** in an elevated PowerShell session:

```powershell
# First time: initialise the submodule
git submodule update --init --recursive

# Static IP (recommended — matches default inventory)
.\powershell\New-OpenClawVM.ps1 -IPAddress 192.168.1.151/24 -Gateway 192.168.1.1

# DHCP (update inventory/hosts.yml with the printed IP afterwards)
.\powershell\New-OpenClawVM.ps1
```

The script:
1. Downloads and caches the Ubuntu 24.04 server cloud image
2. Creates a Gen 2 Hyper-V VM (4 GB RAM, 2 vCPU, 32 GB disk)
3. Injects your SSH public key via cloud-init
4. Waits for SSH to become available
5. Creates the `claw` user with passwordless sudo
6. Prints the exact commands to run next

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-VmName` | `OpenClaw-VM` | Hyper-V VM name |
| `-VmUser` | `claw` | Linux user for Ansible |
| `-SwitchName` | `Default Switch` | Hyper-V virtual switch |
| `-IPAddress` | *(DHCP)* | Static IP in CIDR notation, e.g. `192.168.1.151/24` |
| `-Gateway` | *(none)* | Default gateway (required with `-IPAddress`) |
| `-MemoryStartupBytes` | `4 GB` | VM RAM |
| `-ProcessorCount` | `2` | vCPU count |
| `-VHDXSizeBytes` | `32 GB` | Disk size |
| `-VmRootPath` | `C:\HyperV\OpenClaw` | VM file storage directory |
| `-SshPublicKeyPath` | `~/.ssh/openclaw_vm_ansible.pub` | SSH public key; auto-generated if absent |

## After VM Creation

Update `ansible/inventory/hosts.yml` if needed, then deploy:

```powershell
cd ansible
.\scripts\deploy-windows.ps1 -Check    # dry run
.\scripts\deploy-windows.ps1           # deploy
```

See [ansible/QUICKSTART.md](../ansible/QUICKSTART.md) for full deployment instructions.

## Existing / Manual VMs

For VMs provisioned without this script (e.g. installed from ISO), use the legacy SSH setup helper:

```powershell
.\ansible\scripts\setup-ssh.ps1 -VmAddress 192.168.1.151 -VmUser claw
```
