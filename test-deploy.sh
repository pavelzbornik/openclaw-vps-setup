#!/bin/bash
# OpenClaw Test Deployment Script
# For use in DevContainer environment to test against ubuntu-target container
# Usage: ./test-deploy.sh [options]

set -e

# Navigate to ansible directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/ansible"

# Ensure upstream vendored roles are discoverable even if ansible.cfg
# is ignored due to directory permissions.
export ANSIBLE_ROLES_PATH="$SCRIPT_DIR/ansible/roles:$SCRIPT_DIR/ansible/vendor/openclaw-ansible/roles${ANSIBLE_ROLES_PATH:+:$ANSIBLE_ROLES_PATH}"

# Use test container inventory by default
INVENTORY="inventory/test-container.yml"
PLAYBOOK="site.yml"
DRY_RUN=false
VERBOSE=""
TAGS=""
SKIP_TAGS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

Test deploy OpenClaw to ubuntu-target container in DevContainer

OPTIONS:
    -h, --help              Show this help message
    -c, --check             Run in check mode (dry-run)
    -v, --verbose           Verbose output
    -vv, --very-verbose     Very verbose output
    -t, --tags TAGS         Run only tasks with these tags
    -s, --skip-tags TAGS    Skip tasks with these tags
    -i, --inventory FILE    Use custom inventory file (default: inventory/test-container.yml)

EXAMPLES:
    # Dry-run to see what would change
    $0 --check

    # Full test deployment
    $0

    # Deploy only NodeJS role
    $0 --tags nodejs

    # Deploy with verbose output
    $0 -vv

EOF
    exit 0
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
    print_info "Creating test inventory at $INVENTORY..."
    
    # Create the test inventory file
    mkdir -p "$(dirname "$INVENTORY")"
    cat > "$INVENTORY" << 'INVENTORY_EOF'
# Test container inventory for DevContainer testing
[all]
ubuntu-target ansible_connection=docker ansible_host=ubuntu-target

[all:vars]
ansible_user=root
ansible_python_interpreter=/usr/bin/python3
INVENTORY_EOF
    
    if [ -f "$INVENTORY" ]; then
        print_info "✓ Test inventory created at $INVENTORY"
    else
        print_error "Failed to create inventory file"
        exit 1
    fi
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
print_info "OpenClaw Test Deployment"
print_info "====================================="
print_info "Target: ubuntu-target (Docker container)"
print_info "Inventory: $INVENTORY"
print_info "Playbook: $PLAYBOOK"
if [ "$DRY_RUN" = true ]; then
    print_warn "Running in CHECK MODE (dry-run)"
fi
print_info "====================================="
echo

# Test connectivity
print_info "Testing connectivity to ubuntu-target..."
if ansible all -i "$INVENTORY" -m ping $VERBOSE; then
    print_info "✓ Target container is reachable"
else
    print_error "✗ Cannot reach ubuntu-target container"
    print_error "Make sure the ubuntu-target container is running"
    exit 1
fi
echo

# Install required collections if needed
if [ -f "requirements.yml" ]; then
    print_info "Installing Ansible Galaxy requirements..."
    ansible-galaxy collection install -r requirements.yml
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
    print_info "✓ Test deployment completed successfully!"
    print_info "====================================="
    
    if [ "$DRY_RUN" = true ]; then
        print_warn "This was a dry-run. No changes were made."
        print_warn "Run without --check to apply changes."
    else
        print_info "Next steps:"
        print_info "1. SSH into container: ssh -i ~/.ssh/id_ed25519 root@ubuntu-target"
        print_info "2. Check OpenClaw service: sudo systemctl status openclaw"
        print_info "3. Check logs: sudo journalctl -u openclaw -f"
    fi
else
    echo
    print_error "====================================="
    print_error "✗ Test deployment failed!"
    print_error "====================================="
    exit 1
fi
