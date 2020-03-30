output "bucket_domain_name" {
  value       = var.enabled == "true" ? join("", aws_s3_bucket.default.*.bucket_domain_name) : ""
  description = "FQDN of bucket"
}

output "bucket_id" {
  value       = var.enabled == "true" ? join("", aws_s3_bucket.default.*.id) : ""
  description = "Bucket Name (aka ID)"
}

output "bucket_arn" {
  value       = var.enabled == "true" ? join("", aws_s3_bucket.default.*.arn) : ""
  description = "Bucket ARN"
}

output "user_name" {
  value       = element(concat(aws_iam_user.default.*.name, [""]), 0)
  description = "Normalized IAM user name"
}

output "user_arn" {
  value       = element(concat(aws_iam_user.default.*.arn, [""]), 0)
  description = "The ARN assigned by AWS for the user"
}

output "user_unique_id" {
  value       = element(concat(aws_iam_user.default.*.unique_id, [""]), 0)
  description = "The user unique ID assigned by AWS"
}

output "access_key_id" {
  sensitive   = true
  value       = element(concat(aws_iam_access_key.default.*.id, [""]), 0)
  description = "The access key ID"
}

output "secret_access_key" {
  sensitive   = true
  value       = element(concat(aws_iam_access_key.default.*.secret, [""]), 0)
  description = "The secret access key. This will be written to the state file in plain-text"
}

