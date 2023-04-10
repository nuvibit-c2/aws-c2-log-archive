output "region" {
  description = "The current region name"
  value       = data.aws_region.current.name
}

output "account_id" {
  description = "The current account id"
  value       = data.aws_caller_identity.current.account_id
}

output "ntc_parameters" {
  description = "Map of all ntc core parameters"
  value       = local.ntc_parameters
}