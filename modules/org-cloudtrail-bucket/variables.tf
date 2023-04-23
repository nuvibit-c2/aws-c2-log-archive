variable "cloudtrail_admin_account_id" {
  type = string
  description = "Account ID of Organization Management Account or the delegated CloudTrail Admin Account where the Organization CloudTrail will be deployed"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.org_mgmt_account_id))
    error_message = "\"org_mgmt_account_id\" needs to be a valid Account ID: 12 digit number."
  }
}

variable "org_cloudtrail_name" {
  type = string
  description = "Name of the Organization CloudTrail that will be deployed"
  default = "org_cloudtrail"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([0-9A-Za-z]|\\._-](?![\\._-])){1,126}[a-zA-Z0-9]$", var.org_mgmt_account_id))
    error_message = <<EOT
    \"org_cloudtrail_name\" needs to be a valid cloutrail name:
    - Contain only ASCII letters (a-z, A-Z), numbers (0-9), periods (.), underscores (_), or dashes (-)
    - Start with a letter or number, and end with a letter or number
    - Be between 3 and 128 characters
    - Have no adjacent periods, underscores or dashes. Names like my-_cloudtrail and my--cloudtrail are not valid.
    EOT
  }
}

variable "org_cloudtrail_region" {
  type = string
  description = "Region where the Organization CloudTrail will be deployed"

  validation {
    condition = can(regex("(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\d"), var.org_cloudtrail_region)
    error_message = "\"org_cloudtrail_region\" needs to be a valid region code (eu-central-1, us-east-1, etc)."
  }
}

variable "org_cloudtrail_bucket_kms_alias" {
  type = string
  description = "Alias for ClouTrail bucket KMS key alias"

  validation  {
    condition = can (regex("^[a-zA-Z0-9\\/_-]{1,250}$"))
    error_message = "\"org_cloudtrail_bucket_kms_alias\" must only contain ASCII letters (a-z, A-Z), numbers (0-9), slashes (/), underscores (_), or dashes (-)"
  }
}

