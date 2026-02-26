# Backup and Restore

OpenClaw state (config, credentials, sessions, workspace) is stored in `~/.openclaw/` on the VM.
This project provides two standalone playbooks:

- **`ansible/backup.yml`** — deploys a daily encrypted backup cron job that uploads to S3
- **`ansible/restore.yml`** — one-shot restore from a specific S3 backup archive

Both use **1Password** to retrieve secrets at runtime (encryption passphrase, AWS credentials).
No secrets are stored on disk in plaintext.

---

## Prerequisites

### 1. S3 bucket

Create an S3 bucket (or use an existing one) and note the bucket name and region.

### 2. 1Password items

The playbooks read secrets from 1Password via `op read`. Create these items in your vault
(default vault name: `OpenClaw` — override with `openclaw_*_vault` variables in `group_vars/all.yml`):

| Item name | Fields required | Used for |
|---|---|---|
| `AWS Backup` | `access_key_id`, `secret_access_key`, `s3_bucket`, `passphrase` | S3 credentials and AES-256 encryption/decryption of backup archives |

The 1Password service account token is stored in `group_vars/vault.yml`:

```yaml
vault_openclaw_op_service_account_token: "ops_REPLACE_ME"
```

### 3. Ansible Vault

If not already done:

```bash
cp ansible/group_vars/vault.example.yml ansible/group_vars/vault.yml
# edit vault.yml and fill in real values
ansible-vault encrypt ansible/group_vars/vault.yml
```

---

## Configuration

All backup variables are in `ansible/group_vars/all.yml` under the `Backup / Restore` section:

| Variable | Default | Description |
|---|---|---|
| `openclaw_s3_bucket` | `""` | **Required.** S3 bucket name |
| `openclaw_s3_prefix` | `openclaw` | Key prefix inside the bucket |
| `openclaw_s3_region` | `us-east-1` | AWS region |
| `openclaw_backup_cron_hour` | `2` | UTC hour for daily backup |
| `openclaw_backup_cron_minute` | `0` | UTC minute for daily backup |
| `openclaw_backup_passphrase_vault` | `OpenClaw` | 1Password vault for passphrase |
| `openclaw_backup_passphrase_item` | `AWS Backup` | 1Password item name |
| `openclaw_backup_passphrase_field` | `passphrase` | 1Password field name |
| `openclaw_aws_key_vault` | `OpenClaw` | 1Password vault for AWS keys |
| `openclaw_aws_key_item` | `AWS Backup` | 1Password item name |
| `openclaw_aws_access_key_field` | `access_key_id` | 1Password field for access key |
| `openclaw_aws_secret_key_field` | `secret_access_key` | 1Password field for secret key |
| `openclaw_aws_s3_bucket_field` | `s3_bucket` | 1Password field for S3 bucket name |

Set `openclaw_s3_bucket` either in `group_vars/vault.yml` (recommended) or pass it on the CLI.

---

## Setup: Deploy the Backup Cron Job

Run once after provisioning. Idempotent — safe to rerun to update the schedule or script.

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/backup.yml \
  -e openclaw_s3_bucket=my-bucket \
  -e openclaw_op_service_account_token=ops_...
```

If `openclaw_s3_bucket` and `vault_openclaw_op_service_account_token` are set in vault.yml, just:

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/backup.yml \
  --ask-vault-pass
```

What this deploys on the VM:

- `/usr/local/bin/openclaw-backup.sh` — backup script (templated)
- `/etc/openclaw/backup.env` — 1Password token file (mode 0600, root-only)
- `/var/lib/openclaw/backups/` — staging directory for in-progress archives
- `/etc/logrotate.d/openclaw-backup` — weekly rotation of `/var/log/openclaw-backup.log`
- Cron job running as root at the configured UTC time

### What the backup script does

1. Reads the encryption passphrase and AWS credentials from 1Password at runtime
2. Stops the openclaw service (ensures consistent snapshot)
3. Creates a timestamped `.tgz` archive of `~/.openclaw/`
4. Encrypts it with AES-256-CBC (OpenSSL + PBKDF2)
5. Uploads the encrypted archive to `s3://<bucket>/<prefix>/openclaw-<timestamp>.tgz.enc`
6. Deletes the local plaintext and encrypted copies
7. Restarts the openclaw service (via `trap` — runs even on failure)

Backup log: `/var/log/openclaw-backup.log`

### Verify a backup ran

```bash
# On the VM
sudo tail -f /var/log/openclaw-backup.log

# From your workstation
aws s3 ls s3://my-bucket/openclaw/ --recursive
```

---

## Restore from Backup

### Find the archive to restore

```bash
aws s3 ls s3://my-bucket/openclaw/ --recursive
```

Archives are named `openclaw-<unix-timestamp>.tgz.enc`. Pick the one you want.

### Run the restore playbook

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/restore.yml \
  -e openclaw_restore_s3_path=s3://my-bucket/openclaw/openclaw-1234567890.tgz.enc \
  -e openclaw_op_service_account_token=ops_... \
  --ask-vault-pass
```

### What the restore playbook does

1. Reads the decryption passphrase and AWS credentials from 1Password
2. Stops the openclaw service
3. Renames the existing `~/.openclaw/` to `~/.openclaw.pre-restore-<epoch>.bak` (safety copy)
4. Downloads the encrypted archive from S3 to `/tmp/openclaw-restore/`
5. Decrypts with the same AES-256-CBC passphrase
6. Extracts to `{{ openclaw_home }}` (restores `~/.openclaw/`)
7. Fixes file ownership (`openclaw:openclaw`)
8. Runs `openclaw doctor --non-interactive`
9. Starts the openclaw service
10. Waits for the gateway port to be reachable
11. Cleans up `/tmp/openclaw-restore/` in all cases (including failure)

If the restore fails, the playbook restarts the service and re-raises the error.
The pre-restore backup at `~/.openclaw.pre-restore-<epoch>.bak` is preserved for manual recovery.

---

## Migration to a New VM

To migrate OpenClaw to a new VM:

1. Provision the new VM with the main playbook (`ansible/site.yml`)
2. Find the latest backup in S3
3. Run `ansible/restore.yml` against the new VM's inventory
4. Verify: `ssh openclaw@new-vm openclaw status`

The restore playbook handles service lifecycle, ownership, and schema migration via `openclaw doctor`.
