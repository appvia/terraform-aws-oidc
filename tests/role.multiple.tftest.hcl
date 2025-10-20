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

run "multiple_repositories" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name        = "common"
    description = "Test multiple repositories mapping"
    repository  = "appvia/primary"
    repositories = [
      "appvia/repo-1",
      "appvia/repo-2",
    ]
    common_provider         = "github"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "GitHub"
    }
  }

  // Validate roles are created with expected names
  assert {
    condition     = resource.aws_iam_role.ro.name == "common-ro"
    error_message = "Read-only role name should be 'common-ro'"
  }

  assert {
    condition     = resource.aws_iam_role.rw.name == "common"
    error_message = "Read-write role name should be 'common'"
  }
}
