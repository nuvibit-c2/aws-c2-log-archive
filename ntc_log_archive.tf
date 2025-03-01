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

# variable "lifecycle_configuration_rules" {
#   description = "A list of lifecycle rules."
#   type = list(object({
#     enabled                                = optional(bool, true)
#     id                                     = string
#     abort_incomplete_multipart_upload_days = optional(number, null)
#     filter = optional(
#       object({
#         object_size_greater_than = optional(number, null)
#         object_size_less_than    = optional(number, null)
#         prefix                   = optional(string, null)
#         tag = optional(
#           object({
#             key   = string
#             value = string
#           }), null
#         )
#       }), {}
#     )
#     filter_and = optional(
#       object({
#         object_size_greater_than = optional(number, null)
#         object_size_less_than    = optional(number, null)
#         prefix                   = optional(string, null)
#         tags                     = optional(map(string), null)
#       }), {}
#     )
#     expiration = optional(
#       object({
#         date                         = optional(string, null)
#         days                         = optional(number, null)
#         expired_object_delete_marker = optional(bool, null)
#       }), {}
#     )
#     transition = optional(
#       object({
#         date          = optional(string, null)
#         days          = optional(number, null)
#         storage_class = optional(string, null)
#       }), {}
#     )
#     noncurrent_version_expiration = optional(
#       object({
#         newer_noncurrent_versions = optional(number, null)
#         noncurrent_days           = optional(number, null)
#       }), {}
#     )
#     noncurrent_version_transition = optional(
#       object({
#         newer_noncurrent_versions = optional(number, null)
#         noncurrent_days           = optional(number, null)
#         storage_class             = optional(string, null)
#       }), {}
#     )
#   }))
#   default = [
#     {
#       id      = "expire_logs"
#       enabled = true
#       expiration = {
#         days = 730
#       }
#     }
#   ]
# }

# variable "expected_bucket_owner" {
#   description = "The account ID of the expected bucket owner."
#   type        = string
#   default     = null
# }

# # DEBUG
# resource "aws_s3_bucket_lifecycle_configuration" "ntc_bucket" {
#   count = length(var.lifecycle_configuration_rules) > 0 ? 1 : 0

#   bucket                = "aws-c2-dns-query-logs-archive"
#   expected_bucket_owner = var.expected_bucket_owner

#   dynamic "rule" {
#     for_each = var.lifecycle_configuration_rules

#     content {
#       id     = rule.value.id
#       status = rule.value.enabled == true ? "Enabled" : "Disabled"

#       dynamic "filter" {
#         for_each = length([for v in values(rule.value.filter) : v if v != null]) == 0 && length([for v in values(rule.value.filter_and) : v if v != null]) == 0 ? [true] : []

#         content {}
#       }

#       dynamic "filter" {
#         for_each = length([for v in values(rule.value.filter) : v if v != null]) > 0 ? [true] : []

#         content {
#           object_size_greater_than = rule.value.filter.object_size_greater_than
#           object_size_less_than    = rule.value.filter.object_size_less_than
#           prefix                   = rule.value.filter.prefix

#           dynamic "tag" {
#             for_each = length(keys(rule.value.filter.tag)) > 0 ? [true] : []

#             content {
#               key   = tag.value.key
#               value = tag.value.value
#             }
#           }
#         }
#       }

#       dynamic "filter" {
#         for_each = length([for v in values(rule.value.filter_and) : v if v != null]) > 0 ? [true] : []

#         content {
#           and {
#             object_size_greater_than = rule.value.filter.object_size_greater_than
#             object_size_less_than    = rule.value.filter.object_size_less_than
#             prefix                   = rule.value.filter.prefix
#             tags                     = rule.value.filter.tags
#           }
#         }
#       }

#       dynamic "abort_incomplete_multipart_upload" {
#         for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [true] : []

#         content {
#           days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
#         }
#       }

#       dynamic "expiration" {
#         for_each = length([for v in values(rule.value.expiration) : v if v != null]) > 0 ? [true] : []

#         content {
#           date                         = rule.value.expiration.date
#           days                         = rule.value.expiration.days
#           expired_object_delete_marker = rule.value.expiration.expired_object_delete_marker
#         }
#       }

#       dynamic "transition" {
#         for_each = length([for v in values(rule.value.transition) : v if v != null]) > 0 ? [true] : []

#         content {
#           date          = rule.value.transition.date
#           days          = rule.value.transition.days
#           storage_class = rule.value.transition.storage_class
#         }
#       }

#       dynamic "noncurrent_version_expiration" {
#         for_each = length([for v in values(rule.value.noncurrent_version_expiration) : v if v != null]) > 0 ? [true] : []

#         content {
#           newer_noncurrent_versions = rule.value.noncurrent_version_expiration.newer_noncurrent_versions
#           noncurrent_days           = rule.value.noncurrent_version_expiration.noncurrent_days
#         }
#       }

#       dynamic "noncurrent_version_transition" {
#         for_each = length([for v in values(rule.value.noncurrent_version_transition) : v if v != null]) > 0 ? [true] : []

#         content {
#           newer_noncurrent_versions = rule.value.noncurrent_version_transition.newer_noncurrent_versions
#           noncurrent_days           = rule.value.noncurrent_version_transition.noncurrent_days
#           storage_class             = rule.value.noncurrent_version_transition.storage_class
#         }
#       }
#     }
#   }
# }

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC S3 LOG ARCHIVE
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_log_archive" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.2.0"

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

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC S3 LOG ARCHIVE - EXCEPTION
# ---------------------------------------------------------------------------------------------------------------------
# WARNING: guardduty log archive cannot be provisioned in opt-in region (e.g. zurich) - you can split log archive across 2 regions

# module "ntc_log_archive_exception" {
#   source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive?ref=1.2.0"

#   # guardduty cannot export findings from a default region to an opt-in region (e.g. from frankfurt to zurich)
#   # hence, all guardduty findings are exported to eu-central-1
#   log_archive_buckets = [
#     {
#       bucket_name                   = "nivel-guardduty-archive"
#       archive_type                  = "guardduty"
#       lifecycle_configuration_rules = local.default_lifecycle_configuration_rules
#       enable_access_logging         = false # cross-region access logging is not possible
#       object_lock_enabled           = false
#     }
#   ]

#   providers = {
#     aws = aws.euc1
#   }
# }
