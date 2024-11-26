# ---------------------------------------------------------------------------------------------------------------------
# ¦ SPACELIFT AUDIT LOG FORWARDER - FRANKFURT
# ---------------------------------------------------------------------------------------------------------------------
module "spacelift_audit_log_forwarder_euc1" {
  source = "./modules/spacelift-audit-log-forwarder"

  forwarder_name_prefix = "spacelift-audit-log-forwarder-euc1"
  forwarding_endpoint   = "lambda_function_url"
  audit_trail_secret    = "1k2l3hjrkjh12lkjasd"

  providers = {
    aws = aws.euc1
  }
}

output "spacelift_audit_log_forwarder_euc1" {
  description = "Outputs of spacelift audit log forwarder module"
  value       = module.spacelift_audit_log_forwarder_euc1
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ SPACELIFT AUDIT LOG FORWARDER - ZURICH
# ---------------------------------------------------------------------------------------------------------------------
module "spacelift_audit_log_forwarder_euc2" {
  source = "./modules/spacelift-audit-log-forwarder"

  forwarder_name_prefix = "spacelift-audit-log-forwarder-euc2"
  forwarding_endpoint   = "lambda_function_url"
  audit_trail_secret    = "1k2l3hjrkjh12lkjasd"

  providers = {
    aws = aws.euc2
  }
}

output "spacelift_audit_log_forwarder_euc2" {
  description = "Outputs of spacelift audit log forwarder module"
  value       = module.spacelift_audit_log_forwarder_euc2
}
