<!-- markdownlint-disable -->
<a href="https://www.appvia.io/"><img src="https://github.com/appvia/terraform-aws-oidc/blob/main/appvia_banner.jpg?raw=true" alt="Appvia Banner"/></a><br/><p align="right"> <a href="https://registry.terraform.io/modules/appvia/oidc/aws/latest"><img src="https://img.shields.io/static/v1?label=APPVIA&message=Terraform%20Registry&color=191970&style=for-the-badge" alt="Terraform Registry"/></a></a> <a href="https://github.com/appvia/terraform-aws-oidc/releases/latest"><img src="https://img.shields.io/github/release/appvia/terraform-aws-oidc.svg?style=for-the-badge&color=006400" alt="Latest Release"/></a> <a href="https://appvia-community.slack.com/join/shared_invite/zt-1s7i7xy85-T155drryqU56emm09ojMVA#/shared-invite/email"><img src="https://img.shields.io/badge/Slack-Join%20Community-purple?style=for-the-badge&logo=slack" alt="Slack Community"/></a> <a href="https://github.com/appvia/terraform-aws-oidc/graphs/contributors"><img src="https://img.shields.io/github/contributors/appvia/terraform-aws-oidc.svg?style=for-the-badge&color=FF8C00" alt="Contributors"/></a>

<!-- markdownlint-restore -->
<!--
  ***** CAUTION: DO NOT EDIT ABOVE THIS LINE ******
-->

![Github Actions](https://github.com/appvia/terraform-aws-oidc/actions/workflows/terraform.yml/badge.svg)

# Terraform IAM OIDC Integration

## Overview

This module provides two child modules to simplify integrating AWS IAM Roles with OpenID Connect identity provider trusts.
The [Provider module](modules/provider) is responsible for creating an OpenID Connect provider in IAM, whilst the [Role module](modules/role)
is responsible for creating AWS IAM Roles with a trust relationship to the AWS IAM OIDC Provider.

## Examples

### OIDC Identity Provider

```hcl
module "common_provider_example" {
  source  = "appvia/oidc/aws//modules/provider"
  version = "0.0.16"

  // List of common OIDC providers to enable
  common_providers = [
    "github",
    "gitlab",
  ]

  // Per-provider tags to apply to the OIDC provider
  provider_tags = {
    github = {
      Provider = "GitHub Only Tag"
    }

    gitlab = {
      Provider = "GitLab Only Tag"
    }
  }

  // Tags to apply to all providers
  tags = {
    Name = "Example Common Provider"
  }
}

module "custom_provider_example" {
  source  = "appvia/oidc/aws//modules/provider"
  version = "0.0.16"

  // Custom provider configuration
  custom_providers = {
    gitlab = {
      // Friendly name of the provider
      name = "GitLab"

      // Root URL of the OpenID Connect identity provider
      url = "https://gitlab.example.org"

      // Client ID (audience)
      client_id_list = [
        "https://gitlab.example.org",
      ]

      // List of certificate thumbprints for the provider.
      // If these are not specified, the module will attempt
      // to look up the current thumbprint automatically.
      thumbprint_list = [
        "92bed42098f508e91f47f321f6607e4b",
      ]
    }
  }

  // Tags to provide to all providers
  tags = {
    Name = "Example Custom Provider"
  }
}
```

### OIDC Trusted Role

```hcl
module "common_provider_example" {
  source  = "appvia/oidc/aws//modules/role"
  version = "0.0.16"

  // Basic role details
  name        = "test-common-role"
  description = "Creates a role using the GitHub OIDC provider"

  // Name of the common OIDC provider to use
  common_provider = "github"

  // Relative path to the repository for the given provider
  repository = "appvia/something"

  // Set the permission boundary for both the read-only and read-write role
  permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

  // List of policy ARNs to attach to the read-only role
  read_only_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  // List of policy ARNs to attach to the read-write role
  read_write_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  // List of additional repositories which will be able to read the remote
  // terraform state, created by this role.
  shared_repositories = [
    "appvia/repo-1",
    "appvia/repo-2",
  ]

  // Tags to apply to the role
  tags = {
    Name = "Example Common Provider"
  }
}
```

### Remote State Reader

```hcl
module "basic" {
  source  = "appvia/oidc/aws//modules/role"
  version = "0.0.16"

  // ID of the destination AWS account from which remote
  // state is to be read from.
  account_id = "0123456789"

  // Name of the region of the destination AWS account where
  // resource have been deployed to.
  region = "eu-west-2"

  // The path of the repository which produced the remote
  // state being read.
  repository = "appvia/repo-1"

  // Path to the identity token file containing the credentials needed
  // to assume the role.
  web_identity_token_file = "/tmp/web_identity_token_file"
}
```

<!-- BEGIN_TF_DOCS -->
## Providers

No providers.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->