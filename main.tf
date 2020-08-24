resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name}.logs"
  acl           = "log-delivery-write"
  force_destroy = var.force_destroy

  lifecycle_rule {
    id                                     = "Remove versions after ${var.log_retention_days} days"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 7

    noncurrent_version_expiration {
      days = var.log_retention_days
    }

    expiration {
      days = var.log_retention_days
      expired_object_delete_marker = true
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.kms_master_key_id
        sse_algorithm     = var.sse_algorithm
      }
    }
  }

  tags = {
    Name = var.name
  }
}

resource "aws_s3_bucket" "default" {
  count         = var.enabled == "true" ? 1 : 0
  bucket        = var.name
  acl           = var.acl
  region        = var.region
  force_destroy = var.force_destroy
  policy        = var.policy

  versioning {
    enabled = var.versioning_enabled
  }

  logging {
    target_bucket = aws_s3_bucket.logs.id
    target_prefix = "${var.name}-s3/"
  }

  lifecycle_rule {
    id                                     = "Remove versions after ${var.version_retention_days} days"
    enabled                                = var.lifecycle_enabled
    abort_incomplete_multipart_upload_days = 7

    noncurrent_version_expiration {
      days = var.version_retention_days
    }

    noncurrent_version_transition {
      days          = var.noncurrent_version_transition_days
      storage_class = "GLACIER"
    }

    transition {
      days          = var.standard_transition_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.glacier_transition_days
      storage_class = "GLACIER"
    }

    expiration {
      expired_object_delete_marker = true
    }
  }

  # https://docs.aws.amazon.com/AmazonS3/latest/dev/bucket-encryption.html
  # https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#enable-default-server-side-encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.sse_algorithm
        kms_master_key_id = var.kms_master_key_id
      }
    }
  }

  tags = {
    Name = var.name
  }

  depends_on = [aws_s3_bucket.logs]
}

data "aws_iam_policy_document" "bucket_policy" {
  count = var.enabled == "true" && var.allow_encrypted_uploads_only == "true" ? 1 : 0

  statement {
    sid       = "DenyIncorrectEncryptionHeader"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.default[0].id}/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "StringNotEquals"
      values   = [var.sse_algorithm]
      variable = "s3:x-amz-server-side-encryption"
    }
  }

  statement {
    sid       = "DenyUnEncryptedObjectUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.default[0].id}/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "Null"
      values   = ["true"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}

resource "aws_s3_bucket_policy" "force_encrypted" {
  count  = var.enabled == "true" && var.allow_encrypted_uploads_only == "true" ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  policy = join("", data.aws_iam_policy_document.bucket_policy.*.json)
}

data "aws_iam_policy_document" "default_bucket_policy" {
  count = var.enabled == "true" && var.allow_datadog_lambda_logging == "true" ? 1 : 0

  statement {
    sid    = "allow datadog lambda Get and List"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.default[0].id}",
      "arn:aws:s3:::${aws_s3_bucket.default[0].id}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "default" {
  count  = var.enabled == "true" && var.allow_datadog_lambda_logging == "true" ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  policy = join(
    "",
    data.aws_iam_policy_document.default_bucket_policy.*.json,
  )
}

data "aws_iam_policy_document" "log_bucket_policy" {
  count = var.enabled == "true" && var.allow_datadog_lambda_logging == "true" ? 1 : 0

  statement {
    sid    = "allow datadog lambda Get and List"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.logs.id}",
      "arn:aws:s3:::${aws_s3_bucket.logs.id}/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "default_log" {
  count  = var.enabled == "true" && var.allow_datadog_lambda_logging == "true" ? 1 : 0
  bucket = join("", aws_s3_bucket.logs.*.id)

  policy = join("", data.aws_iam_policy_document.log_bucket_policy.*.json)
}

