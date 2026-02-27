# Documentation Index

This repository provides Infrastructure-as-Code for automated provisioning and
deployment of the OpenClaw AI agent on Ubuntu VPS or Hyper-V VMs. The docs below
cover everything from first-time setup through day-to-day operations.

## Reading Paths by Persona

| I want to… | Start here |
|------------|-----------|
| **Deploy OpenClaw for the first time** | [README](../README.md) → [Quickstart](../ansible/QUICKSTART.md) → [Ansible deployment](../ansible/README.md) |
| **Test changes in DevContainer** | [README](../README.md) → [DevContainer guide](.devcontainer/README.md) |
| **Set up a Hyper-V VM** | [README](../README.md) → [Hyper-V VM setup](hyperv-setup.md) → [Quickstart](../ansible/QUICKSTART.md) |
| **Contribute code or docs** | [CONTRIBUTING](../CONTRIBUTING.md) → [CLAUDE.md](../CLAUDE.md) → [Ansible deployment](../ansible/README.md) |
| **Debug a broken deployment** | [Troubleshooting](../ansible/TROUBLESHOOTING.md) |
| **Understand the system architecture** | [Architecture (C4 diagrams)](architecture.md) |
| **Report a security issue** | [SECURITY.md](../SECURITY.md) |

---

## All Documents

| Document | Description |
|----------|-------------|
| [Architecture (C4 diagrams)](architecture.md) | System context and container diagrams showing how OpenClaw, Ansible, 1Password, Tailscale, and Discord fit together |
| [Ansible deployment](../ansible/README.md) | Role reference, inventory setup, secrets configuration, and deployment commands |
| [Quickstart](../ansible/QUICKSTART.md) | Step-by-step guide for first-time provisioning from VM creation to a running OpenClaw service |
| [Troubleshooting](../ansible/TROUBLESHOOTING.md) | Solutions for common deployment, connectivity, firewall, 1Password, and Molecule failures |
| [Hyper-V VM setup](hyperv-setup.md) | Windows-specific guide for creating and configuring a Hyper-V Ubuntu VM using the bundled PowerShell automation |
| [Firewall and network controls](firewall.md) | UFW posture, port-matrix table (which role opens what), and Tailscale integration notes |
| [Backup and restore](backup-restore.md) | How the daily S3 backup cron works, how to trigger a manual backup, and how to restore from a snapshot |
| [Discord Terraform](discord-terraform.md) | Why Discord is used as OpenClaw's interface channel and how Terraform manages the server layout |
| [Pre-commit setup](PRE_COMMIT_SETUP.md) | Installing and configuring the pre-commit hooks enforced by this repository |
