# Hyper-V VM Setup (Windows 11)

This is a concise checklist for preparing a Hyper-V VM before running Ansible.

## 1) Create the VM

- Create a Generation 2 VM in Hyper-V Manager
- Assign 2+ vCPUs and 4+ GB RAM
- Attach the Ubuntu 24.04 Server ISO

## 2) Network and IP

- Use an internal or NAT switch
- Assign a static IP during Ubuntu install (example: `192.168.100.10/24`)
- Record the VM IP for Ansible inventory

## 3) Install Ubuntu + OpenSSH

During the Ubuntu installer:

- Create the `openclaw` user
- Enable OpenSSH server
- Reboot and verify SSH access

## 4) Prepare WSL2 (Control Node)

Install WSL2 Ubuntu and Ansible on your Windows host. Then follow the Ansible quickstart:

- [ansible/QUICKSTART.md](../ansible/QUICKSTART.md)

## Optional PowerShell Snippets

```powershell
# Create an internal switch
New-VMSwitch -SwitchName "OpenClawNAT" -SwitchType Internal

# Assign IP to host-side interface
$ifIndex = (Get-NetAdapter | Where-Object { $_.Name -like "*OpenClawNAT*" }).ifIndex
New-NetIPAddress -IPAddress 192.168.100.1 -PrefixLength 24 -InterfaceIndex $ifIndex

# Create NAT
New-NetNat -Name "OpenClawNATNetwork" -InternalIPInterfaceAddressPrefix "192.168.100.0/24"
```
