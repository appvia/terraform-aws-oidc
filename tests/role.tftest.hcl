## Override only the data sources that need real AWS access (identity, region, the OIDC
## provider lookup). aws_iam_policy_document is deliberately left un-mocked and evaluated for
## real by the aws provider (a pure local computation, no API calls) so assertions below verify
## the actual generated trust policy content - proving the azuredevops/trust_policy/primary-role
## additions elsewhere in this module left GitHub/GitLab trust policy generation unchanged.
override_data {
  target = data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

override_data {
  target = data.aws_region.current
  values = {
    region = "us-west-2"
  }
}

override_data {
  target = data.aws_iam_openid_connect_provider.this
  values = {
    url = "https://token.actions.githubusercontent.com"
    arn = "arn:aws:iam::aws:oidc-provider/token.actions.githubusercontent.com"
  }
}

run "github_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "common"
    description             = "Test role using GitHub OIDC provider"
    repository              = "appvia/something"
    common_provider         = "github"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "GitHub"
    }

    shared_repositories = [
      "appvia/repo-1",
      "appvia/repo-2",
    ]
  }

  // GitHub's audience and StringLike subject matching must be unaffected by the azuredevops/
  // primary-role additions elsewhere in the module
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRoleWithWebIdentity" && strcontains(jsonencode(stmt.Condition), "sts.amazonaws.com")
    ]) > 0
    error_message = "GitHub read-write role should trust the sts.amazonaws.com audience via a direct OIDC statement"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "StringLike") && strcontains(jsonencode(stmt.Condition), "repo:appvia/something:ref:refs/heads/main")
    ]) > 0
    error_message = "GitHub read-write role should use StringLike matching against the branch-protected subject"
  }

  // GitHub roles must never gain the Azure-DevOps-only cross-account chaining behaviour
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole"
    ]) == 0
    error_message = "GitHub read-write role should not gain an Azure-DevOps-only sts:AssumeRole trust statement"
  }

  assert {
    condition     = length(resource.aws_iam_role_policy.allow_primary_assume_role_rw) == 0
    error_message = "GitHub read-write role should never get the Azure-DevOps-only allow_primary_assume_role policy"
  }
}

run "gitlab_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "common"
    description             = "Test role using GitLab OIDC provider"
    repository              = "appvia/something"
    common_provider         = "gitlab"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "GitLab"
    }
  }

  // GitLab's audience and StringLike subject matching must be unaffected by the azuredevops/
  // primary-role additions elsewhere in the module
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRoleWithWebIdentity" && strcontains(jsonencode(stmt.Condition), "gitlab.com")
    ]) > 0
    error_message = "GitLab read-write role should trust the gitlab.com audience via a direct OIDC statement"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "StringLike") && strcontains(jsonencode(stmt.Condition), "project_path:appvia/something:ref_type:branch:ref:main")
    ]) > 0
    error_message = "GitLab read-write role should use StringLike matching against the branch-protected subject"
  }

  // GitLab roles must never gain the Azure-DevOps-only cross-account chaining behaviour
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole"
    ]) == 0
    error_message = "GitLab read-write role should not gain an Azure-DevOps-only sts:AssumeRole trust statement"
  }

  assert {
    condition     = length(resource.aws_iam_role_policy.allow_primary_assume_role_rw) == 0
    error_message = "GitLab read-write role should never get the Azure-DevOps-only allow_primary_assume_role policy"
  }
}

run "custom_providers" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name        = "custom"
    description = "Test role using custom OIDC provider"
    repository  = "appvia/something"

    custom_provider = {
      url                    = "https://token.actions.githubusercontent.com"
      audiences              = ["test"]
      subject_branch_mapping = "repo={repo},branch={ref}"
      subject_tag_mapping    = "repo={repo},tag={ref}"
      subject_reader_mapping = "repo={repo}"
      subject_env_mapping    = "repo={repo},environment={environment}"
    }

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"

    read_only_inline_policies = {
      ReadOnly = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Sid" : "ReadOnlyActions",
            "Effect" : "Allow",
            "Action" : [
              "ec2:Describe*",
              "ec2:Get*",
              "ec2:ListImagesInRecycleBin",
              "ec2:ListSnapshotsInRecycleBin",
              "ec2:SearchLocalGatewayRoutes",
              "ec2:SearchTransitGatewayRoutes",
              "s3:DescribeJob",
              "s3:Get*",
              "s3:List*",
            ],
            "Resource" : "*"
          }
        ]
      })
    }

    read_write_inline_policies = {
      AdministratorAccess = jsonencode({
        "Version" : "2012-10-17",
        "Statement" : [
          {
            "Effect" : "Allow",
            "Action" : "*",
            "Resource" : "*"
          }
        ]
      })
    }

    tags = {
      Name = "Custom"
    }
  }
}
