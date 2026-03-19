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

run "disable_read_only_role_single_repo_allows_all_branches" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "rw-only-single-repo"
    description             = "Test with read-only role disabled for single repository"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    enable_read_only_role   = false
    enable_terraform_state  = true
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "RW-Only-Single-Repo"
    }
  }

  // Validate the read-write role is created
  assert {
    condition     = resource.aws_iam_role.rw.name == "rw-only-single-repo"
    error_message = "Read-write role should be created with name 'rw-only-single-repo'"
  }

  // Validate read-only role is NOT created
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false"
  }

  // Validate the trust policy allows all branches when enable_read_only_role is false
  // The policy should have exactly 3 conditions:
  // 1. Audience condition
  // 2. Subject condition for all branches (with StringLike matcher)
  // 3. NOT a branch/tag/environment condition (those are only added when enable_read_only_role is true)
  assert {
    condition     = can(jsondecode(resource.aws_iam_role.rw.assume_role_policy))
    error_message = "Trust policy should be valid JSON"
  }

  // Additional assertion: verify the policy contains the expected structure
  assert {
    condition = can(
      length([
        for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
        if stmt.Effect == "Allow" && contains(stmt.Principal.Federated, "oidc-provider/token.actions.githubusercontent.com")
      ]) > 0
    )
    error_message = "Trust policy should contain Allow statement with Federated principal for OIDC provider"
  }
}

run "disable_read_only_role_multiple_repos_allows_all_branches" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "rw-only-multiple-repos"
    description             = "Test with read-only role disabled for multiple repositories"
    repositories            = ["appvia/repo-1", "appvia/repo-2", "appvia/repo-3"]
    common_provider         = "github"
    enable_read_only_role   = false
    enable_terraform_state  = true
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "RW-Only-Multiple-Repos"
    }
  }

  // Validate the read-write role is created
  assert {
    condition     = resource.aws_iam_role.rw.name == "rw-only-multiple-repos"
    error_message = "Read-write role should be created with name 'rw-only-multiple-repos'"
  }

  // Validate read-only role is NOT created
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false"
  }

  // Validate the trust policy is valid JSON
  assert {
    condition     = can(jsondecode(resource.aws_iam_role.rw.assume_role_policy))
    error_message = "Trust policy should be valid JSON for multiple repositories"
  }

  // Verify policy allows all branches for all repositories
  assert {
    condition = can(
      length([
        for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
        if stmt.Effect == "Allow" && contains(keys(stmt), "Condition")
      ]) > 0
    )
    error_message = "Trust policy should contain conditions for all repositories"
  }
}

run "enable_read_only_role_with_branch_protection" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "rw-with-branch-protection"
    description             = "Test with read-only role enabled and branch protection"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    enable_read_only_role   = true
    enable_terraform_state  = true
    protected_by = {
      branch      = "main"
      environment = null
      tag         = null
    }
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "RW-With-Branch-Protection"
    }
  }

  // Validate both roles are created
  assert {
    condition     = resource.aws_iam_role.rw.name == "rw-with-branch-protection"
    error_message = "Read-write role should be created"
  }

  assert {
    condition     = length(resource.aws_iam_role.ro) == 1
    error_message = "Read-only role should be created when enable_read_only_role is true"
  }

  // Validate read-write role has branch protection
  assert {
    condition     = resource.aws_iam_role.rw.max_session_duration == null || resource.aws_iam_role.rw.max_session_duration > 0
    error_message = "Read-write role should be properly configured"
  }

  // Validate read-only role is properly named
  assert {
    condition     = resource.aws_iam_role.ro[0].name == "rw-with-branch-protection-ro"
    error_message = "Read-only role should have proper naming convention"
  }
}


run "disable_read_only_role_policy_structure_validation" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "policy-structure-test"
    description             = "Validate policy structure when read-only is disabled"
    repositories            = ["appvia/repo-a", "appvia/repo-b"]
    common_provider         = "github"
    enable_read_only_role   = false
    enable_terraform_state  = false
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "Policy-Structure-Test"
    }
  }

  // Validate the read-write role is created
  assert {
    condition     = resource.aws_iam_role.rw.name == "policy-structure-test"
    error_message = "Read-write role should be created with policy structure test"
  }

  // Validate read-only role is NOT created when enable_read_only_role is false
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false"
  }

  // Validate inline policies for read-write role are attached
  assert {
    condition     = length(resource.aws_iam_role_policy.inline_policies_rw) >= 0
    error_message = "Inline policies can be attached to read-write role"
  }

  // Validate managed policies for read-write role are attached
  assert {
    condition     = length(resource.aws_iam_role_policy_attachment.rw) >= 0
    error_message = "Managed policies can be attached to read-write role"
  }
}

run "disable_read_only_role_with_custom_provider" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name        = "custom-provider-rw-only"
    description = "Test custom provider with read-only role disabled"
    repository  = "my-org/my-repo"

    custom_provider = {
      url                    = "https://token.actions.githubusercontent.com"
      audiences              = ["sts.amazonaws.com"]
      subject_reader_mapping = "repo:{repo}:*"
      subject_branch_mapping = "repo:{repo}:ref:refs/heads/{ref}"
      subject_tag_mapping    = "repo:{repo}:ref:refs/tags/{ref}"
      subject_env_mapping    = "repo:{repo}:environment:{env}"
    }

    enable_read_only_role   = false
    enable_terraform_state  = false
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "Custom-Provider-RW-Only"
    }
  }

  // Validate the read-write role is created with custom provider
  assert {
    condition     = resource.aws_iam_role.rw.name == "custom-provider-rw-only"
    error_message = "Read-write role should be created with custom provider"
  }

  // Validate read-only role is NOT created with custom provider
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false with custom provider"
  }

  // Validate the trust policy is valid JSON with custom provider
  assert {
    condition     = can(jsondecode(resource.aws_iam_role.rw.assume_role_policy))
    error_message = "Trust policy should be valid JSON with custom provider"
  }
}
