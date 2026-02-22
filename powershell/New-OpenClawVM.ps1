#Requires -RunAsAdministrator
#Requires -Modules Hyper-V
<#
.SYNOPSIS
    Creates a Hyper-V Ubuntu VM pre-configured for the OpenClaw Ansible playbook.

.DESCRIPTION
    Downloads Ubuntu 24.04, creates a Gen 2 Hyper-V VM via cloud-init, and provisions
    the 'claw' user ready for Ansible deployment. Uses fdcastel/Hyper-V-Automation.

.PARAMETER VmName
    Name for the Hyper-V VM. Default: OpenClaw-VM

.PARAMETER VmUser
    Linux username to create for Ansible. Default: claw

.PARAMETER SwitchName
    Hyper-V virtual switch name. Default: Default Switch

.PARAMETER IPAddress
    Static IP in CIDR notation (e.g. 192.168.1.151/24). Omit for DHCP.

.PARAMETER Gateway
    Default gateway IP (required when IPAddress is set).

.PARAMETER MemoryStartupBytes
    VM RAM. Default: 4 GB

.PARAMETER ProcessorCount
    VM vCPU count. Default: 2

.PARAMETER VHDXSizeBytes
    VM disk size. Default: 32 GB

.PARAMETER VmRootPath
    Directory where VM files are stored. Default: C:\HyperV\OpenClaw

.PARAMETER SshPublicKeyPath
    Path to SSH public key. If absent a new key pair is generated at
    ~/.ssh/openclaw_vm_ansible. Default: ~/.ssh/openclaw_vm_ansible.pub

.EXAMPLE
    # Static IP (recommended)
    .\powershell\New-OpenClawVM.ps1 -IPAddress 192.168.1.151/24 -Gateway 192.168.1.1

.EXAMPLE
    # DHCP
    .\powershell\New-OpenClawVM.ps1

.NOTES
    Run from the repository root in an elevated PowerShell session.
    Requires: Hyper-V, OpenSSH Client (built-in on Windows 11).
    After the VM is ready, deploy with: cd ansible && .\scripts\deploy-windows.ps1
#>
[CmdletBinding()]
param(
    [string]$VmName = 'OpenClaw-VM',
    [string]$VmUser = 'claw',
    [string]$SwitchName = 'Default Switch',
    [string]$IPAddress = '',
    [string]$Gateway = '',
    [UInt64]$MemoryStartupBytes = 4GB,
    [int]$ProcessorCount = 2,
    [UInt64]$VHDXSizeBytes = 32GB,
    [string]$VmRootPath = 'C:\HyperV\OpenClaw',
    [string]$SshPublicKeyPath = "$HOME\.ssh\openclaw_vm_ansible.pub"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Validate VmUser is a safe Linux username before it is embedded in remote shell commands
if ($VmUser -notmatch '^[a-z_][a-z0-9_-]*$') {
    throw "VmUser must be a valid Linux username (lowercase letters, digits, hyphens, underscores; no spaces or special characters)"
}

$vendorRoot = Join-Path $PSScriptRoot 'vendor\Hyper-V-Automation'

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Done {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

# ── Resolve SSH keypair ────────────────────────────────────────────────────────
function Resolve-SshKey {
    $privateKeyPath = [System.IO.Path]::ChangeExtension($SshPublicKeyPath, $null).TrimEnd('.')
    if (-not (Test-Path $SshPublicKeyPath)) {
        Write-Step "SSH public key not found — generating new ED25519 keypair"
        $sshDir = Split-Path -Parent $SshPublicKeyPath
        New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
        $keygen = Get-Command ssh-keygen -ErrorAction Stop
        # -N '' sets an empty passphrase (no quotes needed on Linux; empty string works on Windows OpenSSH)
        & $keygen.Source -t ed25519 -q -C 'openclaw-vm-ansible' -f $privateKeyPath -N '' 2>&1 | Out-Null
        if (-not (Test-Path $SshPublicKeyPath)) {
            throw "ssh-keygen failed — key not found at $SshPublicKeyPath"
        }
    }
    return @{
        PublicKey  = (Get-Content $SshPublicKeyPath -Raw).Trim()
        PrivateKey = $privateKeyPath
    }
}

# ── Wait for SSH ───────────────────────────────────────────────────────────────
function Wait-ForSsh {
    param([string]$Address, [int]$TimeoutSeconds = 600)
    Write-Step "Waiting for SSH on $Address:22 (up to ${TimeoutSeconds}s)"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $test = Test-NetConnection -ComputerName $Address -Port 22 -WarningAction SilentlyContinue
        if ($test.TcpTestSucceeded) { return }
        Start-Sleep -Seconds 5
    }
    throw "Timed out waiting for SSH on $Address — check VM console for cloud-init errors"
}

# ── Create claw user via SSH ───────────────────────────────────────────────────
function New-ClawUser {
    param([string]$Address, [string]$PrivateKeyPath)
    Write-Step "Creating '$VmUser' user on $Address"
    $sshExe = (Get-Command ssh -ErrorAction Stop).Source
    $cmd = @"
set -e
id "$VmUser" 2>/dev/null || useradd -m -s /bin/bash "$VmUser"
usermod -aG sudo "$VmUser"
mkdir -p "/home/$VmUser/.ssh"
cp /root/.ssh/authorized_keys "/home/$VmUser/.ssh/authorized_keys"
chown -R "${VmUser}:${VmUser}" "/home/$VmUser/.ssh"
chmod 700 "/home/$VmUser/.ssh"
chmod 600 "/home/$VmUser/.ssh/authorized_keys"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$VmUser" > "/etc/sudoers.d/$VmUser"
chmod 440 "/etc/sudoers.d/$VmUser"
"@
    & $sshExe `
        -i $PrivateKeyPath `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=/dev/null `
        -o BatchMode=yes `
        "root@$Address" $cmd
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create '$VmUser' user on $Address"
    }
}

