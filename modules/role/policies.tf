
## Craft a IAM policy for all terraform roles
data "aws_iam_policy_document" "base" {
  statement {
    actions = [
      "s3:ListBucket",
    ]

    resources = [
      format("arn:aws:s3:::%s-tfstate", local.tf_state_prefix),
      format("arn:aws:s3:::%s-tfstate/*", local.tf_state_prefix),
    ]
  }

  statement {
    actions = [
      "s3:HeadObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      format("arn:aws:s3:::%s-tfstate/%s%s.tfstate", local.tf_state_prefix, local.repo_name, local.tf_state_suffix),
    ]
  }
}

## Craft a IAM policy for access to the DynamoDB table 
data "aws_iam_policy_document" "dynamo" {
  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
    ]

    resources = [
      format("arn:aws:dynamodb:*:%s:table/%s-tflock", local.account_id, local.tf_state_prefix),
    ]
  }
}

## Craft an IAM policy with the necessary permissions for terraform apply 
data "aws_iam_policy_document" "tfstate_apply" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
    data.aws_iam_policy_document.dynamo.json,
  ]

  statement {
    actions = [
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = [
      format("arn:aws:s3:::%s-tfstate/%s%s.tfstate", local.tf_state_prefix, local.repo_name, local.tf_state_suffix)
    ]
  }
}


## Craft an IAM policy with the necessary permissions for terraform plan 
data "aws_iam_policy_document" "tfstate_plan" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
    data.aws_iam_policy_document.dynamo.json,
  ]
}

## Craft an IAM policy with the necessary permissions for terraform remote state
data "aws_iam_policy_document" "tfstate_remote" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]
}
