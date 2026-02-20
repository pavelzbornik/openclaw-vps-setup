[CmdletBinding()]
param(
    [string]$VmName = "OpenClaw-VM",
    [string]$VmUser = "openclaw",
    [string]$SwitchName = "Default Switch",
    [ValidateSet("dhcp", "static")]
    [string]$NetworkMode = "dhcp",
    [string]$NatName = "OpenClawNATNetwork",
    [string]$SubnetCidr = "192.168.100.0/24",
    [string]$HostGatewayIp = "192.168.100.1",
    [string]$VmIp = "",
    [int]$PrefixLength = 24,
    [int]$CpuCount = 2,
    [ValidateSet(1, 2)]
    [int]$VmGeneration = 1,
    [UInt64]$MemoryStartupBytes = 4GB,
    [string]$VmRootPath = "C:\HyperV\OpenClaw",
    [string]$SshPublicKeyPath = "$HOME\.ssh\openclaw_vm.pub",
    [string]$UbuntuImageUrl = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64-azure.vhd.tar.gz",
    [int]$SshWaitTimeoutSeconds = 900,
    [bool]$UseBaseDiskDirect = $true,
    [switch]$ForceRecreate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Ensure-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run in an elevated PowerShell session (Run as Administrator)."
    }
}

function Ensure-HyperV {
    if (-not (Get-Module -ListAvailable -Name Hyper-V)) {
        throw "Hyper-V PowerShell module is unavailable. Enable Hyper-V and reboot."
    }
    Import-Module Hyper-V
}

function Convert-CidrToPrefix {
    param([string]$Cidr)
    $parts = $Cidr.Split('/')
    if ($parts.Count -ne 2) {
        throw "Invalid CIDR format: $Cidr"
    }
    return [int]$parts[1]
}

function Ensure-SwitchNetworking {
    $existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if (-not $existingSwitch) {
        throw "Hyper-V switch '$SwitchName' not found. Create/select an existing switch (for DHCP, use an external switch or 'Default Switch')."
    }

    Write-Info "Using existing Hyper-V switch '$SwitchName' (type: $($existingSwitch.SwitchType))"

    if ($NetworkMode -eq "dhcp") {
        if ($existingSwitch.SwitchType -eq "Internal" -and $SwitchName -ne "Default Switch") {
            Write-WarnMsg "Switch '$SwitchName' is Internal and usually has no DHCP. Prefer an external switch or 'Default Switch' for automatic IP assignment."
        }
        return
    }

    if ([string]::IsNullOrWhiteSpace($VmIp)) {
        throw "-VmIp is required when -NetworkMode static is used."
    }

    if ($existingSwitch.SwitchType -ne "Internal") {
        Write-WarnMsg "Static mode was requested on a non-internal switch. Continuing, but ensure your routing supports this configuration."
        return
    }

    $switchAdapter = Get-NetAdapter | Where-Object { $_.Name -like "vEthernet ($SwitchName)" }
    if (-not $switchAdapter) {
        throw "Host vEthernet adapter for switch '$SwitchName' not found."
    }

    $existingIp = Get-NetIPAddress -InterfaceIndex $switchAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $HostGatewayIp }

    if (-not $existingIp) {
        $existingAnyIp = Get-NetIPAddress -InterfaceIndex $switchAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($existingAnyIp) {
            Write-WarnMsg "Adapter already has IPv4 address(es): $($existingAnyIp.IPAddress -join ', '). Keeping existing config."
        }
        else {
            Write-Info "Assigning host gateway IP $HostGatewayIp/$PrefixLength to switch adapter"
            New-NetIPAddress -IPAddress $HostGatewayIp -PrefixLength $PrefixLength -InterfaceIndex $switchAdapter.ifIndex | Out-Null
        }
    }
    else {
        Write-Info "Host gateway IP already configured on switch adapter"
    }

    $nat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
    if (-not $nat) {
        Write-Info "Creating NAT '$NatName' for subnet $SubnetCidr"
        New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $SubnetCidr | Out-Null
    }
    else {
        Write-Info "Using existing NAT '$NatName'"
    }
}

function Wait-ForVmIp {
    param(
        [string]$Name,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $ips = (Get-VMNetworkAdapter -VMName $Name -ErrorAction Stop).IPAddresses |
                Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' -and $_ -ne '0.0.0.0' }

            if ($ips) {
                return $ips[0]
            }
        }
        catch {
            Write-Verbose "Wait-ForVmIp probe failed for VM '$Name': $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 5
    }

    return $null
}

