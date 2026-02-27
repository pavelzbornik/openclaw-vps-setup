# 1Password provider — reads admin credentials and writes scoped backup credentials
# Requires: OP_SERVICE_ACCOUNT_TOKEN environment variable
provider "onepassword" {}

# Fetch high-privilege admin AWS credentials from the OpenClaw Admin vault.
# These are used only to configure the AWS provider and never written anywhere.
data "onepassword_item" "aws_admin" {
  vault = var.onepassword_admin_vault
  title = var.onepassword_admin_item
}

provider "aws" {
  region     = var.aws_region
  access_key = data.onepassword_item.aws_admin.username
  secret_key = data.onepassword_item.aws_admin.password
}

# ── S3 bucket ──────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "backup" {
  bucket = var.bucket_name

  tags = {
    Project     = "openclaw"
    ManagedBy   = "terraform"
    Description = "OpenClaw agent encrypted daily backups"
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  count  = var.enable_lifecycle ? 1 : 0
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "expire-encrypted-backups"
    status = "Enabled"

    filter {
      suffix = ".tgz.enc"
    }

    expiration {
      days = var.backup_retention_days
    }
  }
}

# ── IAM user (scoped, least-privilege) ────────────────────────────────────────

resource "aws_iam_user" "backup" {
  name = var.iam_user_name

  tags = {
    Project   = "openclaw"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_user_policy" "backup" {
  name = "openclaw-backup-s3"
  user = aws_iam_user.backup.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.backup.arn]
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
        ]
        Resource = ["${aws_s3_bucket.backup.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}

# ── Write scoped credentials to 1Password (OpenClaw vault) ────────────────────

resource "onepassword_item" "aws_backup" {
  vault    = var.onepassword_vault
  title    = var.onepassword_aws_item
  category = "login"

  username = aws_iam_access_key.backup.id
  password = aws_iam_access_key.backup.secret

  section {
    label = "AWS"

    field {
      label = "access_key_id"
      type  = "STRING"
      value = aws_iam_access_key.backup.id
    }

    field {
      label = "secret_access_key"
      type  = "CONCEALED"
      value = aws_iam_access_key.backup.secret
    }

    field {
      label = "s3_bucket"
      type  = "STRING"
      value = aws_s3_bucket.backup.id
    }

    field {
      label = "passphrase"
      type  = "CONCEALED"
      value = var.backup_passphrase
    }
  }
}
