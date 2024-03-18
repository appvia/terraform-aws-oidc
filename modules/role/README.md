# AWS IAM OIDC Trust Role

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_audiences"></a> [additional\_audiences](#input\_additional\_audiences) | Additional audiences to be allowed in the OIDC federation mapping | `list(string)` | `[]` | no |
| <a name="input_common_provider"></a> [common\_provider](#input\_common\_provider) | The name of a common OIDC provider to be used as the trust for the role | `string` | `""` | no |
| <a name="input_custom_provider"></a> [custom\_provider](#input\_custom\_provider) | An object representing an `aws_iam_openid_connect_provider` resource | <pre>object({<br>    url                    = string<br>    audiences              = list(string)<br>    subject_branch_mapping = string<br>    subject_tag_mapping    = string<br>  })</pre> | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the role being created | `string` | n/a | yes |
| <a name="input_force_detach_policies"></a> [force\_detach\_policies](#input\_force\_detach\_policies) | Flag to force detachment of policies attached to the IAM role. | `bool` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the role to create | `string` | n/a | yes |
| <a name="input_permission_boundary_arn"></a> [permission\_boundary\_arn](#input\_permission\_boundary\_arn) | The ARN of the policy that is used to set the permissions boundary for the IAM role | `string` | `null` | no |
| <a name="input_protected_branch"></a> [protected\_branch](#input\_protected\_branch) | The name of the protected branch under which the read-write role can be assumed | `string` | `"main"` | no |
| <a name="input_protected_tag"></a> [protected\_tag](#input\_protected\_tag) | The name of the protected tag under which the read-write role can be assume | `string` | `"*"` | no |
| <a name="input_read_only_inline_policies"></a> [read\_only\_inline\_policies](#input\_read\_only\_inline\_policies) | Inline policies map with policy name as key and json as value. | `map(string)` | `{}` | no |
| <a name="input_read_only_max_session_duration"></a> [read\_only\_max\_session\_duration](#input\_read\_only\_max\_session\_duration) | The maximum session duration (in seconds) that you want to set for the specified role | `number` | `null` | no |
| <a name="input_read_only_policy_arns"></a> [read\_only\_policy\_arns](#input\_read\_only\_policy\_arns) | List of IAM policy ARNs to attach to the read-only role | `list(string)` | `[]` | no |
| <a name="input_read_write_inline_policies"></a> [read\_write\_inline\_policies](#input\_read\_write\_inline\_policies) | Inline policies map with policy name as key and json as value. | `map(string)` | `{}` | no |
| <a name="input_read_write_max_session_duration"></a> [read\_write\_max\_session\_duration](#input\_read\_write\_max\_session\_duration) | The maximum session duration (in seconds) that you want to set for the specified role | `number` | `null` | no |
| <a name="input_read_write_policy_arns"></a> [read\_write\_policy\_arns](#input\_read\_write\_policy\_arns) | List of IAM policy ARNs to attach to the read-write role | `list(string)` | `[]` | no |
| <a name="input_repository"></a> [repository](#input\_repository) | List of repositories to be allowed i nthe OIDC federation mapping | `string` | n/a | yes |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | Path under which to create IAM role. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply resoures created by this module | `map(string)` | `{}` | no |
| <a name="input_unprotected_branch"></a> [unprotected\_branch](#input\_unprotected\_branch) | The name (or pattern) of non-protected branches under which the read-only role can be assumed | `string` | `"*"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_read_only"></a> [read\_only](#output\_read\_only) | n/a |
| <a name="output_read_write"></a> [read\_write](#output\_read\_write) | n/a |
