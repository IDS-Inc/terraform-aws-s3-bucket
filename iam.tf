resource "aws_iam_user" "default" {
  count         = var.user_enabled ? 1 : 0
  name          = "${aws_s3_bucket.default.*.bucket[0]}-user"
  path          = var.iam_user_path == "" ? "s3" : var.iam_user_path
  force_destroy = var.force_destroy
}

# Generate API credentials
resource "aws_iam_access_key" "default" {
  count = var.user_enabled ? 1 : 0
  user  = aws_iam_user.default.*.name[0]
}

data "aws_iam_policy_document" "default" {
  count = var.user_enabled ? 1 : 0

  statement {
    actions   = var.allowed_bucket_actions
    resources = ["${join("", aws_s3_bucket.default.*.arn)}/*", join("", aws_s3_bucket.default.*.arn)]
    effect    = "Allow"
  }
}

resource "aws_iam_user_policy" "default" {
  count  = var.user_enabled ? 1 : 0
  name   = aws_iam_user.default.*.name[0]
  user   = aws_iam_user.default.*.name[0]
  policy = join("", data.aws_iam_policy_document.default.*.json)
}
