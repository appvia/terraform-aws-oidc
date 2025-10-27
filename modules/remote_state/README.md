# AWS OIDC Remote State Reader

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID where the remote state bucket is located | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | The name of the repository to lookup remote state for | `string` | n/a | yes |
| <a name="input_reader_role"></a> [reader\_role](#input\_reader\_role) | The name of the reader role to assume in order to read the remote state | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region name where the destination resources have been created | `string` | `null` | no |
| <a name="input_web_identity_token_file"></a> [web\_identity\_token\_file](#input\_web\_identity\_token\_file) | Path to the web identity token file | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_key"></a> [bucket\_key](#output\_bucket\_key) | The key of the S3 bucket where the Terraform state is stored. |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | The name of the S3 bucket where the Terraform state is stored. |
| <a name="output_outputs"></a> [outputs](#output\_outputs) | The outputs from the terraform\_remote\_state data source. |
<!-- END_TF_DOCS -->
