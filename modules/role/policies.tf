locals {
  ## Note: an explicit tf_state_key always wins, else when using multiple repositories, the state key is
  ## the iam role name, else it is the repository name
  state_key = var.tf_state_key != null ? var.tf_state_key : (length(var.repositories) > 0 ? var.name : local.repository_name)
  ## When tf_state_key is set the key is used verbatim, i.e. no suffix and no .tfstate extension
  state_key_suffix = var.tf_state_key != null ? "" : local.tf_state_suffix
  # The extension of the state file, only added when the state key is derived
  state_file_extension = var.tf_state_key != null ? "" : ".tfstate"
  # The default state key is PREFIX + REPOSITORY_NAME + .tfstate, or the tf_state_key verbatim
  default_state_key = format("arn:aws:s3:::%s-tfstate/%s%s%s", local.tf_state_bucket, local.state_key, local.state_key_suffix, local.state_file_extension)
  # Is the default state lock file key, i.e. the state key + .tflock
  default_state_lock_file_key = format("%s.tflock", local.default_state_key)
  # The default state prefix when using the entire namespace is PREFIX + REPOSITORY_NAME + /*
  default_state_namespace_key = format("arn:aws:s3:::%s-tfstate/%s%s/*", local.tf_state_bucket, local.state_key, local.state_key_suffix)
  # The prefix for the lock file
  default_state_namespace_lock_file_key = format("arn:aws:s3:::%s-tfstate/%s%s/*%s.tflock", local.tf_state_bucket, local.state_key, local.state_key_suffix, local.state_file_extension)

  # Is the prefix for the terraform state key, by default this is PREFIX + REPOSITORY_NAME + .tfstate.
  # However, when the entire namespace is enabled, this is PREFIX + REPOSITORY_NAME + /*
  terraform_state_keys = compact([
    local.default_state_key,
    local.default_state_lock_file_key,
    (var.enable_key_namespace ? local.default_state_namespace_key : null),
    (var.enable_key_namespace ? local.default_state_namespace_lock_file_key : null),
  ])

  terraform_lock_file_keys = compact([
    local.default_state_lock_file_key,
    (var.enable_key_namespace ? local.default_state_namespace_lock_file_key : null),
  ])
}

## Craft a IAM policy for all terraform roles
data "aws_iam_policy_document" "base" {
  statement {
    sid = "AllowS3ListBucket"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      format("arn:aws:s3:::%s-tfstate", local.tf_state_bucket),
      format("arn:aws:s3:::%s-tfstate/*", local.tf_state_bucket),
    ]
  }

  ## If the entire namespace is not enabled, we need to add the specific object permissions
  statement {
    sid = "AllowS3GetObject"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = local.terraform_state_keys
  }

  statement {
    sid = "AllowS3LockFileObject"
    actions = [
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = local.terraform_lock_file_keys
  }
}

