[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VmAddress,
    [string]$VmUser = "openclaw",
    [string]$SshKeyPath = "$HOME\.ssh\openclaw_vm",
    [int]$SshPort = 22,
    [int]$SshTimeoutSeconds = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Ensure-SshTools {
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    $scp = Get-Command scp -ErrorAction SilentlyContinue
    $sshKeygen = Get-Command ssh-keygen -ErrorAction SilentlyContinue

    if (-not $ssh -or -not $scp -or -not $sshKeygen) {
        throw "OpenSSH client tools were not found (ssh/scp/ssh-keygen). Install Windows OpenSSH Client and retry."
    }

    return @{
        Ssh = $ssh.Source
        Scp = $scp.Source
        SshKeygen = $sshKeygen.Source
    }
}

function Ensure-SshKey {
    param(
        [string]$KeyPath,
        [string]$SshKeygenExe
    )

    $pubPath = "$KeyPath.pub"
    New-Item -Path (Split-Path -Parent $KeyPath) -ItemType Directory -Force | Out-Null

    if (-not (Test-Path $KeyPath) -or -not (Test-Path $pubPath)) {
        Write-Info "Generating SSH keypair at '$KeyPath'"
        $escapedKeyPath = $KeyPath.Replace('"', '""')
        $keygenArgs = "-t ed25519 -f `"$escapedKeyPath`" -q -N `"`" -C `"openclaw-vm-key`""
        $keygenProc = Start-Process -FilePath $SshKeygenExe -ArgumentList $keygenArgs -Wait -NoNewWindow -PassThru
        if ($keygenProc.ExitCode -ne 0) {
            throw "ssh-keygen failed with exit code $($keygenProc.ExitCode)."
        }
    }

    if (-not (Test-Path $KeyPath) -or -not (Test-Path $pubPath)) {
        throw "SSH key generation failed. Missing '$KeyPath' or '$pubPath'."
    }

    return $pubPath
}

function Add-PublicKeyToVm {
    param(
        [string]$SshExe,
        [string]$ScpExe,
        [string]$Address,
        [string]$User,
        [int]$Port,
        [string]$PublicKeyPath
    )

    $remoteTempKey = "/tmp/openclaw_vm_key.pub"
    $remoteNormalizedKey = "/tmp/openclaw_vm_key_normalized.pub"
    $remoteCommand = "umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; tr -d '\r' < $remoteTempKey > $remoteNormalizedKey; grep -qxFf $remoteNormalizedKey ~/.ssh/authorized_keys || cat $remoteNormalizedKey >> ~/.ssh/authorized_keys; rm -f $remoteTempKey $remoteNormalizedKey"
    $target = "{0}@{1}:{2}" -f $User, $Address, $remoteTempKey

    Write-Info "Installing public key on VM (you may be prompted for password)"
    & $ScpExe -P $Port -o StrictHostKeyChecking=accept-new $PublicKeyPath $target
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload SSH public key to VM."
    }

    & $SshExe -p $Port -o StrictHostKeyChecking=accept-new ("{0}@{1}" -f $User, $Address) $remoteCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install SSH public key on VM."
    }
}

function Test-KeyBasedSsh {
    param(
        [string]$SshExe,
        [string]$Address,
        [string]$User,
        [int]$Port,
        [string]$PrivateKeyPath,
        [int]$TimeoutSeconds
    )

    Write-Info "Validating key-based SSH login"
    & $SshExe -i $PrivateKeyPath -p $Port -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=$TimeoutSeconds ("{0}@{1}" -f $User, $Address) "echo SSH_OK"

    if ($LASTEXITCODE -ne 0) {
        throw "Key-based SSH validation failed."
    }
}

Write-Info "====================================="
Write-Info "OpenClaw VM SSH Setup (PowerShell)"
Write-Info "====================================="
Write-Info "VM Address: $VmAddress"
Write-Info "VM User: $VmUser"
Write-Info "SSH Key: $SshKeyPath"
Write-Host ""

$tools = Ensure-SshTools

Write-Info "Checking SSH port reachability"
$portTest = Test-NetConnection -ComputerName $VmAddress -Port $SshPort -WarningAction SilentlyContinue
if (-not $portTest.TcpTestSucceeded) {
    throw "SSH port $SshPort is not reachable on $VmAddress."
}

$pubPath = Ensure-SshKey -KeyPath $SshKeyPath -SshKeygenExe $tools.SshKeygen
Add-PublicKeyToVm -SshExe $tools.Ssh -ScpExe $tools.Scp -Address $VmAddress -User $VmUser -Port $SshPort -PublicKeyPath $pubPath
Test-KeyBasedSsh -SshExe $tools.Ssh -Address $VmAddress -User $VmUser -Port $SshPort -PrivateKeyPath $SshKeyPath -TimeoutSeconds $SshTimeoutSeconds

$inventoryPath = Join-Path $PSScriptRoot "..\inventory\hosts.yml"
Write-Host ""
Write-Info "SSH setup and validation succeeded"
Write-Info "Inventory check: $inventoryPath"
Write-Host "Ensure your inventory contains:" -ForegroundColor Cyan
Write-Host "  ansible_host: $VmAddress"
Write-Host "  ansible_user: $VmUser"
Write-Host "  ansible_ssh_private_key_file: $SshKeyPath"
Write-Host ""
Write-Host "Next (from ansible folder):" -ForegroundColor Cyan
Write-Host "  .\scripts\deploy-windows.ps1 -Check    # Windows PowerShell + Docker"
Write-Host "  ./scripts/deploy.sh --check -vv         # Linux/WSL shell"
