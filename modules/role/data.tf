
## Retrieve the current AWS account identity 
data "aws_caller_identity" "current" {}
## Retrieve the current AWS region
data "aws_region" "current" {}
