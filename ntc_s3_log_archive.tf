# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  log_archive_buckets = [
    {
      bucket_name  = "aws-c2-cloudtrail-archive"
      archive_type = "org_cloudtrail"
      lifecycle_configuration_rules = [
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
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC S3 LOG ARCHIVE
# ---------------------------------------------------------------------------------------------------------------------
module "log_archive" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-s3?ref=beta"

  log_archive_buckets = local.log_archive_buckets

  providers = {
    aws = aws.euc1
  }
}