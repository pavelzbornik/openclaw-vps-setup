set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false

# ── Variables ────────────────────────────────────────────────────────────────

ansible_dir   := justfile_directory() / "ansible"
inventory     := ansible_dir / "inventory/hosts.yml"
test_inventory := ansible_dir / "inventory/test-container.yml"
run_playbook  := ansible_dir / "scripts/run-playbook.sh"

vm_host := "192.168.1.151"
vm_user := "openclaw"
vm_key  := "~/.ssh/openclaw_vm"

# ── Default ──────────────────────────────────────────────────────────────────

[private]
default:
    @just --list

# ── Setup ────────────────────────────────────────────────────────────────────

# Install Ansible, molecule, and Python dependencies
install:
    sudo apt-get update -qq
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible
    pip3 install molecule "molecule-plugins[docker]" ansible-lint docker
    ansible-galaxy collection install -r "{{ansible_dir}}/requirements.yml"
    @echo "✓ Installation complete"

# Install Ansible Galaxy collections only
galaxy:
    ansible-galaxy collection install -r "{{ansible_dir}}/requirements.yml"

# ── Testing ──────────────────────────────────────────────────────────────────

# Run Molecule tests
test:
    cd "{{ansible_dir}}" && molecule test

# Lint Ansible playbooks
lint:
    cd "{{ansible_dir}}" && ansible-lint site.yml

# Run all pre-commit hooks
hooks:
    pre-commit run --all-files

# ── Connectivity ─────────────────────────────────────────────────────────────

# Test connectivity to production VM
ping:
    ANSIBLE_CONFIG="{{ansible_dir}}/ansible.cfg" \
    ansible all -i "{{inventory}}" -m ping

# Test connectivity to devcontainer test target
ping-test:
    ANSIBLE_CONFIG="{{ansible_dir}}/ansible.cfg" \
    ansible all -i "{{test_inventory}}" -m ping

# ── Production deploy ────────────────────────────────────────────────────────

# Deploy to production VM  (tags="", skip="", verbose="")
deploy tags="" skip="" verbose="":
    bash "{{run_playbook}}" \
        --inventory "{{inventory}}" \
        {{ if tags != "" { "--tags " + tags } else { "" } }} \
        {{ if skip != "" { "--skip-tags " + skip } else { "" } }} \
        {{ if verbose != "" { "-" + verbose } else { "" } }}

# Dry-run production deploy
check tags="" skip="":
    bash "{{run_playbook}}" \
        --inventory "{{inventory}}" \
        --check --diff \
        {{ if tags != "" { "--tags " + tags } else { "" } }} \
        {{ if skip != "" { "--skip-tags " + skip } else { "" } }}

# Deploy common role only
deploy-common: (deploy "common")

# Deploy Node.js role only
deploy-nodejs: (deploy "nodejs")

# Deploy Tailscale role only
deploy-tailscale: (deploy "tailscale")

# Deploy openclaw role only
deploy-openclaw: (deploy "openclaw")

# Deploy firewall role only
deploy-firewall: (deploy "firewall")

# Deploy Samba role only
deploy-samba: (deploy "samba")

# ── Test-container deploy ────────────────────────────────────────────────────

# Deploy to devcontainer test target  (tags="", check="")
test-deploy tags="" check="":
    bash "{{run_playbook}}" \
        --inventory "{{test_inventory}}" \
        {{ if check != "" { "--check --diff" } else { "" } }} \
        {{ if tags != "" { "--tags " + tags } else { "" } }}

# Dry-run deploy to devcontainer test target
test-check tags="":
    @just test-deploy tags="{{ tags }}" check="true"

# ── Standalone playbooks ─────────────────────────────────────────────────────

# Deploy daily S3 backup cron job (run once after provisioning)
backup:
    ANSIBLE_CONFIG="{{ansible_dir}}/ansible.cfg" \
    ansible-playbook -i "{{inventory}}" "{{ansible_dir}}/backup.yml"

# Restore from S3 backup (s3_path required, e.g. s3://bucket/prefix/file.tgz.enc)
restore s3_path:
    ANSIBLE_CONFIG="{{ansible_dir}}/ansible.cfg" \
    ansible-playbook -i "{{inventory}}" "{{ansible_dir}}/restore.yml" \
        -e "openclaw_restore_s3_path={{s3_path}}"

# ── SSH / VM management ───────────────────────────────────────────────────────

# Set up SSH key access to the VM  (ip=192.168.1.151, user=claw)
ssh-setup ip=vm_host user="claw":
    bash "{{ansible_dir}}/scripts/setup-ssh.sh" "{{ip}}" "{{user}}"

# Stream OpenClaw service logs from VM
logs:
    ssh -i "{{vm_key}}" "{{vm_user}}@{{vm_host}}" "sudo journalctl -u openclaw -f"

# Check OpenClaw service status on VM
status:
    ssh -i "{{vm_key}}" "{{vm_user}}@{{vm_host}}" "sudo systemctl status openclaw"

# Restart OpenClaw service on VM
restart:
    ssh -i "{{vm_key}}" "{{vm_user}}@{{vm_host}}" "sudo systemctl restart openclaw"
    @echo "✓ Service restarted"

# ── Hyper-V snapshot ──────────────────────────────────────────────────────────

# Print Hyper-V snapshot command to run on Windows host  (name=pre-deploy-<timestamp>)
snapshot name="":
    #!/usr/bin/env bash
    snap_name="{{ if name != "" { name } else { "" } }}"
    if [[ -z "$snap_name" ]]; then
        snap_name="pre-deploy-$(date +%Y%m%d-%H%M)"
    fi
    echo "Creating snapshot: $snap_name"
    echo "Run on Windows host:"
    echo "  Checkpoint-VM -Name OpenClaw-VM -SnapshotName $snap_name"

# ── Cleanup ───────────────────────────────────────────────────────────────────

# Destroy Molecule containers and remove test artifacts
clean:
    cd "{{ansible_dir}}" && molecule destroy || true
    find "{{ansible_dir}}" -type f -name "*.pyc" -delete
    find "{{ansible_dir}}" -type d -name "__pycache__" -delete
    @echo "✓ Cleanup complete"
