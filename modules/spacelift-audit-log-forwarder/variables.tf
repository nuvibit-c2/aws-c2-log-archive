variable "buffer_interval" {
  description = "Buffer incoming data for the specified period of time, in seconds, before delivering it to the destination"
  type        = number
  default     = 300
}

variable "buffer_size" {
  description = "Buffer incoming events to the specified size, in MBs, before delivering it to the destination"
  type        = number
  default     = 5
}

variable "logs_retention_days" {
  description = "Keep the logs for this number of days"
  type        = number
  default     = 14
}

variable "logs_verbose" {
  description = "Include debug information in the logs"
  type        = bool
  default     = false
}

variable "python_version" {
  description = "AWS Lambda Python runtime version"
  type        = string
  default     = "3.11"
}

variable "audit_trail_secret" {
  description = "Secret to be expected by the collector"
  type        = string
  default     = ""
}

variable "audit_trail_expiration_days" {
  default     = 365
  description = "Keep the audit trail for this number of days"
  type        = number
}

variable "forwarder_name_prefix" {
  description = "Prefix name of the Spacelift audit forwarder resources"
  default     = "spacelift-audit-log-forwarder"
  type        = string
}

variable "forwarding_endpoint" {
  description = "Set endpoint type for audit log forwarding. \"lambda_function_url\" is not supported in all regions and therefore \"api_gateway\" can be used as well."
  default     = "lambda_function_url"
  type        = string

  validation {
    condition     = contains(["lambda_function_url", "api_gateway"], var.forwarding_endpoint)
    error_message = "Value for \"forwarding_endpoint\" must be \"lambda_function_url\" or \"api_gateway\"."
  }
}

variable "kms_deletion_window_in_days" {
  description = "The waiting period, specified in number of days. After the waiting period ends, AWS KMS deletes the KMS key."
  type        = number
  default     = 7
}

variable "kms_enable_key_rotation" {
  description = "Specifies whether key rotation is enabled. Defaults to true."
  type        = bool
  default     = true
}