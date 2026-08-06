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

run "azuredevops_assume_roles_replaces_named_role_trust" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                                = "azdo-combined"
    description                         = "Test role trusting only the explicitly named roles, not its own naming-convention counterpart"
    repository                          = "myorg/myproject/aws-oidc-sc"
    common_provider                     = "azuredevops"
    azuredevops_organization_id         = "00000000-0000-0000-0000-000000000000"
    azuredevops_primary_role_account_id = "111111111111"
    azuredevops_assume_roles            = ["external-ci", "another-ci"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Combined"
    }
  }

  // Read-write role should NOT trust the primary account's naming-convention counterpart -
  // azuredevops_assume_roles replaces that statement rather than adding to it
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/azdo-combined\"")
    ]) == 0
    error_message = "Read-write role should not trust the primary account's naming-convention counterpart once azuredevops_assume_roles is set"
  }

  // ...but should trust both named roles, resolved to ARNs in the primary account, unsuffixed
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" &&
      strcontains(jsonencode(stmt.Principal), "role/external-ci\"") &&
      strcontains(jsonencode(stmt.Principal), "role/another-ci\"")
    ]) > 0
    error_message = "Read-write role should trust both named roles, resolved to unsuffixed ARNs in the primary account"
  }

  // Read-write trust should NOT pick up the '-ro' suffixed variants
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/external-ci-ro\"")
    ]) == 0
    error_message = "Read-write role should not trust the '-ro' suffixed variant of a named role"
  }

  // Read-only role should likewise NOT trust the primary account's naming-convention counterpart
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/azdo-combined-ro\"")
    ]) == 0
    error_message = "Read-only role should not trust the primary account's naming-convention counterpart once azuredevops_assume_roles is set"
  }

  // ...but should trust both named roles, resolved to '-ro'-suffixed ARNs in the primary account
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" &&
      strcontains(jsonencode(stmt.Principal), "role/external-ci-ro\"") &&
      strcontains(jsonencode(stmt.Principal), "role/another-ci-ro\"")
    ]) > 0
    error_message = "Read-only role should trust both named roles, resolved to '-ro'-suffixed ARNs in the primary account"
  }

  // Being a spoke role (via azuredevops_primary_role_account_id) still drops the direct
  // OIDC trust statement, regardless of the named-role trust
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Spoke read-write role should not trust the Azure DevOps OIDC provider directly, even with azuredevops_assume_roles set"
  }
}

run "azuredevops_assume_roles_can_include_own_name_to_keep_default_counterpart" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                                = "azdo-combined-plus-self"
    description                         = "Test role including its own name in azuredevops_assume_roles to keep the default counterpart trusted"
    repository                          = "myorg/myproject/aws-oidc-sc"
    common_provider                     = "azuredevops"
    azuredevops_organization_id         = "00000000-0000-0000-0000-000000000000"
    azuredevops_primary_role_account_id = "111111111111"
    azuredevops_assume_roles            = ["azdo-combined-plus-self", "external-ci"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Combined-Plus-Self"
    }
  }

  // Read-write role should trust its own naming-convention counterpart, since it was
  // explicitly included in azuredevops_assume_roles...
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/azdo-combined-plus-self\"")
    ]) > 0
    error_message = "Read-write role should trust its own naming-convention counterpart when explicitly listed in azuredevops_assume_roles"
  }

  // ...as well as the other named role
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/external-ci\"")
    ]) > 0
    error_message = "Read-write role should trust the other named role alongside its own counterpart"
  }

  // Read-only role should trust its own '-ro' naming-convention counterpart likewise
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/azdo-combined-plus-self-ro\"")
    ]) > 0
    error_message = "Read-only role should trust its own '-ro' naming-convention counterpart when explicitly listed in azuredevops_assume_roles"
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

