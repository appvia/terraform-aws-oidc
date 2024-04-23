
## Retrieve the current AWS account identity 
data "aws_caller_identity" "current" {}

## Retrieve the current AWS region
data "aws_region" "current" {}

## Retrieve the OpenID Connect provider ARN 
data "aws_iam_openid_connect_provider" "this" {
  url = local.selected_provider.url
}
