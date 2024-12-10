# AWS OIDC Remote State Reader

## Requirements

| Name                                                                     | Version |
| ------------------------------------------------------------------------ | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.0  |

## Providers

| Name                                                               | Version |
| ------------------------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws)                   | 5.41.0  |
| <a name="provider_terraform"></a> [terraform](#provider_terraform) | n/a     |

## Modules

No modules.

## Resources

| Name                                                                                                                             | Type        |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)    | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                      | data source |
| [terraform_remote_state.this](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name                                                                                                   | Description                                                            | Type     | Default | Required |
| ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- | -------- | ------- | :------: |
| <a name="input_account_id"></a> [account_id](#input_account_id)                                        | Account ID where the remote state bucket is located                    | `string` | `null`  |    no    |
| <a name="input_reader_role_arn"></a> [reader_role_arn](#input_reader_role_arn)                         | The ARN of the reader role to assume in order to read the remote state | `string` | n/a     |   yes    |
| <a name="input_region"></a> [region](#input_region)                                                    | The region name where the destination resources have been created      | `string` | `null`  |    no    |
| <a name="input_repository"></a> [repository](#input_repository)                                        | The name of the repository to lookup remote state for                  | `string` | n/a     |   yes    |
| <a name="input_web_identity_token_file"></a> [web_identity_token_file](#input_web_identity_token_file) | Path to the web identity token file                                    | `string` | n/a     |   yes    |

## Outputs

| Name                                                     | Description |
| -------------------------------------------------------- | ----------- |
| <a name="output_outputs"></a> [outputs](#output_outputs) | n/a         |

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_reader_role_arn"></a> [reader\_role\_arn](#input\_reader\_role\_arn) | The ARN of the reader role to assume in order to read the remote state | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | The name of the repository to lookup remote state for | `string` | n/a | yes |
| <a name="input_web_identity_token_file"></a> [web\_identity\_token\_file](#input\_web\_identity\_token\_file) | Path to the web identity token file | `string` | n/a | yes |
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID where the remote state bucket is located | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | The region name where the destination resources have been created | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_outputs"></a> [outputs](#output\_outputs) | n/a |
<!-- END_TF_DOCS -->

