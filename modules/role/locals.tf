locals {
  # The current account ID, if not provided
  account_id = var.account_id != null ? var.account_id : data.aws_caller_identity.current.account_id
  ## The common OIDC providers to use 
  common_providers = {
    github = {
      url = "https://token.actions.githubusercontent.com"

      audiences = [
        "sts.amazonaws.com",
      ]

      subject_reader_mapping = "repo:{repo}:*"
      subject_branch_mapping = "repo:{repo}:ref:refs/heads/{ref}"
      subject_env_mapping    = "repo:{repo}:environment:{env}"
      subject_tag_mapping    = "repo:{repo}:ref:refs/tags/{ref}"
    }

    gitlab = {
      url = "https://gitlab.com"

      audiences = [
        "https://gitlab.com",
      ]

      subject_reader_mapping = "project_path:{repo}:*"
      subject_branch_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
      # GitLab includes environment info as separate JWT claims (environment, deployment_tier) 
      # rather than in the subject claim. Need to use custom claim conditions for environment-based access.
      # setting this to empty string to avoid null value error for now.
      subject_env_mapping = ""
      subject_tag_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
    }
  }
  # The devired permission_boundary arn 
  permission_boundary_by_name = var.permission_boundary != null ? format("arn:aws:iam::%s:policy/%s", local.account_id, var.permission_boundary) : null
  # The full ARN of the permission boundary to attach to the role
  permission_boundary_arn = var.permission_boundary_arn == null ? local.permission_boundary_by_name : var.permission_boundary_arn
  # The region where the iam role will be used 
  region = var.region != null ? var.region : data.aws_region.current.region
  ## The list of repositories to create roles for
  repositories = compact(concat([var.repository], []))
  # Find the source control provider from supplied list
  common_provider = lookup(local.common_providers, var.common_provider, null)
  # The selected provider from the supplied list
  selected_provider = var.custom_provider != null ? var.custom_provider : local.common_provider
  # Extract just the repository name part of the full path
  repository_name = element(split("/", var.repository), length(split("/", var.repository)) - 1)
  # Keys to search for in the subject mapping template
  template_keys_regex = "{(repo|type|ref|env)}"
  # The prefix for the terraform state key in the S3 bucket
  tf_state_bucket = format("%s-%s", local.account_id, local.region)
  # The suffix for the terraform state key in the S3 bucket
  tf_state_suffix = var.tf_state_suffix != "" ? format("-%s", var.tf_state_suffix) : ""
}
