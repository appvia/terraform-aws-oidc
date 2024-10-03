# AWS IAM OIDC Trust Role

## Description

This module creates an two IAM roles with trust relationships to an OIDC provider. One role is read-only and the other is read-write. The read-only role is intended to be used by CI/CD pipelines to validate pull requests and changes, where as the read-write role applies the changes on the merge to main. In all cases the consumer must pass a IAM boundary policy to ensure that the roles are not able to escalate their permissions, or make changes to critical resources.

## Update Documentation

The `terraform-docs` utility is used to generate this README. Follow the below steps to update:

1. Make changes to the `.terraform-docs.yml` file
2. Fetch the `terraform-docs` binary (https://terraform-docs.io/user-guide/installation/)
3. Run `terraform-docs markdown table --output-file ${PWD}/README.md --output-mode inject .`

## Requirements

| Name                                                                     | Version |
| ------------------------------------------------------------------------ | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.0  |

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | n/a     |

## Modules

No modules.

## Resources

| Name                                                                                                                                                    | Type        |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_iam_policy.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                                  | resource    |
| [aws_iam_policy.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                                   | resource    |
| [aws_iam_policy.tfstate_remote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy)                                 | resource    |
| [aws_iam_role.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                 | resource    |
| [aws_iam_role.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                 | resource    |
| [aws_iam_role.sr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                 | resource    |
| [aws_iam_role_policy_attachment.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)             | resource    |
| [aws_iam_role_policy_attachment.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)             | resource    |
| [aws_iam_role_policy_attachment.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)  | resource    |
| [aws_iam_role_policy_attachment.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)   | resource    |
| [aws_iam_role_policy_attachment.tfstate_remote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource    |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                           | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider)      | data source |
| [aws_iam_policy_document.base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                      | data source |
| [aws_iam_policy_document.dynamo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                    | data source |
| [aws_iam_policy_document.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                        | data source |
| [aws_iam_policy_document.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                        | data source |
| [aws_iam_policy_document.sr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                        | data source |
| [aws_iam_policy_document.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)             | data source |
| [aws_iam_policy_document.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)              | data source |
| [aws_iam_policy_document.tfstate_remote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)            | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                             | data source |

## Inputs

| Name                                                                                                                           | Description                                                                           | Type                                                                                                                                                                              | Default  | Required |
| ------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | :------: |
| <a name="input_additional_audiences"></a> [additional_audiences](#input_additional_audiences)                                  | Additional audiences to be allowed in the OIDC federation mapping                     | `list(string)`                                                                                                                                                                    | `[]`     |    no    |
| <a name="input_common_provider"></a> [common_provider](#input_common_provider)                                                 | The name of a common OIDC provider to be used as the trust for the role               | `string`                                                                                                                                                                          | `""`     |    no    |
| <a name="input_custom_provider"></a> [custom_provider](#input_custom_provider)                                                 | An object representing an `aws_iam_openid_connect_provider` resource                  | <pre>object({<br> url = string<br> audiences = list(string)<br> subject_reader_mapping = string<br> subject_branch_mapping = string<br> subject_tag_mapping = string<br> })</pre> | `null`   |    no    |
| <a name="input_description"></a> [description](#input_description)                                                             | Description of the role being created                                                 | `string`                                                                                                                                                                          | n/a      |   yes    |
| <a name="input_force_detach_policies"></a> [force_detach_policies](#input_force_detach_policies)                               | Flag to force detachment of policies attached to the IAM role.                        | `bool`                                                                                                                                                                            | `null`   |    no    |
| <a name="input_name"></a> [name](#input_name)                                                                                  | Name of the role to create                                                            | `string`                                                                                                                                                                          | n/a      |   yes    |
| <a name="input_permission_boundary_arn"></a> [permission_boundary_arn](#input_permission_boundary_arn)                         | The ARN of the policy that is used to set the permissions boundary for the IAM role   | `string`                                                                                                                                                                          | `null`   |    no    |
| <a name="input_protected_branch"></a> [protected_branch](#input_protected_branch)                                              | The name of the protected branch under which the read-write role can be assumed       | `string`                                                                                                                                                                          | `"main"` |    no    |
| <a name="input_protected_tag"></a> [protected_tag](#input_protected_tag)                                                       | The name of the protected tag under which the read-write role can be assume           | `string`                                                                                                                                                                          | `"*"`    |    no    |
| <a name="input_read_only_inline_policies"></a> [read_only_inline_policies](#input_read_only_inline_policies)                   | Inline policies map with policy name as key and json as value.                        | `map(string)`                                                                                                                                                                     | `{}`     |    no    |
| <a name="input_read_only_max_session_duration"></a> [read_only_max_session_duration](#input_read_only_max_session_duration)    | The maximum session duration (in seconds) that you want to set for the specified role | `number`                                                                                                                                                                          | `null`   |    no    |
| <a name="input_read_only_policy_arns"></a> [read_only_policy_arns](#input_read_only_policy_arns)                               | List of IAM policy ARNs to attach to the read-only role                               | `list(string)`                                                                                                                                                                    | `[]`     |    no    |
| <a name="input_read_write_inline_policies"></a> [read_write_inline_policies](#input_read_write_inline_policies)                | Inline policies map with policy name as key and json as value.                        | `map(string)`                                                                                                                                                                     | `{}`     |    no    |
| <a name="input_read_write_max_session_duration"></a> [read_write_max_session_duration](#input_read_write_max_session_duration) | The maximum session duration (in seconds) that you want to set for the specified role | `number`                                                                                                                                                                          | `null`   |    no    |
| <a name="input_read_write_policy_arns"></a> [read_write_policy_arns](#input_read_write_policy_arns)                            | List of IAM policy ARNs to attach to the read-write role                              | `list(string)`                                                                                                                                                                    | `[]`     |    no    |
| <a name="input_repository"></a> [repository](#input_repository)                                                                | List of repositories to be allowed i nthe OIDC federation mapping                     | `string`                                                                                                                                                                          | n/a      |   yes    |
| <a name="input_role_path"></a> [role_path](#input_role_path)                                                                   | Path under which to create IAM role.                                                  | `string`                                                                                                                                                                          | `null`   |    no    |
| <a name="input_shared_repositories"></a> [shared_repositories](#input_shared_repositories)                                     | List of repositories to provide read access to the remote state                       | `list(string)`                                                                                                                                                                    | `[]`     |    no    |
| <a name="input_tags"></a> [tags](#input_tags)                                                                                  | Tags to apply resoures created by this module                                         | `map(string)`                                                                                                                                                                     | `{}`     |    no    |

## Outputs

| Name                                                                    | Description |
| ----------------------------------------------------------------------- | ----------- |
| <a name="output_read_only"></a> [read_only](#output_read_only)          | n/a         |
| <a name="output_read_write"></a> [read_write](#output_read_write)       | n/a         |
| <a name="output_state_reader"></a> [state_reader](#output_state_reader) | n/a         |

<!-- BEGIN_TF_DOCS -->
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
| [aws_iam_role.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.base](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dynamo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ro](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.rw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfstate_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfstate_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.tfstate_remote](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Description of the role being created | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the role to create | `string` | n/a | yes |
| <a name="input_repository"></a> [repository](#input\_repository) | List of repositories to be allowed in the OIDC federation mapping | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply resoures created by this module | `map(string)` | n/a | yes |
| <a name="input_additional_audiences"></a> [additional\_audiences](#input\_additional\_audiences) | Additional audiences to be allowed in the OIDC federation mapping | `list(string)` | `[]` | no |
| <a name="input_common_provider"></a> [common\_provider](#input\_common\_provider) | The name of a common OIDC provider to be used as the trust for the role | `string` | `"github"` | no |
| <a name="input_custom_provider"></a> [custom\_provider](#input\_custom\_provider) | An object representing an `aws_iam_openid_connect_provider` resource | <pre>object({<br/>    url                    = string<br/>    audiences              = list(string)<br/>    subject_reader_mapping = string<br/>    subject_branch_mapping = string<br/>    subject_env_mapping    = string<br/>    subject_tag_mapping    = string<br/>  })</pre> | `null` | no |
| <a name="input_default_inline_policies"></a> [default\_inline\_policies](#input\_default\_inline\_policies) | Inline policies map with policy name as key and json as value, attached to both read-only and read-write roles | `map(string)` | `{}` | no |
| <a name="input_default_managed_policies"></a> [default\_managed\_policies](#input\_default\_managed\_policies) | List of IAM managed policy ARNs to attach to this role/s, both read-only and read-write | `list(string)` | `[]` | no |
| <a name="input_force_detach_policies"></a> [force\_detach\_policies](#input\_force\_detach\_policies) | Flag to force detachment of policies attached to the IAM role. | `bool` | `null` | no |
| <a name="input_permission_boundary"></a> [permission\_boundary](#input\_permission\_boundary) | The name of the policy that is used to set the permissions boundary for the IAM role | `string` | `null` | no |
| <a name="input_permission_boundary_arn"></a> [permission\_boundary\_arn](#input\_permission\_boundary\_arn) | The full ARN of the permission boundary to attach to the role | `string` | `null` | no |
| <a name="input_protected_by"></a> [protected\_by](#input\_protected\_by) | The branch, environment and/or tag to protect the role against | <pre>object({<br/>    branch      = optional(string)<br/>    environment = optional(string)<br/>    tag         = optional(string)<br/>  })</pre> | <pre>{<br/>  "branch": "main",<br/>  "environment": "production",<br/>  "tag": "*"<br/>}</pre> | no |
| <a name="input_read_only_inline_policies"></a> [read\_only\_inline\_policies](#input\_read\_only\_inline\_policies) | Inline policies map with policy name as key and json as value. | `map(string)` | `{}` | no |
| <a name="input_read_only_max_session_duration"></a> [read\_only\_max\_session\_duration](#input\_read\_only\_max\_session\_duration) | The maximum session duration (in seconds) that you want to set for the specified role | `number` | `null` | no |
| <a name="input_read_only_policy_arns"></a> [read\_only\_policy\_arns](#input\_read\_only\_policy\_arns) | List of IAM policy ARNs to attach to the read-only role | `list(string)` | `[]` | no |
| <a name="input_read_write_inline_policies"></a> [read\_write\_inline\_policies](#input\_read\_write\_inline\_policies) | Inline policies map with policy name as key and json as value. | `map(string)` | `{}` | no |
| <a name="input_read_write_max_session_duration"></a> [read\_write\_max\_session\_duration](#input\_read\_write\_max\_session\_duration) | The maximum session duration (in seconds) that you want to set for the specified role | `number` | `null` | no |
| <a name="input_read_write_policy_arns"></a> [read\_write\_policy\_arns](#input\_read\_write\_policy\_arns) | List of IAM policy ARNs to attach to the read-write role | `list(string)` | `[]` | no |
| <a name="input_region"></a> [region](#input\_region) | The region in which the role will be used (defaulting to the provider region) | `string` | `null` | no |
| <a name="input_repository_uuid"></a> [repository\_uuid](#input\_repository\_uuid) | Repository UUID. You can get it in the repository settings in the OpenID connect provider. | `string` | `null` | no |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | Path under which to create IAM role. | `string` | `null` | no |
| <a name="input_shared_repositories"></a> [shared\_repositories](#input\_shared\_repositories) | List of repositories to provide read access to the remote state | `list(string)` | `[]` | no |
| <a name="input_tf_state_suffix"></a> [tf\_state\_suffix](#input\_tf\_state\_suffix) | A suffix for the terraform statefile, e.g. <repo>-<tf\_state\_suffix>.tfstate | `string` | `""` | no |
| <a name="input_workspace_name"></a> [workspace\_name](#input\_workspace\_name) | The name of the workspace. | `string` | `null` | no |
| <a name="input_workspace_uuid"></a> [workspace\_uuid](#input\_workspace\_uuid) | Workspace UUID. You can get it in the repository settings in the OpenID connect provider. Don't include the brackets and make sure it is lower cased. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_read_only"></a> [read\_only](#output\_read\_only) | n/a |
| <a name="output_read_write"></a> [read\_write](#output\_read\_write) | n/a |
| <a name="output_state_reader"></a> [state\_reader](#output\_state\_reader) | n/a |
<!-- END_TF_DOCS -->