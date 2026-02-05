# Makefile for OpenClaw Ansible Deployment

.PHONY: help install test deploy check lint clean snapshot

# Default inventory (override with INVENTORY=inventory/test-container.yml for devcontainer)
INVENTORY ?= inventory/hosts.yml

# Default target
help:
	@echo "OpenClaw Ansible Deployment"
	@echo ""
	@echo "Available targets:"
	@echo "  install       - Install Ansible and dependencies"
	@echo "  test          - Run Molecule tests"
	@echo "  deploy        - Deploy to VM"
	@echo "  check         - Dry-run deployment"
	@echo "  lint          - Lint playbooks with ansible-lint"
	@echo "  ping          - Test connectivity to VM"
	@echo "  ssh-setup     - Setup SSH access to VM"
	@echo "  clean         - Clean up test artifacts"
	@echo "  snapshot      - Create Hyper-V VM snapshot (Windows host)"
	@echo "  test-deploy   - Deploy to test container (devcontainer)"
	@echo ""
	@echo "Examples:"
	@echo "  make test                                    # Run all tests"
	@echo "  make check                                   # Dry-run deployment"
	@echo "  make deploy                                  # Deploy to VM"
	@echo "  make deploy TAGS=openclaw                    # Deploy only OpenClaw role"
	@echo "  make deploy INVENTORY=inventory/test-container.yml  # Deploy to devcontainer target"
	@echo ""
	@echo "DevContainer Testing:"
	@echo "  make ping INVENTORY=inventory/test-container.yml     # Test container connectivity"
	@echo "  make test-deploy                                     # Quick deploy to container"

# Install Ansible and dependencies
install:
	@echo "Installing Ansible and dependencies..."
	sudo apt update
	sudo apt install -y software-properties-common
	sudo add-apt-repository --yes --update ppa:ansible/ansible
	sudo apt install -y ansible
	pip3 install molecule molecule-plugins[docker] ansible-lint docker
	ansible-galaxy install -r requirements.yml
	@echo "✓ Installation complete"

# Run Molecule tests
test:
	@echo "Running Molecule tests..."
	cd .. && molecule test

# Deploy to VM
deploy:
	@echo "Deploying OpenClaw to VM..."
	cd .. && bash scripts/deploy.sh $(if $(VERBOSE),-vv) $(if $(TAGS),--tags $(TAGS)) $(if $(SKIP_TAGS),--skip-tags $(SKIP_TAGS))

# Dry-run deployment
check:
	@echo "Running deployment check (dry-run)..."
	cd .. && bash scripts/deploy.sh --check -vv

# Lint playbooks
lint:
	@echo "Linting Ansible playbooks..."
	cd .. && ansible-lint site.yml

# Test connectivity
ping:
	@echo "Testing connectivity to VM..."
	cd .. && ansible all -i $(INVENTORY) -m ping

# Setup SSH
ssh-setup:
	@echo "Setting up SSH access..."
	cd .. && bash scripts/setup-ssh.sh

# Clean up
clean:
	@echo "Cleaning up test artifacts..."
	cd .. && molecule destroy || true
	rm -rf molecule/default/.molecule
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	@echo "✓ Cleanup complete"

# Create VM snapshot (requires PowerShell on Windows host)
snapshot:
	@echo "Creating Hyper-V VM snapshot..."
	@echo "Note: This should be run from Windows host or via SSH to Windows"
	@read -p "Enter snapshot name (default: pre-deploy-$$(date +%Y%m%d-%H%M)): " name; \
	name=$${name:-pre-deploy-$$(date +%Y%m%d-%H%M)}; \
	echo "Creating snapshot: $$name"; \
	echo "Run this on Windows host:"; \
	echo "  Checkpoint-VM -Name OpenClaw-VM -SnapshotName $$name"

# Quick deploy specific roles
deploy-common:
	$(MAKE) deploy TAGS=common

deploy-nodejs:
	$(MAKE) deploy TAGS=nodejs

deploy-openclaw:
	$(MAKE) deploy TAGS=openclaw

deploy-firewall:
	$(MAKE) deploy TAGS=firewall

# View logs from VM
logs:
	@echo "Fetching OpenClaw logs from VM..."
	ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10 "sudo journalctl -u openclaw -f"

# Check service status on VM
status:
	@echo "Checking OpenClaw service status..."
	ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10 "sudo systemctl status openclaw"

# Restart OpenClaw service on VM
restart:
	@echo "Restarting OpenClaw service..."
	ssh -i ~/.ssh/openclaw_vm openclaw@192.168.100.10 "sudo systemctl restart openclaw"
	@echo "✓ Service restarted"

# Deploy to test container (devcontainer)
test-deploy:
	@echo "Deploying to test container..."
	cd .. && bash test-deploy.sh $(if $(VERBOSE),-vv) $(if $(TAGS),--tags $(TAGS))
