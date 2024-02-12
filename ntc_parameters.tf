locals {
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"
  ntc_parameters_writer_node = "log-archive"

  # parameters that are managed by core log archive account
  ntc_parameters_to_write = {
    log_bucket_arns : module.log_archive.log_archive_bucket_arns
    log_bucket_ids : module.log_archive.log_archive_bucket_ids
    log_bucket_kms_key_arns : module.log_archive.log_archive_kms_key_arns
  }

  # by default existing node parameters will be merged with new parameters to avoid deleting parameters
  ntc_replace_parameters = true

  # map of parameters merged from all parameter nodes
  ntc_parameters = module.ntc_parameters_reader.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.1"

  bucket_name = local.ntc_parameters_bucket_name

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - WRITER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_writer" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.1.0"

  bucket_name        = local.ntc_parameters_bucket_name
  parameter_node     = local.ntc_parameters_writer_node
  node_parameters    = local.ntc_parameters_to_write
  replace_parameters = local.ntc_replace_parameters

  providers = {
    aws = aws.euc1
  }
}
