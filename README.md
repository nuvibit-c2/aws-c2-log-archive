<!-- BEGIN_TF_DOCS -->
## Requirements

The following requirements are needed by this module:

- terraform (>= 1.3.0)

- aws (~> 6.0)

## Providers

The following providers are used by this module:

- aws (~> 6.0)

## Modules

The following Modules are called:

### ntc\_log\_archive

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive

Version: feat-harden-bucket-policies

### ntc\_log\_archive\_access\_logging

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-log-archive

Version: feat-harden-bucket-policies

### ntc\_parameters\_reader

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader

Version: 1.1.4

### ntc\_parameters\_writer

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer

Version: 1.1.4

## Resources

The following resources are used by this module:

- [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) (data source)
- [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) (data source)

## Required Inputs

No required inputs.

## Optional Inputs

No optional inputs.

## Outputs

The following outputs are exported:

### account\_id

Description: The current account id

### default\_region

Description: The default region name

### ntc\_parameters

Description: Map of all ntc parameters
<!-- END_TF_DOCS -->