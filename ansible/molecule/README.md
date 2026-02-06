# Molecule Testing for OpenClaw Ansible

This directory contains Molecule test scenarios for validating the OpenClaw Ansible playbooks.

## Prerequisites

```bash
# Install Molecule and dependencies
pip3 install molecule molecule-plugins[docker] ansible-lint docker
```

## Running Tests

```bash
# Full test cycle
molecule test

# Individual steps
molecule create      # Create test container
molecule converge    # Apply playbook
molecule verify      # Run verification tests
molecule login       # SSH into test container
molecule destroy     # Destroy test container

# Test with specific scenario
molecule test -s default
```

## Test Scenarios

### Default Scenario

Tests the complete OpenClaw provisioning on Ubuntu 24.04:

- Creates Docker container with systemd
- Applies roles: openclaw_vendor_base (wrapper around official submodule tasks), common, onepassword, openclaw_git, openclaw
- Verifies installation and configuration
- Checks service status

## Customization

Edit `molecule/default/molecule.yml` to customize:

- Container image
- Platform configuration
- Test variables
- Provisioner options

## Troubleshooting

**Docker not found:**

```bash
# Ensure Docker is running
docker ps
```

**Permission denied:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**Container fails to start:**

```bash
# Check logs
molecule --debug create
```

## CI/CD Integration

Include in your CI pipeline:

```yaml
- name: Test with Molecule
  run: |
    cd ansible
    molecule test
```
