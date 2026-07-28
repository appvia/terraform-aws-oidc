## Configure the real aws provider with fake static credentials, skipping every validation
## call it would otherwise make. This lets aws_iam_policy_document (a pure local computation,
## no API calls) evaluate for real, so assertions below can verify the actual generated trust
## policy content rather than a stubbed value, without requiring genuine AWS credentials.
provider "aws" {
  region                      = "us-west-2"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

## Override only the data sources that would otherwise still need real AWS access (identity,
## region, the OIDC provider lookup).
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

run "trust_conditions_applied_to_all_roles" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "vpc-locked"
    description             = "Test the trust policy conditions are applied to every role"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    shared_repositories     = ["appvia/repo-1"]
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    trust_policy_conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceVpc"
        values   = ["vpc-0123456789abcdef0"]
      },
    ]
    tags = {
      Name = "VPC-Locked"
    }
  }

  // The read-write role's OIDC trust statement should carry the additional condition
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity" &&
      strcontains(jsonencode(stmt.Condition), "aws:SourceVpc") &&
      strcontains(jsonencode(stmt.Condition), "vpc-0123456789abcdef0")
    ]) == 1
    error_message = "Read-write trust policy should restrict sts:AssumeRoleWithWebIdentity to the supplied VPC"
  }

  // The read-only role's OIDC trust statement should carry the additional condition
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity" &&
      strcontains(jsonencode(stmt.Condition), "aws:SourceVpc") &&
      strcontains(jsonencode(stmt.Condition), "vpc-0123456789abcdef0")
    ]) == 1
    error_message = "Read-only trust policy should restrict sts:AssumeRoleWithWebIdentity to the supplied VPC"
  }

  // The state reader role's OIDC trust statement should carry the additional condition
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity" &&
      strcontains(jsonencode(stmt.Condition), "aws:SourceVpc") &&
      strcontains(jsonencode(stmt.Condition), "vpc-0123456789abcdef0")
    ]) == 1
    error_message = "State reader trust policy should restrict sts:AssumeRoleWithWebIdentity to the supplied VPC"
  }

  // The module's own audience and subject conditions must survive alongside the new one
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity" &&
      strcontains(jsonencode(stmt.Condition), "token.actions.githubusercontent.com:aud") &&
      strcontains(jsonencode(stmt.Condition), "token.actions.githubusercontent.com:sub")
    ]) == 1
    error_message = "Additional trust conditions should not replace the module's own aud/sub conditions"
  }
}

run "trust_conditions_default_is_empty" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "vpc-unlocked"
    description             = "Test no additional conditions are added by default"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    shared_repositories     = ["appvia/repo-1"]
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "VPC-Unlocked"
    }
  }

  assert {
    condition     = !strcontains(resource.aws_iam_role.rw.assume_role_policy, "aws:SourceVpc")
    error_message = "Read-write trust policy should carry no additional conditions by default"
  }

  assert {
    condition     = !strcontains(resource.aws_iam_role.ro[0].assume_role_policy, "aws:SourceVpc")
    error_message = "Read-only trust policy should carry no additional conditions by default"
  }

  assert {
    condition     = !strcontains(resource.aws_iam_role.sr[0].assume_role_policy, "aws:SourceVpc")
    error_message = "State reader trust policy should carry no additional conditions by default"
  }
}

run "trust_conditions_support_multiple_entries" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "vpc-and-ip-locked"
    description             = "Test multiple conditions with differing operators are rendered"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    trust_policy_conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceVpc"
        values   = ["vpc-0123456789abcdef0"]
      },
      {
        test     = "IpAddress"
        variable = "aws:SourceIp"
        values   = ["10.0.0.0/16", "10.1.0.0/16"]
      },
    ]
    tags = {
      Name = "VPC-And-IP-Locked"
    }
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity" &&
      strcontains(jsonencode(stmt.Condition), "aws:SourceVpc") &&
      strcontains(jsonencode(stmt.Condition), "aws:SourceIp") &&
      strcontains(jsonencode(stmt.Condition), "10.1.0.0/16")
    ]) == 1
    error_message = "Both supplied conditions should be rendered onto the trust policy"
  }
}

run "trust_conditions_applied_to_spoke_assume_role" {
  command = plan

  module {
    source = "./modules/role"
  }

  ## Spoke roles drop the OIDC statement entirely, so the conditions must land on the
  ## sts:AssumeRole statement trusting the primary (hub) account's counterpart role
  override_data {
    target = data.aws_iam_openid_connect_provider.this
    values = {
      url = "https://vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
      arn = "arn:aws:iam::aws:oidc-provider/vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
    }
  }

  variables {
    name                                = "azdo-spoke-vpc-locked"
    description                         = "Test the conditions are applied to the hub-to-spoke trust"
    repository                          = "myorg/myproject/aws-oidc-sc"
    common_provider                     = "azuredevops"
    azuredevops_organization_id         = "00000000-0000-0000-0000-000000000000"
    azuredevops_primary_role_account_id = "111111111111"
    shared_repositories                 = ["myorg/myproject/other-sc"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    trust_policy_conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceVpc"
        values   = ["vpc-0123456789abcdef0"]
      },
    ]
    tags = {
      Name = "AzureDevOps-Spoke-VPC-Locked"
    }
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Condition), "aws:SourceVpc")
    ]) == 1
    error_message = "Spoke read-write role should restrict the hub sts:AssumeRole to the supplied VPC"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Condition), "aws:SourceVpc")
    ]) == 1
    error_message = "Spoke read-only role should restrict the hub sts:AssumeRole to the supplied VPC"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Condition), "aws:SourceVpc")
    ]) == 1
    error_message = "Spoke state reader role should restrict the hub sts:AssumeRole to the supplied VPC"
  }
}

run "trust_conditions_reject_empty_values" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "invalid-empty-values"
    description             = "Test a condition with no values is rejected"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    trust_policy_conditions = [
      {
        test     = "StringEquals"
        variable = "aws:SourceVpc"
        values   = []
      },
    ]
    tags = {
      Name = "Invalid-Empty-Values"
    }
  }

  expect_failures = [
    var.trust_policy_conditions,
  ]
}

run "trust_conditions_reject_module_owned_claims" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "invalid-sub-claim"
    description             = "Test overriding the module's own sub condition is rejected"
    repository              = "appvia/terraform-aws-oidc"
    common_provider         = "github"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    trust_policy_conditions = [
      {
        test     = "StringLike"
        variable = "token.actions.githubusercontent.com:sub"
        values   = ["repo:appvia/*"]
      },
    ]
    tags = {
      Name = "Invalid-Sub-Claim"
    }
  }

  expect_failures = [
    var.trust_policy_conditions,
  ]
}
