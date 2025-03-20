# AWS OIDC Remote State Reader

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.87.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [terraform_remote_state.this](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID where the remote state bucket is located | `string` | n/a | yes |
| <a name="input_reader_role"></a> [reader\_role](#input\_reader\_role) | The name of the reader role to assume in order to read the remote state | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region name where the destination resources have been created | `string` | `null` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | The name of the repository to lookup remote state for | `string` | n/a | yes |
| <a name="input_web_identity_token_file"></a> [web\_identity\_token\_file](#input\_web\_identity\_token\_file) | Path to the web identity token file | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_key"></a> [bucket\_key](#output\_bucket\_key) | The key of the S3 bucket where the Terraform state is stored. |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | The name of the S3 bucket where the Terraform state is stored. |
| <a name="output_outputs"></a> [outputs](#output\_outputs) | The outputs from the terraform\_remote\_state data source. |
<!-- END_TF_DOCS -->
