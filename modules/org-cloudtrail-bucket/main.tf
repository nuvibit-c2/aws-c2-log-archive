
# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ KMS KEY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "org_cloudtrail_bucket_kms" {
  description             = "encryption key for SSE of cloudtrail bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.org_cloudtrail_bucket_kms.json
}

data "aws_iam_policy_document" "org_cloudtrail_bucket_kms" {
  # enable IAM access
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # allow access for organization cloudtrail
  statement {
    sid       = "Allow CloudTrail to encrypt logs"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values = [
        format(
          "arn:aws:cloudtrail:*:%s:trail/%s",
          var.cloudtrail_admin_account_id,
          var.org_cloudtrail_name
        )
      ]
    }
  }

  statement {
    sid       = "Allow CloudTrail to describe key"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_kms_alias" "org_cloudtrail_bucket_kms" {
  name          = format("alias/%s", var.org_cloudtrail_bucket_kms_alias)
  target_key_id = aws_kms_key.org_cloudtrail_bucket_kms.key_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "org_cloudtrail_bucket" {
  bucket = var.org_cloudtrail_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "org_cloudtrail_bucket_sse" {
  bucket = aws_s3_bucket.org_cloudtrail_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_alias.org_cloudtrail_bucket_kms.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "org_cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.org_cloudtrail_bucket.id
  policy = dat.aws_iam_policy_document.org_cloudtrail_bucket_policy.json
}

data "aws_iam_policy_document" "org_cloudtrail_bucket_policy" {
  statement {
    sid    = "allow_org_cloudtrail"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["s3:PutObject"]
    # Only Organization Cloudtrail includes Organization ID in the log path => only Organization CloudTrail is allowed to write
    resource = format("aws:aws:s3:::%s/%s/*/AWSLogs/*", aws_s3_bucket.org_cloudtrail_bucket.name, var.org_id)

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceArn"
      values   = [format("arn:aws:cloudtrail:%s:%s:trail/*", var.org_cloudtrail_region, var.cloudtrail_admin_account_id)]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.org_cloudtrail_bucket_kms.id]
    }
  }

  statement {
    sid = "allow"
  }
}

