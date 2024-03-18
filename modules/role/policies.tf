data "aws_iam_policy_document" "tfstate_plan" {
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
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      format("arn:aws:s3:::%s-tfstate/%s.tfstate", local.tf_state_prefix, var.repository)
    ]
  }
}

resource "aws_iam_policy" "tfstate_plan" {
  name        = format("%s-tfstate-plan", var.name)
  description = "Policy allowing read access to the Terraform state bucket and DynamoDB table for the ${var.name} role"
  policy      = data.aws_iam_policy_document.tfstate_plan.json
}

data "aws_iam_policy_document" "tfstate_apply" {
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
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]

    resources = [
      format("arn:aws:s3:::%s-tfstate/%s.tfstate", local.tf_state_prefix, var.repository)
    ]
  }
}

resource "aws_iam_policy" "tfstate_apply" {
  name        = format("%s-tfstate-apply", var.name)
  description = "Policy allowing write access to the Terraform state bucket and DynamoDB table for the ${var.name} role"
  policy      = data.aws_iam_policy_document.tfstate_apply.json
}