function Ensure-SshPublicKey {
    $privateKeyPath = [System.IO.Path]::ChangeExtension($SshPublicKeyPath, $null)
    if ([string]::IsNullOrWhiteSpace($privateKeyPath)) {
        $privateKeyPath = "$HOME\.ssh\openclaw_vm"
    }

    if (-not (Test-Path -Path $SshPublicKeyPath)) {
        Write-WarnMsg "SSH public key not found at '$SshPublicKeyPath'."
        $sshDir = Split-Path -Parent $SshPublicKeyPath
        New-Item -Path $sshDir -ItemType Directory -Force | Out-Null

        $sshKeyGenExe = Get-Command ssh-keygen -ErrorAction SilentlyContinue
        if (-not $sshKeyGenExe) {
            throw "ssh-keygen was not found on PATH. Install OpenSSH Client feature on Windows and retry."
        }

        if (Test-Path -Path $privateKeyPath) {
            Remove-Item -Path $privateKeyPath -Force
        }

        Write-WarnMsg "Generating a new keypair."
        & $sshKeyGenExe.Source -t ed25519 -q -C "openclaw-vm-key" -f $privateKeyPath -N '""' | Out-Null

        if (-not (Test-Path -Path $SshPublicKeyPath)) {
            throw "SSH public key generation failed. Expected key at '$SshPublicKeyPath'."
        }
    }

    return (Get-Content -Path $SshPublicKeyPath -Raw).Trim()
}

function Ensure-UbuntuDisk {
    param(
        [string]$WorkingDirectory
    )

    New-Item -Path $WorkingDirectory -ItemType Directory -Force | Out-Null

    $archiveName = Split-Path -Leaf $UbuntuImageUrl
    if ([string]::IsNullOrWhiteSpace($archiveName)) {
        throw "Could not infer archive file name from UbuntuImageUrl: $UbuntuImageUrl"
    }

    $archivePath = Join-Path $WorkingDirectory $archiveName
    $extractDir = Join-Path $WorkingDirectory "base-image"
    $baseVhdPath = $null

    if (-not (Test-Path $archivePath)) {
        Write-Info "Downloading Ubuntu cloud image archive"
        try {
            Invoke-WebRequest -Uri $UbuntuImageUrl -OutFile $archivePath -UseBasicParsing -TimeoutSec 3600
        }
        catch {
            throw "Failed to download Ubuntu image from '$UbuntuImageUrl' to '$archivePath': $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "Using cached Ubuntu cloud image archive"
    }

    $existingVhd = Get-ChildItem -Path $extractDir -Filter "*.vhd" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $existingVhd) {
        Write-Info "Extracting Ubuntu cloud image"
        New-Item -Path $extractDir -ItemType Directory -Force | Out-Null
        tar -xzf $archivePath -C $extractDir

        $existingVhd = Get-ChildItem -Path $extractDir -Filter "*.vhd" -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $existingVhd) {
            throw "No .vhd file found after extracting '$archivePath'."
        }
    }
    else {
        Write-Info "Using extracted Ubuntu cloud image"
    }

    $baseVhdPath = $existingVhd.FullName
    Write-Info "Using base VHD: $baseVhdPath"
    return $baseVhdPath
}

