locals {
  ## Note: when using multiple repositories, the state key is the iam role name, else it is the repository name
  state_key = length(var.repositories) > 0 ? var.name : local.repository_name
  # The default state key is PREFIX + REPOSITORY_NAME + .tfstate
  default_state_key = format("arn:aws:s3:::%s-tfstate/%s%s.tfstate", local.tf_state_bucket, local.state_key, local.tf_state_suffix)
  # Is the default state lock file key
  default_state_lock_file_key = format("arn:aws:s3:::%s-tfstate/%s%s.tfstate.tflock", local.tf_state_bucket, local.state_key, local.tf_state_suffix)
  # The default state prefix when using the entire namespace is PREFIX + REPOSITORY_NAME + /*
  default_state_namespace_key = format("arn:aws:s3:::%s-tfstate/%s%s/*", local.tf_state_bucket, local.state_key, local.tf_state_suffix)
  # The prefix for the lock file
  default_state_namespace_lock_file_key = format("arn:aws:s3:::%s-tfstate/%s%s/*.tfstate.tflock", local.tf_state_bucket, local.state_key, local.tf_state_suffix)

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
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = local.terraform_state_keys
  }

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = local.terraform_lock_file_keys
  }
}

## Craft an IAM policy with the necessary permissions for terraform apply
data "aws_iam_policy_document" "tfstate_apply" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = local.terraform_state_keys
  }
}


## Craft an IAM policy with the necessary permissions for terraform plan
data "aws_iam_policy_document" "tfstate_plan" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]
}
