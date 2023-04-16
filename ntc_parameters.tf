locals {
  # map of parameters merged from all parameter nodes
  ntc_parameters = module.ntc_parameters_reader.parameter_map

  # parameters that are managed by core log archive account
  ntc_parameters_log_archive = {
    bucket_arns : {
      cloudtrail : ""
      config : ""
      guardduty : ""
      security_hub : ""
      flow_logs : ""
      dns_logs : ""
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=beta"

  bucket_name = "aws-c2-ntc-parameters"
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - WRITER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_writer" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=beta"

  bucket_name     = "aws-c2-ntc-parameters"
  parameter_node  = "log-archive"
  node_parameters = local.ntc_parameters_log_archive
}