# ── Resolve VM IP after DHCP ───────────────────────────────────────────────────
function Resolve-VmIp {
    param([string]$Name, [int]$TimeoutSeconds = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $ips = (Get-VMNetworkAdapter -VMName $Name -ErrorAction SilentlyContinue).IPAddresses |
            Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and $_ -ne '0.0.0.0' }
        if ($ips) { return $ips[0] }
        Start-Sleep -Seconds 5
    }
    throw "Timed out waiting for DHCP IP on '$Name' — check Hyper-V switch DHCP"
}

# ── Main ───────────────────────────────────────────────────────────────────────
Import-Module Hyper-V -ErrorAction Stop

$keys = Resolve-SshKey
Write-Done "SSH public key: $SshPublicKeyPath"

# Import library scripts from submodule
. (Join-Path $vendorRoot 'Get-UbuntuImage.ps1')
. (Join-Path $vendorRoot 'New-VMFromUbuntuImage.ps1')

$imageCache = Join-Path $VmRootPath '_images'
New-Item -Path $imageCache -ItemType Directory -Force | Out-Null

Write-Step "Downloading Ubuntu 24.04 cloud image (cached after first run)"
$imagePath = Get-UbuntuImage -OutputPath $imageCache
Write-Done "Image: $imagePath"

Write-Step "Creating Hyper-V VM '$VmName'"
$newVmParams = @{
    SourcePath         = $imagePath
    VMName             = $VmName
    FQDN               = "$VmName.local"
    RootPublicKey      = $keys.PublicKey
    SwitchName         = $SwitchName
    MemoryStartupBytes = $MemoryStartupBytes
    ProcessorCount     = $ProcessorCount
    VHDXSizeBytes      = $VHDXSizeBytes
}

if (-not [string]::IsNullOrWhiteSpace($IPAddress)) {
    if ([string]::IsNullOrWhiteSpace($Gateway)) {
        throw "-Gateway is required when -IPAddress is specified"
    }
    $newVmParams['IPAddress'] = $IPAddress
    $newVmParams['Gateway'] = $Gateway
}

New-VMFromUbuntuImage @newVmParams
Write-Done "VM '$VmName' created and started"

# Resolve IP
if ([string]::IsNullOrWhiteSpace($IPAddress)) {
    $resolvedIp = Resolve-VmIp -Name $VmName
} else {
    $resolvedIp = $IPAddress.Split('/')[0]
}
Write-Done "VM IP: $resolvedIp"

Wait-ForSsh -Address $resolvedIp
New-ClawUser -Address $resolvedIp -PrivateKeyPath $keys.PrivateKey

Write-Done "VM is ready for Ansible deployment"
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Yellow
Write-Host "  1. Update ansible/inventory/hosts.yml — set ansible_host: $resolvedIp" -ForegroundColor White
Write-Host "  2. cd ansible" -ForegroundColor White
Write-Host '  3. .\scripts\deploy-windows.ps1 -Check' -ForegroundColor White
Write-Host '  4. .\scripts\deploy-windows.ps1' -ForegroundColor White
Write-Host ''
Write-Host "SSH access: ssh -i $($keys.PrivateKey) $VmUser@$resolvedIp" -ForegroundColor DarkGray
