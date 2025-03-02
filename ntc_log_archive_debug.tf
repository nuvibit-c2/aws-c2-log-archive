
variable "lifecycle_configuration_rules" {
  description = "A list of lifecycle rules."
  type = list(object({
    enabled                                = optional(bool, true)
    id                                     = string
    abort_incomplete_multipart_upload_days = optional(number, null)
    filter = optional(
      object({
        object_size_greater_than = optional(number, null)
        object_size_less_than    = optional(number, null)
        prefix                   = optional(string, null)
        tag = optional(
          object({
            key   = string
            value = string
          }), null
        )
      }), {}
    )
    filter_and = optional(
      object({
        object_size_greater_than = optional(number, null)
        object_size_less_than    = optional(number, null)
        prefix                   = optional(string, null)
        tags                     = optional(map(string), null)
      }), {}
    )
    expiration = optional(
      object({
        date                         = optional(string, null)
        days                         = optional(number, null)
        expired_object_delete_marker = optional(bool, null)
      }), {}
    )
    transition = optional(
      object({
        date          = optional(string, null)
        days          = optional(number, null)
        storage_class = optional(string, null)
      }), {}
    )
    noncurrent_version_expiration = optional(
      object({
        newer_noncurrent_versions = optional(number, null)
        noncurrent_days           = optional(number, null)
      }), {}
    )
    noncurrent_version_transition = optional(
      object({
        newer_noncurrent_versions = optional(number, null)
        noncurrent_days           = optional(number, null)
        storage_class             = optional(string, null)
      }), {}
    )
  }))
  default = [
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

variable "expected_bucket_owner" {
  description = "The account ID of the expected bucket owner."
  type        = string
  default     = null
}

resource "aws_s3_bucket_lifecycle_configuration" "ntc_bucket" {
  bucket                = "aws-c2-vpc-flow-logs-archive"
  expected_bucket_owner = var.expected_bucket_owner

  dynamic "rule" {
    for_each = var.lifecycle_configuration_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled == true ? "Enabled" : "Disabled"

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [true] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }

      dynamic "expiration" {
        for_each = length([for v in values(rule.value.expiration) : v if v != null]) > 0 ? [true] : []

        content {
          date                         = rule.value.expiration.date
          days                         = rule.value.expiration.days
          expired_object_delete_marker = rule.value.expiration.expired_object_delete_marker
        }
      }

      dynamic "transition" {
        for_each = length([for v in values(rule.value.transition) : v if v != null]) > 0 ? [true] : []

        content {
          date          = rule.value.transition.date
          days          = rule.value.transition.days
          storage_class = rule.value.transition.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = length([for v in values(rule.value.noncurrent_version_expiration) : v if v != null]) > 0 ? [true] : []

        content {
          newer_noncurrent_versions = rule.value.noncurrent_version_expiration.newer_noncurrent_versions
          noncurrent_days           = rule.value.noncurrent_version_expiration.noncurrent_days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = length([for v in values(rule.value.noncurrent_version_transition) : v if v != null]) > 0 ? [true] : []

        content {
          newer_noncurrent_versions = rule.value.noncurrent_version_transition.newer_noncurrent_versions
          noncurrent_days           = rule.value.noncurrent_version_transition.noncurrent_days
          storage_class             = rule.value.noncurrent_version_transition.storage_class
        }
      }

      dynamic "filter" {
        for_each = length([for v in values(rule.value.filter) : v if v != null]) == 0 && length([for v in values(rule.value.filter_and) : v if v != null]) == 0 ? [true] : []

        content {}
      }

      dynamic "filter" {
        for_each = length([for v in values(rule.value.filter) : v if v != null]) > 0 ? [true] : []

        content {
          object_size_greater_than = rule.value.filter.object_size_greater_than
          object_size_less_than    = rule.value.filter.object_size_less_than
          prefix                   = rule.value.filter.prefix

          dynamic "tag" {
            for_each = length(keys(rule.value.filter.tag)) > 0 ? [true] : []

            content {
              key   = tag.value.key
              value = tag.value.value
            }
          }
        }
      }

      dynamic "filter" {
        for_each = length([for v in values(rule.value.filter_and) : v if v != null]) > 0 ? [true] : []

        content {
          and {
            object_size_greater_than = rule.value.filter.object_size_greater_than
            object_size_less_than    = rule.value.filter.object_size_less_than
            prefix                   = rule.value.filter.prefix
            tags                     = rule.value.filter.tags
          }
        }
      }
    }
  }
}