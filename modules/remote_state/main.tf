locals {
  // Use provided account ID or default to current account
  account = coalesce(var.account_id, data.aws_caller_identity.current.account_id)

  // Use provided region or default to the current region
  region = coalesce(var.region, data.aws_region.current.name)

  // Terraform state bucket name
  tf_state_bucket = format("%s-%s", var.account_id, local.region)
}

data "terraform_remote_state" "this" {
  backend = "s3"

  config = {
    bucket = format("arn:aws:s3:::%s-tfstate", local.tf_state_bucket)
    key    = format("%s.tfstate", var.repository)

    assume_role_with_web_identity = {
      role_arn                = var.reader_role_arn
      web_identity_token_file = var.web_identity_token_file
    }
  }
}
