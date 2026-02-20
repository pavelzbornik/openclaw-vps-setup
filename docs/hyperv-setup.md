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

If OpenSSH was not enabled during install, configure it in VM console:

```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

If firewall is enabled:

```bash
sudo ufw allow OpenSSH
sudo ufw status
```

From Windows host, verify network reachability:

```powershell
Test-NetConnection <vm-ip> -Port 22
```

## 4) Prepare Ansible Host (Control Node)

Use one of these paths on your Windows host:

- **Recommended:** PowerShell + Docker Desktop (no WSL shell required)
- **Alternative:** WSL2 Ubuntu + native Ansible

Then follow the Ansible quickstart:

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
