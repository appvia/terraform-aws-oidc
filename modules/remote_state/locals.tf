
locals {
  ## Use provided account ID or default to current account
  account = var.account_id

  ## Use provided region or default to the current region
  region = coalesce(var.region, data.aws_region.current.region)

  ## Terraform state bucket name
  tf_state_bucket = format("%s-%s-tfstate", local.account, local.region)

  ## Terraform state bucket key
  tf_state_key = format("%s.tfstate", var.repository)

  ## Remote state role
  role_arn = var.reader_role != null ? format("arn:aws:iam::%s:role/%s", local.account, var.reader_role) : format("arn:aws:iam::%s:role/%s-sr", local.account, var.repository)
}

