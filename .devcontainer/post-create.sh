#!/bin/bash
# Post-creation script for devcontainer setup

set -e

echo "🚀 Setting up OpenClaw Ansible development environment..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Install and configure pre-commit
print_info "Installing pre-commit..."
if ! command -v pre-commit &> /dev/null; then
    pipx install pre-commit
    export PATH="$HOME/.local/bin:$PATH"
fi

print_info "Setting up pre-commit hooks..."
cd /workspaces/openclaw || exit 1
pre-commit install --install-hooks
pre-commit autoupdate || print_warn "Could not update pre-commit hooks (network issue?)"

# Navigate to ansible directory
cd /workspaces/openclaw/ansible || exit 1

# Install Ansible Galaxy requirements
if [ -f "requirements.yml" ]; then
    print_info "Installing Ansible Galaxy requirements..."
    ansible-galaxy collection install -r requirements.yml --force
fi

# Set up inventory for the test container
print_info "Creating test inventory..."
cat > inventory/test-container.yml << 'EOF'
all:
  children:
    test_vms:
      hosts:
        ubuntu-target:
                    ansible_host: ubuntu-target
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
          ansible_python_interpreter: /usr/bin/python3
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
      vars:
        ansible_connection: ssh
EOF

# Detect if we need sudo for docker
DOCKER_SUDO=""
if ! docker ps &> /dev/null 2>&1; then
    DOCKER_SUDO="sudo"
fi

# Find the running ubuntu-target container (Compose-managed name)
TARGET_CONTAINER_ID=$($DOCKER_SUDO docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1)
if [ -z "$TARGET_CONTAINER_ID" ]; then
        print_warn "Could not find a running ubuntu-target container via Docker labels yet."
fi

# Wait for target container to be ready
print_info "Waiting for target container to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if [ -n "$TARGET_CONTAINER_ID" ] && $DOCKER_SUDO docker exec "$TARGET_CONTAINER_ID" echo "ready" &>/dev/null; then
        print_info "✓ Target container is ready!"
        break
    fi
    TARGET_CONTAINER_ID=$($DOCKER_SUDO docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1)
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    print_warn "Target container is not responding yet. You may need to wait a bit longer."
fi

# Setup SSH access to target container
print_info "Setting up SSH access to target container..."

# Get the target container name
TARGET_CONTAINER=$($DOCKER_SUDO docker ps --filter "ancestor=openclaw/ubuntu-target:24.04-systemd" --format "{{.Names}}" | head -1)

if [ -z "$TARGET_CONTAINER" ]; then
    print_warn "Could not find ubuntu-target container. SSH setup will be attempted later."
else
    print_info "Found target container: $TARGET_CONTAINER"

    # Ensure SSH directory exists and generate key if needed
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        print_info "Generating SSH key..."
        mkdir -p ~/.ssh
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "ansible-control"
    fi

    # Get the SSH public key
    SSH_PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)

    # Add public key to root's authorized_keys on target
    print_info "Adding public key to $TARGET_CONTAINER..."
    $DOCKER_SUDO docker exec "$TARGET_CONTAINER" bash -c "
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        echo '$SSH_PUB_KEY' >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    " 2>/dev/null || print_warn "Could not add SSH key to target container yet."

    # Test SSH connection
    print_info "Testing SSH connection to target container..."
    if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 root@ubuntu-target "echo 'SSH connection successful'" &>/dev/null; then
        print_info "✓ SSH connection to target container works!"
    else
        print_warn "SSH connection test failed. The target container may still be starting."
    fi
fi

# Test Ansible connectivity
print_info "Testing Ansible connectivity..."
if ansible all -i inventory/test-container.yml -m ping &>/dev/null; then
    print_info "✓ Ansible can connect to target container!"
else
    print_warn "Ansible ping test failed. Try running: ansible all -i inventory/test-container.yml -m ping"
fi

# Print completion message
echo ""
echo "=========================================="
print_info "✅ Development environment ready!"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  • Test connectivity:  ansible all -i inventory/test-container.yml -m ping"
echo "  • Deploy to container: ./test-deploy.sh --check  (dry-run)"
echo "  • Deploy to container: ./test-deploy.sh         (full deployment)"
echo "  • Run Molecule tests:  molecule test"
echo ""
echo "Container details:"
echo "  • Target Host: ubuntu-target (from inside devcontainer)"
echo "  • SSH Port:   published on a random host port by default"
echo "  • Gateway:    published on a random host port by default"
echo "  • Find ports: docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 22"
echo "              docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 18789"
echo ""
echo "Pre-commit:"
echo "  • Hooks installed:    pre-commit will run on every git commit"
echo "  • Run manually:       pre-commit run --all-files"
echo "  • Cache location:     ~/.cache/pre-commit (persisted via volume)"
echo ""
echo "Next steps:"
echo "  1. Test connectivity: ansible all -i inventory/test-container.yml -m ping"
echo "  2. Deploy (dry-run):  ./test-deploy.sh --check"
echo "  3. Deploy (for real): ./test-deploy.sh"
echo ""
