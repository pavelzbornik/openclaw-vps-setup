output "bucket_name" {
  description = "S3 bucket name (written to 1Password AWS Backup item as 's3_bucket')"
  value       = aws_s3_bucket.backup.id
}

output "bucket_arn" {
  description = "ARN of the S3 backup bucket"
  value       = aws_s3_bucket.backup.arn
}

output "iam_user_arn" {
  description = "ARN of the scoped IAM backup user"
  value       = aws_iam_user.backup.arn
}

output "iam_user_name" {
  description = "Name of the scoped IAM backup user"
  value       = aws_iam_user.backup.name
}
