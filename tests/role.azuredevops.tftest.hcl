## Override only the data sources that need real AWS access (identity, region, the OIDC
## provider lookup). aws_iam_policy_document is deliberately left un-mocked and evaluated for
## real by the aws provider (a pure local computation, no API calls) so assertions below can
## verify the actual generated trust policy content rather than a stubbed value.
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
    url = "https://vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
    arn = "arn:aws:iam::aws:oidc-provider/vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
  }
}

run "azuredevops_provider" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                        = "azdo-common"
    description                 = "Test role using Azure DevOps OIDC provider"
    repository                  = "myorg/myproject/aws-oidc-sc"
    common_provider             = "azuredevops"
    azuredevops_organization_id = "00000000-0000-0000-0000-000000000000"
    permission_boundary_arn     = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_only_policy_arns       = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    read_write_policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps"
    }
  }

  // Validate both roles are created with expected names
  assert {
    condition     = resource.aws_iam_role.rw.name == "azdo-common"
    error_message = "Read-write role should be created with name 'azdo-common'"
  }

  assert {
    condition     = resource.aws_iam_role.ro[0].name == "azdo-common-ro"
    error_message = "Read-only role should be created with name 'azdo-common-ro'"
  }

  // Validate the trust policy is valid JSON
  assert {
    condition     = can(jsondecode(resource.aws_iam_role.rw.assume_role_policy))
    error_message = "Trust policy should be valid JSON"
  }

  // Validate the trust policy uses the Azure DevOps service connection subject format
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "sc://myorg/myproject/aws-oidc-sc")
    ]) > 0
    error_message = "Trust policy should contain the Azure DevOps service connection subject"
  }

  // Validate the trust policy uses the Azure DevOps workload identity federation audience
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "api://AzureADTokenExchange")
    ]) > 0
    error_message = "Trust policy should contain the Azure DevOps audience 'api://AzureADTokenExchange'"
  }

  // The read-write role's trust must NOT carry the '-ro' suffix - it trusts the plain service connection
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "sc://myorg/myproject/aws-oidc-sc-ro")
    ]) == 0
    error_message = "Read-write role's trust policy should not reference the '-ro' service connection"
  }

  // The read-only role must trust a distinct, '-ro' suffixed service connection - without this,
  // the same Azure DevOps service connection could assume both the rw and ro roles, since Azure
  // DevOps subjects carry no branch/tag/environment claim to otherwise distinguish them
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && strcontains(jsonencode(stmt.Condition), "sc://myorg/myproject/aws-oidc-sc-ro")
    ]) > 0
    error_message = "Read-only role's trust policy should reference the '-ro' suffixed service connection"
  }
}

run "azuredevops_missing_organization_id" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                    = "azdo-missing-org"
    description             = "Test role using Azure DevOps OIDC provider without an organization id"
    repository              = "myorg/myproject/aws-oidc-sc"
    common_provider         = "azuredevops"
    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Missing-Org"
    }
  }

  expect_failures = [
    var.common_provider,
  ]
}

run "azuredevops_read_only_disabled_single_repo" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                        = "azdo-rw-only"
    description                 = "Test Azure DevOps role with read-only role disabled"
    repository                  = "myorg/myproject/aws-oidc-sc"
    common_provider             = "azuredevops"
    azuredevops_organization_id = "00000000-0000-0000-0000-000000000000"
    enable_read_only_role       = false
    permission_boundary_arn     = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-RW-Only"
    }
  }

  // Validate the read-write role is created
  assert {
    condition     = resource.aws_iam_role.rw.name == "azdo-rw-only"
    error_message = "Read-write role should be created with name 'azdo-rw-only'"
  }

  // Validate read-only role is NOT created
  assert {
    condition     = length(resource.aws_iam_role.ro) == 0
    error_message = "Read-only role should not be created when enable_read_only_role is false"
  }
}

run "azuredevops_custom_provider_override" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name        = "azdo-custom"
    description = "Test role using Azure DevOps via the generic custom_provider escape hatch"
    repository  = "myorg/myproject/aws-oidc-sc"

    // Proves Azure DevOps can be fully expressed with the pre-existing generic
    // custom_provider mechanism, with no dependency on common_provider at all.
    custom_provider = {
      url                    = "https://vstoken.dev.azure.com/00000000-0000-0000-0000-000000000000"
      audiences              = ["api://AzureADTokenExchange"]
      subject_reader_mapping = "sc://{repo}"
      subject_branch_mapping = "sc://{repo}"
      subject_env_mapping    = "sc://{repo}"
      subject_tag_mapping    = "sc://{repo}"
    }

    permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Custom"
    }
  }

  assert {
    condition     = resource.aws_iam_role.rw.name == "azdo-custom"
    error_message = "Read-write role should be created with name 'azdo-custom'"
  }

  assert {
    condition     = can(jsondecode(resource.aws_iam_role.rw.assume_role_policy))
    error_message = "Trust policy should be valid JSON with custom provider"
  }
}

run "azuredevops_primary_role_account_id_rejected_for_github" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                                = "github-primary-rejected"
    description                         = "GitHub role should reject azuredevops_primary_role_account_id"
    repository                          = "myorg/myrepo"
    common_provider                     = "github"
    azuredevops_primary_role_account_id = "111111111111"
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "GitHub-Primary-Rejected"
    }
  }

  expect_failures = [
    var.azuredevops_primary_role_account_id,
  ]
}

