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
  ## Spoke roles (chained into from the primary account) are only reachable via the primary
  ## role's sts:AssumeRole below, so they skip the direct OIDC trust statement entirely
  dynamic "statement" {
    for_each = local.is_spoke_role ? [] : [1]

    content {
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
        test     = local.selected_provider.subject_condition_test
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

  ## Allow the counterpart state-reader role in the primary (Azure DevOps hub) account to
  ## assume this role, chaining cross-account access from the hub's OIDC-federated role
  dynamic "statement" {
    for_each = contains(keys(local.primary_role_arns), "sr") ? [1] : []

    content {
      sid     = "AllowPrimaryRoleAssume"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = [local.primary_role_arns["sr"]]
      }
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

## Grant the primary role permission to assume its counterpart state-reader role in any spoke
## account (the trust side of this is the spoke's own trust policy - see local.primary_role_arns)
data "aws_iam_policy_document" "allow_primary_assume_role_sr" {
  count = local.is_primary_role && local.enable_state_reader ? 1 : 0

  statement {
    sid       = "AllowPrimaryAssumeRole"
    actions   = ["sts:AssumeRole"]
    resources = [format("arn:aws:iam::*:role/%s", local.state_reader_role_name)]
  }
}

resource "aws_iam_role_policy" "allow_primary_assume_role_sr" {
  count = local.is_primary_role && local.enable_state_reader ? 1 : 0

  name   = "allow_primary_assume_role"
  policy = data.aws_iam_policy_document.allow_primary_assume_role_sr[0].json
  role   = aws_iam_role.sr[0].id
}
