# ---------------------------------------------------------------------------------------------------------------------
# ¦ REQUIREMENTS
# ---------------------------------------------------------------------------------------------------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.51.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  partition          = data.aws_partition.current.partition
  current_account_id = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ RANDOM STRING
# ---------------------------------------------------------------------------------------------------------------------
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - API GATEWAY
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_api_gateway_rest_api" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  name        = "${var.forwarder_name_prefix}-api"
  description = "API for forwarding requests to Lambda"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.forwarder[0].id
  parent_id   = aws_api_gateway_rest_api.forwarder[0].root_resource_id
  path_part   = "spacelift"
}

resource "aws_api_gateway_method" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.forwarder[0].id
  resource_id   = aws_api_gateway_resource.forwarder[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.forwarder[0].id
  resource_id             = aws_api_gateway_resource.forwarder[0].id
  http_method             = aws_api_gateway_method.forwarder[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.forwarder.invoke_arn
}

resource "aws_lambda_permission" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forwarder.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.forwarder[0].execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.forwarder[0].id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.forwarder[0].body))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.forwarder
  ]
}

resource "aws_api_gateway_stage" "forwarder" {
  count = var.forwarding_endpoint == "api_gateway" ? 1 : 0

  deployment_id = aws_api_gateway_deployment.forwarder[0].id
  rest_api_id   = aws_api_gateway_rest_api.forwarder[0].id
  stage_name    = "logs"
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - LAMBDA
# ---------------------------------------------------------------------------------------------------------------------
data "archive_file" "lambda_function" {
  output_file_mode = "0666"
  output_path      = "${path.module}/files/event-forwarder-lambda.zip"
  source_file      = "${path.module}/files/event-forwarder-lambda/main.py"
  type             = "zip"
}

resource "aws_lambda_function" "forwarder" {
  filename         = data.archive_file.lambda_function.output_path
  function_name    = "${var.forwarder_name_prefix}-lambda"
  handler          = "main.handler"
  role             = aws_iam_role.forwarder.arn
  runtime          = "python${var.python_version}"
  source_code_hash = data.archive_file.lambda_function.output_base64sha256

  environment {
    variables = {
      SECRET  = var.audit_trail_secret
      STREAM  = aws_kinesis_firehose_delivery_stream.stream.name
      VERBOSE = var.logs_verbose
    }
  }
}

resource "aws_lambda_function_url" "forwarder" {
  count = var.forwarding_endpoint == "lambda_function_url" ? 1 : 0

  authorization_type = "NONE"
  function_name      = aws_lambda_function.forwarder.function_name
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - LAMBDA - IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "forwarder" {
  name = "${var.forwarder_name_prefix}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "forwarder" {
  role = aws_iam_role.forwarder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "firehose:PutRecord"
        ],
        Resource = [aws_kinesis_firehose_delivery_stream.stream.arn]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.forwarder.name
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - CLOUDWATCH
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "forwarder" {
  name              = "/aws/lambda/${var.forwarder_name_prefix}-lambda"
  retention_in_days = var.logs_retention_days
}

resource "aws_cloudwatch_log_group" "stream" {
  name              = "/aws/kinesisfirehose/${var.forwarder_name_prefix}-stream"
  retention_in_days = var.logs_retention_days
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - STREAM
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_stream" "destination_delivery" {
  log_group_name = aws_cloudwatch_log_group.stream.name
  name           = "DestinationDelivery"
}

resource "aws_kinesis_firehose_delivery_stream" "stream" {
  destination = "extended_s3"
  name        = "${var.forwarder_name_prefix}-stream"

  extended_s3_configuration {
    buffering_interval  = var.buffer_interval
    buffering_size      = var.buffer_size
    bucket_arn          = aws_s3_bucket.storage.arn
    error_output_prefix = "error/!{firehose:error-output-type}/"
    compression_format  = "GZIP"
    kms_key_arn         = aws_kms_key.encryption.arn
    prefix              = "year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/"
    role_arn            = aws_iam_role.stream.arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.stream.name
      log_stream_name = aws_cloudwatch_log_stream.destination_delivery.name
    }
  }

  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = aws_kms_key.encryption.arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - STREAM - IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "stream" {
  name = "${var.forwarder_name_prefix}-stream"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "stream" {
  role = aws_iam_role.stream.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.storage.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.storage.bucket}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        Resource = [
          aws_kms_key.encryption.arn
        ],
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.region.amazonaws.com"
          },
          StringLike = {
            "kms:EncryptionContext:aws:s3:arn" : "arn:aws:s3:::${aws_s3_bucket.storage.bucket}/*"
          }
        }
      },
      {
        Effect = "Allow",
        Action = [
          "logs:PutLogEvents"
        ],
        Resource = [
          aws_cloudwatch_log_stream.destination_delivery.arn
        ]
      },
    ]
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_s3_bucket" "storage" {
  bucket = "${var.forwarder_name_prefix}-${random_string.suffix.result}"
}

resource "aws_s3_bucket_lifecycle_configuration" "cleanup" {
  bucket = aws_s3_bucket.storage.id

  rule {
    id     = "abort-incomplete-multipart-upload"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "delete-old-events"
    status = "Enabled"

    expiration {
      days = var.audit_trail_expiration_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.encryption.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - ENCRYPTION
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_kms_key" "encryption" {
  description             = "Spacelift audit log encryption key"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.kms_enable_key_rotation
}

resource "aws_kms_key_policy" "encryption" {
  key_id = aws_kms_key.encryption.id
  policy = data.aws_iam_policy_document.encryption.json
}

resource "aws_kms_alias" "encryption" {
  name          = "alias/${var.forwarder_name_prefix}-encryption"
  target_key_id = aws_kms_key.encryption.key_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ EVENT FORWARDER - ENCRYPTION - POLICY
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "encryption" {
  # enable IAM access
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.current_account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSpaceliftFowardingRole"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:${local.partition}:iam::*:role/${var.forwarder_name_prefix}*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.current_account_id]
    }
  }
}