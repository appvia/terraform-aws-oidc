mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "iam_openid_connect_provider" {
    defaults = {
      url = "https://token.actions.githubusercontent.com"
      arn = "arn:aws:iam::aws:oidc-provider/token.actions.githubusercontent.com"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

run "disable_read_only_role" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "rw-only"
    description             = "Test with read-only role disabled"
    repository              = "appvia/test-repo"
    common_provider         = "github"
    enable_read_only_role   = false
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "GitHub-RW-Only"
    }
  }

  // Validate the read write role is created with expected name
  assert {
    condition     = resource.aws_iam_role.rw.name == "rw-only"
    error_message = "Read-write role should be created with name 'rw-only'"
  }

  // Validate terraform state policy for read-write is still created
  assert {
    condition     = resource.aws_iam_role_policy.tfstate_apply_rw[0].name == "tfstate_apply"
    error_message = "Terraform state apply policy should be created"
  }

  // Validate read-only role is NOT created
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false"
  }

  // Validate terraform state policy for read-only is NOT created
  assert {
    condition     = length(resource.aws_iam_role_policy.tfstate_plan_ro) == 0
    error_message = "Terraform state plan policy should not be created when enable_read_only_role is false"
  }
}