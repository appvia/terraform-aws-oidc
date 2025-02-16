
locals {
  ## Use provided account ID or default to current account
  account = var.account_id

  ## Use provided region or default to the current region
  region = coalesce(var.region, data.aws_region.current.name)

  ## Terraform state bucket name
  tf_state_bucket = format("%s-%s", local.account, local.region)

  ## Remote state role
  role_arn = coalesce(var.reader_role_arn, format("arn:aws:iam::%s:role/%s-sr", var.account_id, var.repository))
}

