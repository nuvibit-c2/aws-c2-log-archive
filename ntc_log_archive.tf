# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # lifecycle configuration rules to optimize storage cost of logs throughout their lifecycle
  default_lifecycle_configuration_rules = [
    {
      id      = "transition_to_glacier"
      enabled = true
      transition = {
        days          = 365
        storage_class = "GLACIER"
      }
    },
    {
      id      = "expire_logs"
      enabled = true
      expiration = {
        days = 730
      }
    }
  ]

  # s3 access logging bucket must be deployed first or terraform must run twice
  s3_access_logging_bucket_name = "aws-c2-access-logging"
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC S3 LOG ARCHIVE
# ---------------------------------------------------------------------------------------------------------------------
module "log_archive" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.1.1"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=feat-tgw-flow-logs"

  # log archive buckets to store s3 access logs, cloudtrail logs, vpc flow logs, dns query logs, aws config logs and guardduty logs
  log_archive_buckets = [
    {
      bucket_name                   = local.s3_access_logging_bucket_name
      archive_type                  = "s3_access_logging"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
      object_lock_enabled           = false
    },
    {
      bucket_name                       = "aws-c2-cloudtrail-archive"
      archive_type                      = "org_cloudtrail"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "org_cloudtrail/"
      # object_lock_enabled               = true
      # object_lock_configuration = {
      #   retention_mode = "COMPLIANCE"
      #   retention_days = 365
      # }
    },
    {
      bucket_name                       = "aws-c2-vpc-flow-logs-archive"
      archive_type                      = "vpc_flow_logs"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "vpc_flow_logs/"
    },
    {
      bucket_name                       = "aws-c2-transit-gateway-logs-archive"
      archive_type                      = "transit_gateway_flow_logs"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "transit_gateway_flow_logs/"
    },
    {
      bucket_name                       = "aws-c2-dns-query-logs-archive"
      archive_type                      = "dns_query_logs"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "dns_query_logs/"
    },
    {
      bucket_name                       = "aws-c2-guardduty-archive"
      archive_type                      = "guardduty"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "guardduty/"
    },
    {
      bucket_name                       = "aws-c2-config-archive"
      archive_type                      = "aws_config"
      lifecycle_configuration_rules     = local.default_lifecycle_configuration_rules
      config_iam_path                   = "/"
      config_iam_role_name              = "ntc-config-role"
      enable_access_logging             = true
      access_logging_target_bucket_name = local.s3_access_logging_bucket_name
      access_logging_target_prefix      = "aws_config/"
    }
  ]

  providers = {
    aws = aws.euc1
  }
}