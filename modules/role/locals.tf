locals {
  common_providers = {
    github = {
      url = "https://token.actions.githubusercontent.com"

      audiences = [
        "sts.amazonaws.com",
      ]

      subject_branch_mapping = "repo:{repo}:ref:refs/heads/{ref}"
      subject_tag_mapping    = "repo:{repo}:ref:refs/tags/{ref}"
    }

    gitlab = {
      url = "https://gitlab.com"

      audiences = [
        "https://gitlab.com",
      ]

      subject_branch_mapping = "project_path:{repo}:ref_type:{type}:ref:{ref}"
      subject_tag_mapping    = "project_path:{repo}:ref_type:{type}:ref:{ref}"
    }
  }
}

locals {
  selected_provider = coalesce(
    var.custom_provider,
    lookup(local.common_providers, var.common_provider, null),
  )

  template_keys_regex = "{(repo|type|ref)}"
}
