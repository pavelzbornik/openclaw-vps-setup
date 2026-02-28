#!/bin/bash
# Internal helper — called only by Justfile recipes. Not for direct use.
# Usage: run-playbook.sh --inventory <file> [ansible-playbook args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export ANSIBLE_CONFIG="${ANSIBLE_DIR}/ansible.cfg"
export ANSIBLE_ROLES_PATH="${ANSIBLE_DIR}/roles:${ANSIBLE_DIR}/vendor/openclaw-ansible/roles${ANSIBLE_ROLES_PATH:+:${ANSIBLE_ROLES_PATH}}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Pull --inventory value out of args; pass everything else through.
INVENTORY=""
PASSTHROUGH=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --inventory|-i)
            INVENTORY="$2"
            shift 2
            ;;
        *)
            PASSTHROUGH+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$INVENTORY" ]]; then
    error "--inventory is required"
    exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
    error "Inventory file not found: $INVENTORY"
    exit 1
fi

if ! command -v ansible-playbook &>/dev/null; then
    error "ansible-playbook not found. Run: just install"
    exit 1
fi

# ── Connectivity check ───────────────────────────────────────────────────────
info "Testing connectivity..."
if ansible all -i "$INVENTORY" -m ping; then
    info "✓ All hosts reachable"
else
    error "✗ One or more hosts unreachable"
    exit 1
fi
echo

# ── Galaxy requirements ──────────────────────────────────────────────────────
if [[ -f "${ANSIBLE_DIR}/requirements.yml" ]]; then
    info "Installing Galaxy requirements..."
    ansible-galaxy collection install -r "${ANSIBLE_DIR}/requirements.yml"
    echo
fi

# ── Run playbook ─────────────────────────────────────────────────────────────
PLAYBOOK="${ANSIBLE_DIR}/site.yml"
CMD=(ansible-playbook -i "$INVENTORY" "$PLAYBOOK" "${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}")

info "Command: ${CMD[*]}"
echo

if "${CMD[@]}"; then
    echo
    info "====================================="
    info "✓ Playbook completed successfully!"
    info "====================================="
else
    echo
    error "====================================="
    error "✗ Playbook failed!"
    error "====================================="
    exit 1
fi
