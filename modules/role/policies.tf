// Base policy shared by all roles
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
      format("arn:aws:s3:::%s-tfstate/%s.tfstate", local.tf_state_prefix, local.repo_name)
    ]
  }
}

// DynamoDB policy shared by terraform roles
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

// Policy for terraform plan role
data "aws_iam_policy_document" "tfstate_plan" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
    data.aws_iam_policy_document.dynamo.json,
  ]
}

resource "aws_iam_policy" "tfstate_plan" {
  name        = format("%s-tfstate-plan", var.name)
  description = "Policy allowing read access to the Terraform state bucket and DynamoDB table for the ${var.name} role"
  policy      = data.aws_iam_policy_document.tfstate_plan.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "tfstate_plan" {
  policy_arn = aws_iam_policy.tfstate_plan.arn
  role       = aws_iam_role.ro.name
}

// Policy for terraform apply role
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
      format("arn:aws:s3:::%s-tfstate/%s.tfstate", local.tf_state_prefix, local.repo_name)
    ]
  }
}

resource "aws_iam_policy" "tfstate_apply" {
  name        = format("%s-tfstate-apply", var.name)
  description = "Policy allowing write access to the Terraform state bucket and DynamoDB table for the ${var.name} role"
  policy      = data.aws_iam_policy_document.tfstate_apply.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "tfstate_apply" {
  policy_arn = aws_iam_policy.tfstate_apply.arn
  role       = aws_iam_role.rw.name
}

// Policy for terraform remote state reading
data "aws_iam_policy_document" "tfstate_remote" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]
}

resource "aws_iam_policy" "tfstate_remote" {
  name        = format("%s-tfstate-remote", var.name)
  description = "Policy allowing read access to the Terraform state bucket for the ${var.name} role"
  policy      = data.aws_iam_policy_document.tfstate_remote.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "tfstate_remote" {
  policy_arn = aws_iam_policy.tfstate_remote.arn
  role       = aws_iam_role.sr.name
}
