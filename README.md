# Terraform IAM OIDC Integration

## Overview

This module provides two child modules to simplify integrating AWS IAM Roles with OpenID Connect identity provider trusts.
The [Provider module](modules/provider) is responsible for creating an OpenID Connect provider in IAM, whilst the [Role module](modules/role)
is responsible for creating AWS IAM Roles with a trust relationship to the AWS IAM OIDC Provider.