function New-CloudInitSeedDisk {
    param(
        [string]$DiskPath,
        [string]$UserData,
        [string]$MetaData,
        [string]$NetworkConfig
    )

    if (Test-Path $DiskPath) {
        Remove-Item -Path $DiskPath -Force
    }

    $tempDir = Join-Path ([System.IO.Path]::GetDirectoryName($DiskPath)) "seed-files"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    Set-Content -Path (Join-Path $tempDir "user-data") -Value $UserData -NoNewline
    Set-Content -Path (Join-Path $tempDir "meta-data") -Value $MetaData -NoNewline
    Set-Content -Path (Join-Path $tempDir "network-config") -Value $NetworkConfig -NoNewline

    New-VHD -Path $DiskPath -Dynamic -SizeBytes 64MB | Out-Null
    $mountedVhd = Mount-VHD -Path $DiskPath -Passthru

    try {
        $disk = Get-Disk -Number $mountedVhd.DiskNumber -ErrorAction SilentlyContinue
        if (-not $disk) {
            throw "Could not find mounted seed VHD disk object."
        }

        Initialize-Disk -Number $disk.Number -PartitionStyle MBR | Out-Null
        $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
        Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel "cidata" -Confirm:$false | Out-Null

        $driveLetter = ($partition | Get-Volume).DriveLetter
        if (-not $driveLetter) {
            throw "Failed to assign drive letter to seed disk."
        }

        Copy-Item -Path (Join-Path $tempDir "*") -Destination "${driveLetter}:\" -Force
    }
    finally {
        Dismount-VHD -Path $DiskPath -ErrorAction SilentlyContinue
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
}

function Wait-ForSsh {
    param(
        [string]$Address,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $test = Test-NetConnection -ComputerName $Address -Port 22 -WarningAction SilentlyContinue
            if ($test.TcpTestSucceeded) {
                return $true
            }
        }
        catch {
            Write-Verbose "Wait-ForSsh probe failed for '$Address:22': $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 5
    }

    return $false
}

function Ensure-Vm {
    param(
        [string]$OsDiskPath,
        [string]$SeedDiskPath
    )

    $existingVm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
    if ($existingVm -and -not $ForceRecreate) {
        Write-Info "VM '$VmName' already exists. Reusing existing VM."
        if ($existingVm.State -ne 'Running') {
            Start-VM -Name $VmName | Out-Null
        }
        return
    }

    if ($existingVm -and $ForceRecreate) {
        Write-WarnMsg "Removing existing VM '$VmName' due to -ForceRecreate"
        if ($existingVm.State -eq 'Running') {
            Stop-VM -Name $VmName -Force | Out-Null
        }
        Remove-VM -Name $VmName -Force
    }

    Write-Info "Creating VM '$VmName'"
    New-VM -Name $VmName -Generation $VmGeneration -MemoryStartupBytes $MemoryStartupBytes -VHDPath $OsDiskPath -Path $VmRootPath -SwitchName $SwitchName | Out-Null
    Set-VMProcessor -VMName $VmName -Count $CpuCount
    if ($VmGeneration -eq 2) {
        Set-VMFirmware -VMName $VmName -EnableSecureBoot On -SecureBootTemplate "MicrosoftUEFICertificateAuthority"
    }

    Add-VMHardDiskDrive -VMName $VmName -Path $SeedDiskPath
    Set-VM -Name $VmName -AutomaticStartAction StartIfRunning -AutomaticStopAction ShutDown
    Start-VM -Name $VmName | Out-Null
}

Ensure-Admin
Ensure-HyperV

if (-not $PSBoundParameters.ContainsKey('PrefixLength')) {
    $PrefixLength = Convert-CidrToPrefix -Cidr $SubnetCidr
}
Ensure-SwitchNetworking

$publicKey = Ensure-SshPublicKey

$vmFolder = Join-Path $VmRootPath $VmName
$imageWorkDir = Join-Path $VmRootPath "_images"
New-Item -Path $vmFolder -ItemType Directory -Force | Out-Null

$baseVhdPath = Ensure-UbuntuDisk -WorkingDirectory $imageWorkDir
$osDiskPath = Join-Path $vmFolder "$VmName-os.vhd"
$seedDiskPath = Join-Path $vmFolder "$VmName-seed.vhd"
$useBaseDiskDirectEffective = $UseBaseDiskDirect

if ($ForceRecreate -and $UseBaseDiskDirect) {
    Write-Info "-ForceRecreate is set; creating a fresh VM OS disk copy instead of reusing base VHD directly"
    $useBaseDiskDirectEffective = $false
}

if ($useBaseDiskDirectEffective) {
    Write-Info "Using base VHD directly as VM OS disk"
    $osDiskPath = $baseVhdPath
}
else {
    if (-not (Test-Path $osDiskPath) -or $ForceRecreate) {
        Write-Info "Creating VM OS disk copy"
        if (Test-Path $osDiskPath) {
            Remove-Item -Path $osDiskPath -Force
        }
        Copy-Item -Path $baseVhdPath -Destination $osDiskPath -Force
    }
    else {
        Write-Info "Using existing VM OS disk"
    }
}

$userData = @"
#cloud-config
package_update: true
packages:
  - openssh-server
  - qemu-guest-agent
users:
  - default
  - name: $VmUser
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - $publicKey
ssh_pwauth: false
runcmd:
  - systemctl enable ssh
  - systemctl restart ssh
"@

$metaData = @"
instance-id: $VmName
local-hostname: $VmName
"@

if ($NetworkMode -eq "dhcp") {
        $networkConfig = @"
version: 2
ethernets:
    default:
        match:
            name: "e*"
        dhcp4: true
"@
}
else {
        $networkConfig = @"
version: 2
ethernets:
    default:
        match:
            name: "e*"
        dhcp4: false
        addresses:
            - $VmIp/$PrefixLength
        routes:
            - to: default
              via: $HostGatewayIp
        nameservers:
            addresses:
                - 1.1.1.1
                - 8.8.8.8
"@
}

New-CloudInitSeedDisk -DiskPath $seedDiskPath -UserData $userData -MetaData $metaData -NetworkConfig $networkConfig
Ensure-Vm -OsDiskPath $osDiskPath -SeedDiskPath $seedDiskPath

$resolvedVmIp = $VmIp
if ($NetworkMode -eq "dhcp") {
    Write-Info "Waiting for VM IPv4 address assignment"
    $resolvedVmIp = Wait-ForVmIp -Name $VmName -TimeoutSeconds $SshWaitTimeoutSeconds
    if ([string]::IsNullOrWhiteSpace($resolvedVmIp)) {
        throw "Timed out waiting for VM IPv4 address. Verify switch DHCP connectivity and cloud-init status in VM console."
    }
    Write-Info "VM IPv4 address detected: $resolvedVmIp"
}

Write-Info "Waiting for SSH on $resolvedVmIp:22"
if (-not (Wait-ForSsh -Address $resolvedVmIp -TimeoutSeconds $SshWaitTimeoutSeconds)) {
    throw "Timed out waiting for SSH on $resolvedVmIp. Verify VM boot and cloud-init logs in Hyper-V console."
}

Write-Info "VM is reachable over SSH."
Write-Host ""
Write-Host "Next commands:" -ForegroundColor Cyan
Write-Host "  ssh -i $([System.IO.Path]::ChangeExtension($SshPublicKeyPath, $null)) $VmUser@$resolvedVmIp"
Write-Host "  cd ansible && ./scripts/deploy.sh --check -vv"
