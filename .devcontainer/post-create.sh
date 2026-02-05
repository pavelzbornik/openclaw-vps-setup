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

# Find the running ubuntu-target container (Compose-managed name)
TARGET_CONTAINER_ID=$(docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1)
if [ -z "$TARGET_CONTAINER_ID" ]; then
        print_warn "Could not find a running ubuntu-target container via Docker labels yet."
fi

# Wait for target container to be ready
print_info "Waiting for target container to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if [ -n "$TARGET_CONTAINER_ID" ] && docker exec "$TARGET_CONTAINER_ID" echo "ready" &>/dev/null; then
        print_info "✓ Target container is ready!"
        break
    fi
    TARGET_CONTAINER_ID=$(docker ps -q --filter label=com.docker.compose.service=ubuntu-target | head -n 1)
    attempt=$((attempt + 1))
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    print_warn "Target container is not responding yet. You may need to wait a bit longer."
fi

# Copy SSH public key to target container
print_info "Setting up SSH access to target container..."
if [ -n "$TARGET_CONTAINER_ID" ]; then
    if docker exec "$TARGET_CONTAINER_ID" test -d /root/.ssh; then
        docker exec "$TARGET_CONTAINER_ID" mkdir -p /root/.ssh
    fi
fi

# Copy the SSH public key
SSH_PUB_KEY=$(cat ~/.ssh/id_ed25519.pub)
if [ -n "$TARGET_CONTAINER_ID" ]; then
    docker exec "$TARGET_CONTAINER_ID" bash -c "mkdir -p /root/.ssh && echo '$SSH_PUB_KEY' >> /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys"
else
    print_warn "Skipping SSH key copy because ubuntu-target container was not found."
fi

# Test SSH connection
print_info "Testing SSH connection to target container..."
if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_ed25519 root@ubuntu-target "echo 'SSH connection successful'" &>/dev/null; then
    print_info "✓ SSH connection to target container works!"
else
    print_warn "SSH connection test failed. You may need to set this up manually."
fi

# Test Ansible connectivity
print_info "Testing Ansible connectivity..."
if ansible all -i inventory/test-container.yml -m ping &>/dev/null; then
    print_info "✓ Ansible can connect to target container!"
else
    print_warn "Ansible ping test failed. Try running: ansible all -i inventory/test-container.yml -m ping"
fi

# Create helper scripts
print_info "Creating helper scripts..."

cat > /workspaces/openclaw/ansible/test-deploy.sh << 'TESTEOF'
#!/bin/bash
# Test deployment to container

set -e

echo "🧪 Testing Ansible deployment to container..."

# Use test inventory
INVENTORY="inventory/test-container.yml"

# Test connectivity
echo "Testing connectivity..."
ansible all -i "$INVENTORY" -m ping

# Run playbook
echo "Running playbook..."
ansible-playbook -i "$INVENTORY" site.yml "$@"

echo "✅ Deployment test complete!"
TESTEOF

chmod +x /workspaces/openclaw/ansible/test-deploy.sh

# Print completion message
echo ""
echo "=========================================="
print_info "✅ Development environment ready!"
echo "=========================================="
echo ""
echo "Available commands:"
echo "  • Test connectivity:  ansible all -i inventory/test-container.yml -m ping"
echo "  • Deploy to container: ./test-deploy.sh"
echo "  • Run Molecule tests:  molecule test"
echo "  • SSH to target:       ssh -i ~/.ssh/id_ed25519 root@172.25.0.10"
echo ""
echo "Container details:"
echo "  • Target Host: ubuntu-target (from inside devcontainer)"
echo "  • SSH Port:   published on a random host port by default"
echo "  • Gateway:    published on a random host port by default"
echo "  • Find ports: docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 22"
echo "              docker compose -f .devcontainer/docker-compose.yml port ubuntu-target 18789"
echo ""
echo "Next steps:"
echo "  1. Test connectivity: make ping INVENTORY=inventory/test-container.yml"
echo "  2. Deploy: ./test-deploy.sh --check"
echo "  3. Deploy for real: ./test-deploy.sh"
echo ""
