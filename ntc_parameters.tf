locals {
  ntc_parameters = module.ntc_parameters_reader.parameter_map
  # parameters that are managed by log-archive account
  ntc_parameters_log_archive = {
    "log_archive_module" : { 
      "input1" : "value1", 
      "input2" : ["value2"], 
      "input3" : 3 
    },
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CORE PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit/terraform-aws-ntc-parameters//modules/reader?ref=beta"

  bucket_name = "ntc-parameters-c2"
}

# # ---------------------------------------------------------------------------------------------------------------------
# # ¦ CORE PARAMETERS - WRITER
# # ---------------------------------------------------------------------------------------------------------------------
# module "ntc_parameters_writer" {
#   source = "github.com/nuvibit/terraform-aws-ntc-parameters//modules/writer?ref=beta"

#   bucket_name     = "ntc-parameters-c2"
#   parameter_node  = "log-archive"
#   node_parameters = local.ntc_parameters_log_archive
# }
