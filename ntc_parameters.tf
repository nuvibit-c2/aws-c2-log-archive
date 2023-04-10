locals {
  ntc_parameters = module.ntc_parameters_reader.parameter_map
  ntc_parameters_log_archive = {
    # this node contains module parameters which are provisioned in core_log_archive account
    "log_archive" : { "input1" : "value1", "input2" : ["value2"], "input3" : 3 },
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CORE PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit/terraform-aws-ntc-parameters//modules/reader?ref=feat-init"

  bucket_name = "ntc-parameters-c2"
}

# # ---------------------------------------------------------------------------------------------------------------------
# # ¦ CORE PARAMETERS - WRITER
# # ---------------------------------------------------------------------------------------------------------------------
# module "ntc_parameters_writer" {
#   source = "github.com/nuvibit/terraform-aws-ntc-parameters//modules/writer?ref=feat-init"

#   bucket_name     = "ntc-parameters-c2"
#   parameter_node  = "connectivity"
#   node_parameters = local.ntc_parameters_connectivity
# }
