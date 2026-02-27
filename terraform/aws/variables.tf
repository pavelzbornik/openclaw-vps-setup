variable "bucket_name" {
  description = "S3 bucket name for OpenClaw backups (must be globally unique)"
  type        = string
  default     = "openclaw-backups"
}

variable "aws_region" {
  description = "AWS region for the S3 bucket and IAM resources"
  type        = string
  default     = "us-east-1"
}

variable "iam_user_name" {
  description = "IAM username for the scoped backup user"
  type        = string
  default     = "openclaw-backup"
}

variable "onepassword_admin_vault" {
  description = "1Password vault containing high-privilege admin AWS credentials (used only by Terraform)"
  type        = string
  default     = "OpenClaw Admin"
}

variable "onepassword_admin_item" {
  description = "1Password item containing admin AWS access key fields: access_key_id, secret_access_key"
  type        = string
  default     = "AWS Admin"
}

variable "onepassword_vault" {
  description = "1Password vault where scoped backup credentials are written (read by the OpenClaw agent)"
  type        = string
  default     = "OpenClaw"
}

variable "onepassword_aws_item" {
  description = "1Password item to create/update with scoped IAM credentials and bucket name"
  type        = string
  default     = "AWS Backup"
}

variable "backup_passphrase" {
  description = "AES-256 passphrase used by the backup script to encrypt archives (stored in 1Password alongside credentials)"
  type        = string
  sensitive   = true
}

variable "enable_lifecycle" {
  description = "Enable S3 lifecycle rules to expire old backup objects"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days before encrypted backup objects (.tgz.enc) are deleted"
  type        = number
  default     = 90
}