run "azuredevops_primary_role_account_id_adds_cross_account_trust" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                                = "azdo-spoke"
    description                         = "Test spoke-account role trusting the primary hub-account role"
    repository                          = "myorg/myproject/aws-oidc-sc"
    common_provider                     = "azuredevops"
    azuredevops_organization_id         = "00000000-0000-0000-0000-000000000000"
    azuredevops_primary_role_account_id = "111111111111"
    shared_repositories                 = ["myorg/myproject/other-sc"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Spoke"
    }
  }

  // Read-write role should trust the primary account's read-write role
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "arn:aws:iam::111111111111:role/azdo-spoke")
    ]) > 0
    error_message = "Read-write role should trust the primary account's read-write role via sts:AssumeRole"
  }

  // Read-only role should trust the primary account's read-only role
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "arn:aws:iam::111111111111:role/azdo-spoke-ro")
    ]) > 0
    error_message = "Read-only role should trust the primary account's read-only role via sts:AssumeRole"
  }

  // State reader role should trust the primary account's state reader role
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "arn:aws:iam::111111111111:role/azdo-spoke-sr")
    ]) > 0
    error_message = "State reader role should trust the primary account's state reader role via sts:AssumeRole"
  }

  // Spoke roles are only reachable via the primary role's sts:AssumeRole, so the direct
  // OIDC (sts:AssumeRoleWithWebIdentity) trust statement should be absent on all three roles
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Spoke read-write role should not trust the Azure DevOps OIDC provider directly"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Spoke read-only role should not trust the Azure DevOps OIDC provider directly"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Spoke state reader role should not trust the Azure DevOps OIDC provider directly"
  }

  // The allow_primary_assume_role policy grants the primary role permission to reach into
  // spokes - a spoke role itself has no need to assume anything, so it should not get one
  assert {
    condition     = length(resource.aws_iam_role_policy.allow_primary_assume_role_rw) == 0
    error_message = "Spoke read-write role should not have an allow_primary_assume_role policy"
  }

  assert {
    condition     = length(resource.aws_iam_role_policy.allow_primary_assume_role_ro) == 0
    error_message = "Spoke read-only role should not have an allow_primary_assume_role policy"
  }

  assert {
    condition     = length(resource.aws_iam_role_policy.allow_primary_assume_role_sr) == 0
    error_message = "Spoke state reader role should not have an allow_primary_assume_role policy"
  }
}

run "azuredevops_primary_role_account_id_matching_own_account_is_noop" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                        = "azdo-hub"
    description                 = "Test hub-account role where azuredevops_primary_role_account_id matches its own account"
    repository                  = "myorg/myproject/aws-oidc-sc"
    common_provider             = "azuredevops"
    azuredevops_organization_id = "00000000-0000-0000-0000-000000000000"
    // Matches the mocked aws_caller_identity account_id below - i.e. this role IS the primary,
    // not a spoke being chained into, so no cross-account trust statement should be added.
    azuredevops_primary_role_account_id = "123456789012"
    shared_repositories                 = ["myorg/myproject/other-sc"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Hub"
    }
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole"
    ]) == 0
    error_message = "Read-write role should not gain a cross-account trust statement when the primary account matches its own account"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole"
    ]) == 0
    error_message = "Read-only role should not gain a cross-account trust statement when the primary account matches its own account"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRole"
    ]) == 0
    error_message = "State reader role should not gain a cross-account trust statement when the primary account matches its own account"
  }

  // The hub role IS the primary, so it should keep its direct OIDC trust statement
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) > 0
    error_message = "Hub read-write role should still trust the Azure DevOps OIDC provider directly"
  }

  // The hub role should be granted permission to assume its counterpart role in any spoke account
  assert {
    condition = (
      jsondecode(resource.aws_iam_role_policy.allow_primary_assume_role_rw[0].policy).Statement[0].Action == "sts:AssumeRole" &&
      jsondecode(resource.aws_iam_role_policy.allow_primary_assume_role_rw[0].policy).Statement[0].Resource == "arn:aws:iam::*:role/azdo-hub"
    )
    error_message = "Hub read-write role should have an allow_primary_assume_role policy granting sts:AssumeRole on arn:aws:iam::*:role/azdo-hub"
  }

  assert {
    condition     = resource.aws_iam_role_policy.allow_primary_assume_role_rw[0].name == "allow_primary_assume_role"
    error_message = "Primary assume-role policy should be named 'allow_primary_assume_role'"
  }

  assert {
    condition = (
      jsondecode(resource.aws_iam_role_policy.allow_primary_assume_role_ro[0].policy).Statement[0].Resource == "arn:aws:iam::*:role/azdo-hub-ro"
    )
    error_message = "Hub read-only role should have an allow_primary_assume_role policy granting sts:AssumeRole on arn:aws:iam::*:role/azdo-hub-ro"
  }

  assert {
    condition = (
      jsondecode(resource.aws_iam_role_policy.allow_primary_assume_role_sr[0].policy).Statement[0].Resource == "arn:aws:iam::*:role/azdo-hub-sr"
    )
    error_message = "Hub state reader role should have an allow_primary_assume_role policy granting sts:AssumeRole on arn:aws:iam::*:role/azdo-hub-sr"
  }
}