run "azuredevops_assume_roles_drops_web_identity_trust_in_primary_account" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                        = "azdo-hub-assume-roles"
    description                 = "Test hub-account role with azuredevops_assume_roles set should drop the direct OIDC trust statement too"
    repository                  = "myorg/myproject/aws-oidc-sc"
    common_provider             = "azuredevops"
    azuredevops_organization_id = "00000000-0000-0000-0000-000000000000"
    // Matches the mocked aws_caller_identity account_id, so this role would otherwise be
    // treated as the primary (hub) role - but azuredevops_assume_roles takes over the trust
    // source entirely, so the direct OIDC trust statement should still be dropped.
    azuredevops_primary_role_account_id = "123456789012"
    azuredevops_assume_roles            = ["external-ci"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Hub-Assume-Roles"
    }
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Read-write role should not trust the Azure DevOps OIDC provider directly once azuredevops_assume_roles is set, even in the primary account"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.ro[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Read-only role should not trust the Azure DevOps OIDC provider directly once azuredevops_assume_roles is set, even in the primary account"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.rw.assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/external-ci\"")
    ]) > 0
    error_message = "Read-write role should still trust the named role via sts:AssumeRole"
  }
}

run "azuredevops_assume_roles_ignored_for_state_reader_in_primary_account" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                        = "azdo-hub-sr-ignore"
    description                 = "State reader role should ignore azuredevops_assume_roles entirely, even in the primary account"
    repository                  = "myorg/myproject/aws-oidc-sc"
    common_provider             = "azuredevops"
    azuredevops_organization_id = "00000000-0000-0000-0000-000000000000"
    // Matches the mocked aws_caller_identity account_id - this role is the primary (hub) role.
    azuredevops_primary_role_account_id = "123456789012"
    azuredevops_assume_roles            = ["external-ci"]
    shared_repositories                 = ["myorg/myproject/other-sc"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Hub-SR-Ignore"
    }
  }

  // azuredevops_assume_roles isn't supported for the state reader role, so - unlike the
  // read-write/read-only roles - it should keep its direct OIDC trust statement rather than
  // ending up with an empty (invalid) trust policy
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) > 0
    error_message = "State reader role should still trust the Azure DevOps OIDC provider directly, since azuredevops_assume_roles doesn't apply to it"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/external-ci\"")
    ]) == 0
    error_message = "State reader role should not trust the azuredevops_assume_roles named roles"
  }
}

run "azuredevops_assume_roles_ignored_for_state_reader_in_spoke_account" {
  command = plan

  module {
    source = "./modules/role"
  }

  variables {
    name                                = "azdo-spoke-sr-ignore"
    description                         = "State reader role should keep trusting its naming-convention counterpart, not azuredevops_assume_roles, in a spoke account"
    repository                          = "myorg/myproject/aws-oidc-sc"
    common_provider                     = "azuredevops"
    azuredevops_organization_id         = "00000000-0000-0000-0000-000000000000"
    azuredevops_primary_role_account_id = "111111111111"
    azuredevops_assume_roles            = ["external-ci"]
    shared_repositories                 = ["myorg/myproject/other-sc"]
    permission_boundary_arn             = "arn:aws:iam::aws:policy/AdministratorAccess"
    read_write_policy_arns              = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    tags = {
      Name = "AzureDevOps-Spoke-SR-Ignore"
    }
  }

  // The state reader role keeps trusting the naming-convention counterpart in the primary
  // account (azdo-spoke-sr-ignore-sr), unaffected by azuredevops_assume_roles
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "arn:aws:iam::111111111111:role/azdo-spoke-sr-ignore-sr")
    ]) > 0
    error_message = "State reader role should trust the primary account's naming-convention counterpart regardless of azuredevops_assume_roles"
  }

  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Effect == "Allow" && stmt.Action == "sts:AssumeRole" && strcontains(jsonencode(stmt.Principal), "role/external-ci\"")
    ]) == 0
    error_message = "State reader role should not trust the azuredevops_assume_roles named roles"
  }

  // Being a spoke role still drops the direct OIDC trust statement on the state reader role
  assert {
    condition = length([
      for stmt in jsondecode(resource.aws_iam_role.sr[0].assume_role_policy).Statement : stmt
      if stmt.Action == "sts:AssumeRoleWithWebIdentity"
    ]) == 0
    error_message = "Spoke state reader role should not trust the Azure DevOps OIDC provider directly"
  }
}
