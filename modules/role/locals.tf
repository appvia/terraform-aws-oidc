locals {
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
  # The full ARN of the permission boundary to attach to the role
  permission_boundary_arn = format("arn:aws:iam::%s:policy/%s", data.aws_caller_identity.current.account_id, var.permission_boundary)
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

  account_id      = data.aws_caller_identity.current.account_id
  tf_state_prefix = format("%s-%s", local.account_id, data.aws_region.current.name)
}
