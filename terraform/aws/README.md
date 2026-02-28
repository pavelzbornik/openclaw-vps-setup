# terraform/aws — OpenClaw S3 Backup Bucket

Provisions the AWS infrastructure required for OpenClaw's encrypted daily backups:

- **S3 bucket** — versioned, SSE-AES256, all public access blocked, optional 90-day lifecycle expiry
- **IAM user** (`openclaw-backup`) — least-privilege: `s3:ListBucket`, `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject` scoped to the single bucket
- **IAM access key** — written directly to 1Password (never output to terminal or state in plaintext)
- **1Password item** (`AWS Backup` in the `OpenClaw` vault) — updated with `access_key_id`, `secret_access_key`, `s3_bucket`, and `passphrase` fields consumed by `ansible/backup.yml`

## Credential separation

| Vault | Item | Held by | Purpose |
|-------|------|---------|---------|
| `OpenClaw Admin` | `AWS Admin` | Terraform operator | High-privilege AWS credentials used only during `terraform apply` |
| `OpenClaw` | `AWS Backup` | OpenClaw agent on VM | Scoped IAM credentials written by this module |

The agent never sees the admin credentials.

## Pre-requisites

1. Create the **`OpenClaw Admin`** vault in 1Password
2. Add an `AWS Admin` item with two fields: `access_key_id` and `secret_access_key` (an IAM user or root account key with permissions to create S3 buckets and IAM users)
3. Have a 1Password service account token with read access to `OpenClaw Admin` and write access to `OpenClaw`

## Usage

```bash
# 1. Navigate to this directory
cd terraform/aws

# 2. Copy and fill in the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit: set bucket_name (globally unique) and backup_passphrase

# 3. Export the 1Password service account token
export OP_SERVICE_ACCOUNT_TOKEN=ops_...

# 4. Initialise and apply
terraform init
terraform plan
terraform apply
```

After a successful apply, the `OpenClaw / AWS Backup` 1Password item will contain all four fields required by `ansible/backup.yml`.

## Next steps

After provisioning the S3 bucket with `terraform apply`:

- **Deploy the backup cron job** — run `ansible/backup.yml` to install the daily encrypted backup job on the VM:
  ```bash
  ansible-playbook -i ansible/inventory/hosts.yml ansible/backup.yml
  ```
- **Restore from a backup** — run `ansible/restore.yml` with the S3 path for one-shot restores or migrations:
  ```bash
  ansible-playbook -i ansible/inventory/hosts.yml ansible/restore.yml \
    -e openclaw_restore_s3_path=s3://your-bucket/openclaw/openclaw-TIMESTAMP.tgz.enc
  ```
- The `AWS Backup` item in the `OpenClaw` 1Password vault contains the credentials (`access_key_id`, `secret_access_key`, `s3_bucket`, `passphrase`) consumed by both playbooks.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `bucket_name` | `"openclaw-backups"` | S3 bucket name (must be globally unique) |
| `aws_region` | `"us-east-1"` | AWS region |
| `iam_user_name` | `"openclaw-backup"` | IAM username |
| `onepassword_admin_vault` | `"OpenClaw Admin"` | Vault holding admin AWS creds |
| `onepassword_admin_item` | `"AWS Admin"` | Item holding admin AWS creds |
| `onepassword_vault` | `"OpenClaw"` | Vault to write scoped creds into |
| `onepassword_aws_item` | `"AWS Backup"` | Item to write scoped creds into |
| `backup_passphrase` | *(required)* | AES-256 backup encryption passphrase |
| `enable_lifecycle` | `true` | Enable object expiry lifecycle rule |
| `backup_retention_days` | `90` | Days before `.tgz.enc` objects expire |

## Outputs

| Output | Description |
|--------|-------------|
| `bucket_name` | S3 bucket name |
| `bucket_arn` | S3 bucket ARN |
| `iam_user_arn` | IAM user ARN |
| `iam_user_name` | IAM username |

> IAM access keys are **not** output — they are written directly to 1Password.
