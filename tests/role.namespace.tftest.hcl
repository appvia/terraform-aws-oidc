mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [
        {
          sha1_fingerprint = "1234567890abcdef1234567890abcdef12345678"
        }
      ]
    }
  }
}

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      url = "https://token.actions.githubusercontent.com"
      arn = "arn:aws:iam::aws:oidc-provider/token.actions.githubusercontent.com"
    }
  }
}

run "namespace_disabled_default" {
  command = plan
  module {
    source = "./modules/role"
  }

  variables {
    name                    = "namespace-disabled"
    common_provider         = "github"
    description             = "Test role with namespace disabled (default behavior)"
    enable_entire_namespace = false
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    repository              = "appvia/test-repo"

    tags = {
      Name = "NamespaceDisabled"
    }
  }

  # It should create a read only role
  assert {
    condition     = aws_iam_role.ro.name == "namespace-disabled-ro"
    error_message = "Read only role should be created with correct name"
  }

  # It should create a read write role
  assert {
    condition     = aws_iam_role.rw.name == "namespace-disabled"
    error_message = "Read write role should be created with correct name"
  }

  assert {
    condition = alltrue([
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo.tfstate"),
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo.tfstate.tflock")
    ])
    error_message = "S3 policy should use both state file and lock file keys when namespace is disabled"
  }
}

run "namespace_enabled" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "namespace-enabled"
    common_provider         = "github"
    description             = "Test role with namespace enabled"
    enable_entire_namespace = true
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    repository              = "appvia/test-repo"

    tags = {
      Name = "NamespaceEnabled"
    }
  }

  # It should create a read only role
  assert {
    condition     = aws_iam_role.ro.name == "namespace-enabled-ro"
    error_message = "Read only role should be created with correct name"
  }

  # It should create a read write role
  assert {
    condition     = aws_iam_role.rw.name == "namespace-enabled"
    error_message = "Read write role should be created with correct name"
  }

  assert {
    condition = alltrue([
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo/*"),
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo.tfstate.tflock")
    ])
    error_message = "S3 policy should use namespace wildcard when namespace is enabled"
  }
}

run "namespace_enabled_with_suffix" {
  command = plan
  module {
    source = "./modules/role"
  }

  variables {
    name                    = "namespace-enabled-suffix"
    common_provider         = "github"
    description             = "Test role with namespace enabled and custom suffix"
    enable_entire_namespace = true
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    repository              = "appvia/test-repo"
    tf_state_suffix         = "production"

    tags = {
      Name = "NamespaceEnabledSuffix"
    }
  }

  assert {
    condition = alltrue([
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo-production/*"),
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo-production.tfstate.tflock")
    ])
    error_message = "S3 policy should use namespace wildcard when namespace is enabled"
  }
}

run "namespace_disabled_with_suffix" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name            = "namespace-disabled-suffix"
    description     = "Test role with namespace disabled and custom suffix"
    repository      = "appvia/test-repo"
    common_provider = "github"
    # Disable namespace access with custom suffix
    enable_entire_namespace = false
    tf_state_suffix         = "staging"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "NamespaceDisabledSuffix"
    }
  }

  assert {
    condition = alltrue([
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo-staging.tfstate"),
      contains(data.aws_iam_policy_document.base.statement[1].resources, "arn:aws:s3:::123456789012-us-west-2-tfstate/test-repo-staging.tfstate.tflock")
    ])
    error_message = "S3 policy should use namespace wildcard when namespace is disabled"
  }
}
