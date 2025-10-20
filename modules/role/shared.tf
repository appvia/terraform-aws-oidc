#
## Terraform state reader role
#
locals {
  ## Indicates if we should create a state reader role
  enable_state_reader = length(var.shared_repositories) > 0
  ## The name of the iam role to create for the state reader - i.e. terraform remote state
  state_reader_role_name = format("%s-sr", var.name)
}

## Provision the policy for the state reader role
data "aws_iam_policy_document" "tfstate_remote" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]
}

## Craft the trust policy for the state reader role
data "aws_iam_policy_document" "sr_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:aud", trimprefix(local.selected_provider.url, "https://"))
      values   = concat(local.selected_provider.audiences, var.additional_audiences)
    }

    condition {
      test     = "StringLike"
      variable = format("%s:sub", trimprefix(local.selected_provider.url, "https://"))
      values = [
        for repo in var.shared_repositories :
        format(replace(local.selected_provider.subject_reader_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_reader_mapping)) : {
            repo = repo
          }[v]
        ]...)
      ]
    }
  }
}

## Provision the state reader role
resource "aws_iam_role" "sr" {
  count = local.enable_state_reader ? 1 : 0

  name               = local.state_reader_role_name
  description        = format("Terraform state reader roles for '%s' repositories", var.name)
  assume_role_policy = data.aws_iam_policy_document.sr_assume_role.json
  path               = var.role_path
  tags               = merge(var.tags, { Name = local.state_reader_role_name })
}

## Attach the state reader policies to the state reader role
resource "aws_iam_role_policy" "sr" {
  count = local.enable_state_reader ? 1 : 0

  name   = "tfstate_remote"
  policy = data.aws_iam_policy_document.tfstate_remote.json
  role   = aws_iam_role.sr[0].id
}
