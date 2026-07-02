locals {
  # The current account ID, if not provided
  account_id = var.account_id != null ? var.account_id : data.aws_caller_identity.current.account_id
  ## The common OIDC providers to use
  common_providers = {
    ## GitHub OIDC provider configuration
    github = {
      ## GitHub OIDC provider configuration
      url = "https://token.actions.githubusercontent.com"
      ## The audiences to be used for GitHub OIDC tokens
      audiences = ["sts.amazonaws.com"]
      ## The subject mapping templates for GitHub
      subject_reader_mapping = "repo:{repo}:*"
      ## The branch subject mapping template for GitHub
      subject_branch_mapping = "repo:{repo}:ref:refs/heads/{ref}"
      ## The environment subject mapping template for GitHub
      subject_env_mapping = "repo:{repo}:environment:{env}"
      ## The tag subject mapping template for GitHub
      subject_tag_mapping = "repo:{repo}:ref:refs/tags/{ref}"
      ## GitHub's reader mapping ends in a wildcard, so the sub condition needs glob matching
      subject_condition_test = "StringLike"
    }

    ## GitLab OIDC provider configuration
    gitlab = {
      ## The URL of the GitLab instance
      url = "https://gitlab.com"
      ## The audiences to be used for GitLab OIDC tokens
      audiences = ["https://gitlab.com"]
      ## The subject mapping templates for gitlab
      subject_reader_mapping = "project_path:{repo}:*"
      ## The branch subject mapping template for gitlab
      subject_branch_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
      # GitLab includes environment info as separate JWT claims (environment, deployment_tier)
      # rather than in the subject claim. Need to use custom claim conditions for environment-based access.
      # setting this to empty string to avoid null value error for now.
      subject_env_mapping = ""
      ## The tag subject mapping template for gitlab
      subject_tag_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
      ## GitLab's reader mapping ends in a wildcard, so the sub condition needs glob matching
      subject_condition_test = "StringLike"
    }

    ## Azure DevOps OIDC provider configuration
    azuredevops = {
      ## Azure DevOps OIDC issuer is per-organization (identified by the org's GUID), unlike the
      ## fixed GitHub/GitLab URLs, so it must be derived from the organisation ID variable
      url = var.azuredevops_organization_id != null ? format("https://vstoken.dev.azure.com/%s", var.azuredevops_organization_id) : null
      ## The audience for Azure DevOps workload identity federation tokens
      audiences = ["api://AzureADTokenExchange"]
      ## Azure DevOps subjects are scoped to a service connection (org/project/service-connection)
      ## and carry no branch/tag/environment claim, so all mapping templates resolve identically.
      ## Branch/tag/environment protection must instead be enforced in Azure DevOps itself, using
      ## a dedicated service connection per protection boundary (see docs/05-security-best-practices.md).
      subject_reader_mapping = "sc://{repo}"
      subject_branch_mapping = "sc://{repo}"
      subject_env_mapping    = "sc://{repo}"
      subject_tag_mapping    = "sc://{repo}"
      ## Azure DevOps subjects carry no wildcard-able segment, so the sub condition can and
      ## should be an exact match rather than a glob match
      subject_condition_test = "StringEquals"
    }
  }
  # The derived permission_boundary arn
  permission_boundary_by_name = var.permission_boundary != null ? format("arn:aws:iam::%s:policy/%s", local.account_id, var.permission_boundary) : null
  # The full ARN of the permission boundary to attach to the role
  permission_boundary_arn = var.permission_boundary_arn == null ? local.permission_boundary_by_name : var.permission_boundary_arn
  # The region where the iam role will be used
  region = var.region != null ? var.region : data.aws_region.current.region
  ## The list of repositories to create roles for
  repositories = compact(concat([var.repository], var.repositories))
  # Find the source control provider from supplied list
  common_provider = lookup(local.common_providers, var.common_provider, null)
  # The selected provider from the supplied list
  selected_provider = var.custom_provider != null ? var.custom_provider : local.common_provider
  # The repository name if it is provided, else an empty string
  repository = try(var.repository, "")
  # Extract just the repository name part of the full path
  repository_name = try(element(split("/", local.repository), length(split("/", local.repository)) - 1), "")
  # Keys to search for in the subject mapping template
  template_keys_regex = "{(repo|type|ref|env)}"
  # The prefix for the terraform state key in the S3 bucket
  tf_state_bucket = format("%s-%s", local.account_id, local.region)
  # The suffix for the terraform state key in the S3 bucket
  tf_state_suffix = var.tf_state_suffix != "" ? format("-%s", var.tf_state_suffix) : ""
  ## ARNs of the counterpart roles in the primary (Azure DevOps hub) account, keyed by role type.
  ## Only populated for the azuredevops provider - see azuredevops_primary_role_account_id.
  ## Skipped when the primary account IS this role's own account: roles being created in the hub
  ## account itself are the primary roles, not spokes being chained into, so no extra trust is needed.
  primary_role_arns = (
    var.azuredevops_primary_role_account_id == null ||
    var.azuredevops_primary_role_account_id == local.account_id
    ) ? {} : {
    rw = format("arn:aws:iam::%s:role/%s", var.azuredevops_primary_role_account_id, local.read_write_role_name)
    ro = format("arn:aws:iam::%s:role/%s", var.azuredevops_primary_role_account_id, local.readonly_role_name)
    sr = format("arn:aws:iam::%s:role/%s", var.azuredevops_primary_role_account_id, local.state_reader_role_name)
  }
  ## True when this role is a spoke chained into from the primary account, rather than the
  ## primary role itself. Spoke roles are only reachable via the primary role's sts:AssumeRole,
  ## so they should not also carry a direct OIDC (sts:AssumeRoleWithWebIdentity) trust statement.
  is_spoke_role = length(local.primary_role_arns) > 0
  ## True when this role IS the primary (hub) role that Azure DevOps federates into directly -
  ## i.e. azuredevops_primary_role_account_id is set and matches this role's own account. The
  ## primary role needs its own sts:AssumeRole permission to chain into the spoke roles that
  ## trust it, granted via the allow_primary_assume_role inline policy on each role type.
  is_primary_role = var.azuredevops_primary_role_account_id != null && var.azuredevops_primary_role_account_id == local.account_id
}
