#!/bin/bash
# Setup SSH access to OpenClaw VM
# Usage: ./setup-ssh.sh [vm_ip] [vm_user]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
VM_IP="${1:-192.168.100.10}"
VM_USER="${2:-openclaw}"
SSH_KEY_PATH="$HOME/.ssh/openclaw_vm"

print_info "====================================="
print_info "OpenClaw VM SSH Setup"
print_info "====================================="
print_info "VM IP: $VM_IP"
print_info "VM User: $VM_USER"
print_info "SSH Key: $SSH_KEY_PATH"
print_info "====================================="
echo

# Check if SSH key already exists
if [ -f "$SSH_KEY_PATH" ]; then
    print_warn "SSH key already exists: $SSH_KEY_PATH"
    read -p "Do you want to use the existing key? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Generating new SSH key..."
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "openclaw-vm-key"
    fi
else
    print_info "Generating SSH key..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "openclaw-vm-key"
fi

print_info "✓ SSH key ready"
echo

# Copy SSH key to VM
print_info "Copying SSH key to VM..."
print_warn "You will be prompted for the VM user's password"
echo

if ssh-copy-id -i "${SSH_KEY_PATH}.pub" "${VM_USER}@${VM_IP}"; then
    print_info "✓ SSH key copied successfully"
else
    print_error "✗ Failed to copy SSH key"
    exit 1
fi
echo

# Test SSH connection
print_info "Testing SSH connection..."
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${VM_USER}@${VM_IP}" "echo 'SSH connection successful'"; then
    print_info "✓ SSH connection works!"
else
    print_error "✗ SSH connection failed"
    exit 1
fi
echo

# Update inventory file if it exists
INVENTORY_FILE="../inventory/hosts.yml"
if [ -f "$INVENTORY_FILE" ]; then
    print_info "Inventory file found: $INVENTORY_FILE"
    print_warn "Make sure the inventory file has the correct settings:"
    echo "  ansible_host: $VM_IP"
    echo "  ansible_user: $VM_USER"
    echo "  ansible_ssh_private_key_file: $SSH_KEY_PATH"
else
    print_warn "Inventory file not found. You'll need to create it manually."
fi
echo

print_info "====================================="
print_info "✓ SSH Setup Complete!"
print_info "====================================="
print_info "You can now test Ansible connectivity:"
print_info "  cd .. && ansible all -i inventory/hosts.yml -m ping"
print_info ""
print_info "Or deploy OpenClaw:"
print_info "  cd .. && ./scripts/deploy.sh"
