
locals {
  # The current account ID 
  account_id = data.aws_caller_identity.current.account_id
  ## The common OIDC providers to use 
  common_providers = {
    github = {
      url = "https://token.actions.githubusercontent.com"

      audiences = [
        "sts.amazonaws.com",
      ]

      subject_reader_mapping = "repo:{repo}:*"
      subject_branch_mapping = "repo:{repo}:ref:refs/heads/{ref}"
      subject_tag_mapping    = "repo:{repo}:ref:refs/tags/{ref}"
    }

    gitlab = {
      url = "https://gitlab.com"

      audiences = [
        "https://gitlab.com",
      ]

      subject_reader_mapping = "project_path:{repo}:*"
      subject_branch_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
      subject_tag_mapping    = "project_path:{repo}:ref_type:{type}:ref:{ref}"
    }
  }
  # The devired permission_boundary arn 
  permission_boundary_by_name = var.permission_boundary != null ? format("arn:aws:iam::%s:policy/%s", local.account_id, var.permission_boundary) : null
  # The full ARN of the permission boundary to attach to the role
  permission_boundary_arn = var.permission_boundary_arn == null ? local.permission_boundary_by_name : var.permission_boundary_arn
  # The region where the iam role will be used 
  region = var.region != null ? var.region : data.aws_region.current.name
}

locals {
  selected_provider = coalesce(
    var.custom_provider,
    lookup(local.common_providers, var.common_provider, null),
  )

  # Extract just the repository name part of the full path
  repo_name = element(split("/", var.repository), length(split("/", var.repository)) - 1)

  # Keys to search for in the subject mapping template
  template_keys_regex = "{(repo|type|ref)}"
  # The prefix for the terraform state key in the S3 bucket
  tf_state_prefix = format("%s-%s", local.account_id, local.region)
  tf_state_suffix = var.enable_branch_suffix_on_statefile ? format("-%s", var.protected_branch) : ""
}
