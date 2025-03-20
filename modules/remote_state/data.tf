
## Lookup current region
data "aws_region" "current" {}

## Retrieve the remote state
data "terraform_remote_state" "this" {
  backend = "s3"

  config = {
    bucket = local.tf_state_bucket
    key    = local.tf_state_key

    ## We can assume via the web identity token if it is provided
    assume_role_with_web_identity = var.web_identity_token_file != null ? {
      role_arn                = local.role_arn
      web_identity_token_file = var.web_identity_token_file
    } : null

    ## We can assume via the reader role if no web identity token is provided
    assume_role = var.web_identity_token_file == null ? {
      role_arn = local.role_arn
    } : null
  }
}
