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

  # log archive buckets can store from cloudtrail logs, vpc flow logs, dns query logs, aws config logs and guardduty logs
  log_archive_buckets = [
    {
      bucket_name                   = "aws-c2-cloudtrail-archive"
      archive_type                  = "org_cloudtrail"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
    },
    {
      bucket_name                   = "aws-c2-vpc-flow-logs-archive"
      archive_type                  = "vpc_flow_logs"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
    },
    {
      bucket_name                   = "aws-c2-dns-query-logs-archive"
      archive_type                  = "dns_query_logs"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
    },
    {
      bucket_name                   = "aws-c2-guardduty-archive"
      archive_type                  = "guardduty"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
    },
    {
      bucket_name                   = "aws-c2-config-archive"
      archive_type                  = "aws_config"
      lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
      config_iam_path               = "/"
      config_iam_role_name          = "baseline-aws-config-role"
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC S3 LOG ARCHIVE
# ---------------------------------------------------------------------------------------------------------------------
module "log_archive" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=beta"

  log_archive_buckets = local.log_archive_buckets

  providers = {
    aws = aws.euc1
  }
}