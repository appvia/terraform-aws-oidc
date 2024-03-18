# AWS IAM OIDC Provider

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_openid_connect_provider.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [tls_certificate.thumbprint](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_providers"></a> [common\_providers](#input\_common\_providers) | List of common well-known providers to enable, such as github, gitlab | `list(string)` | `[]` | no |
| <a name="input_custom_providers"></a> [custom\_providers](#input\_custom\_providers) | Map of custom provider configurations | <pre>map(object({<br>    name              = optional(string, null)<br>    url               = string<br>    client_id_list    = list(string)<br>    thumbprint_list   = optional(list(string), [])<br>    lookup_thumbprint = optional(bool, true)<br>  }))</pre> | `{}` | no |
| <a name="input_provider_tags"></a> [provider\_tags](#input\_provider\_tags) | Nested map of tags to apply to specific providers. Top level keys should match provider names | `map(map(string))` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_providers"></a> [providers](#output\_providers) | n/a |
