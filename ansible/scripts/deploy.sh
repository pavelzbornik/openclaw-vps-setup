#!/bin/bash
# OpenClaw Ansible Deployment Script
# Usage: ./deploy.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
INVENTORY="inventory/hosts.yml"
PLAYBOOK="site.yml"
DRY_RUN=false
VERBOSE=""
TAGS=""
SKIP_TAGS=""

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy OpenClaw to VM using Ansible

OPTIONS:
    -h, --help              Show this help message
    -c, --check             Run in check mode (dry-run)
    -v, --verbose           Verbose output
    -vv, --very-verbose     Very verbose output
    -t, --tags TAGS         Run only tasks with these tags
    -s, --skip-tags TAGS    Skip tasks with these tags
    -i, --inventory FILE    Use custom inventory file (default: inventory/hosts.yml)

EXAMPLES:
    # Full deployment
    $0

    # Dry-run to see what would change
    $0 --check

    # Deploy only OpenClaw role
    $0 --tags openclaw

    # Deploy with verbose output
    $0 -vv

    # Skip Tailscale configuration
    $0 --skip-tags tailscale

EOF
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -c|--check)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -vv|--very-verbose)
            VERBOSE="-vv"
            shift
            ;;
        -t|--tags)
            TAGS="--tags $2"
            shift 2
            ;;
        -s|--skip-tags)
            SKIP_TAGS="--skip-tags $2"
            shift 2
            ;;
        -i|--inventory)
            INVENTORY="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Verify we're in the ansible directory
if [ ! -f "ansible.cfg" ]; then
    print_error "Must be run from the ansible/ directory"
    exit 1
fi

# Check if inventory file exists
if [ ! -f "$INVENTORY" ]; then
    print_error "Inventory file not found: $INVENTORY"
    exit 1
fi

# Check if playbook exists
if [ ! -f "$PLAYBOOK" ]; then
    print_error "Playbook not found: $PLAYBOOK"
    exit 1
fi

# Check if ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    print_error "ansible-playbook not found. Please install Ansible."
    exit 1
fi

print_info "====================================="
print_info "OpenClaw Ansible Deployment"
print_info "====================================="
print_info "Inventory: $INVENTORY"
print_info "Playbook: $PLAYBOOK"
if [ "$DRY_RUN" = true ]; then
    print_warn "Running in CHECK MODE (dry-run)"
fi
print_info "====================================="
echo

# Test connectivity
print_info "Testing connectivity to hosts..."
if ansible all -i "$INVENTORY" -m ping $VERBOSE; then
    print_info "✓ All hosts are reachable"
else
    print_error "✗ Cannot reach one or more hosts"
    exit 1
fi
echo

# Install required collections if needed
if [ -f "requirements.yml" ]; then
    print_info "Installing Ansible Galaxy requirements..."
    ansible-galaxy install -r requirements.yml
    echo
fi

# Build ansible-playbook command
CMD="ansible-playbook -i $INVENTORY $PLAYBOOK"

if [ "$DRY_RUN" = true ]; then
    CMD="$CMD --check --diff"
fi

if [ -n "$VERBOSE" ]; then
    CMD="$CMD $VERBOSE"
fi

if [ -n "$TAGS" ]; then
    CMD="$CMD $TAGS"
fi

if [ -n "$SKIP_TAGS" ]; then
    CMD="$CMD $SKIP_TAGS"
fi

# Run the playbook
print_info "Running playbook..."
echo
print_info "Command: $CMD"
echo

if eval "$CMD"; then
    echo
    print_info "====================================="
    print_info "✓ Deployment completed successfully!"
    print_info "====================================="
    
    if [ "$DRY_RUN" = true ]; then
        print_warn "This was a dry-run. No changes were made."
        print_warn "Run without --check to apply changes."
    else
        print_info "Next steps:"
        print_info "1. SSH to the VM and configure secrets if needed"
        print_info "2. Configure Tailscale: sudo tailscale up"
        print_info "3. Start OpenClaw: sudo systemctl start openclaw"
        print_info "4. Check logs: sudo journalctl -u openclaw -f"
    fi
else
    echo
    print_error "====================================="
    print_error "✗ Deployment failed!"
    print_error "====================================="
    exit 1
fi
