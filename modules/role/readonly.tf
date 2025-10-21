#
## Read only role - used for terraform plan
#

locals {
  ## The name of the iam role to create for the readonly - i.e. terraform plans
  readonly_role_name = format("%s-ro", var.name)
}

## Provision the trust policy for the read only role
data "aws_iam_policy_document" "ro_assume_role" {
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

    ## Support the repositories variable
    dynamic "condition" {
      for_each = toset(local.repositories)

      content {
        test     = "StringLike"
        variable = format("%s:sub", trimprefix(local.selected_provider.url, "https://"))
        values = [
          format(replace(local.selected_provider.subject_reader_mapping, format("/%s/", local.template_keys_regex), "%s"), [
            for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_reader_mapping)) : {
              repo = condition.value
            }[v]
          ]...)
        ]
      }
    }
  }
}

## Provision a read only role to run terraform plan
resource "aws_iam_role" "ro" {
  name                  = local.readonly_role_name
  description           = var.description
  assume_role_policy    = data.aws_iam_policy_document.ro_assume_role.json
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_only_max_session_duration
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readonly_role_name })
}

## Create an inline policy for the read only role
resource "aws_iam_role_policy" "tfstate_plan_ro" {
  count = var.enable_terraform_state ? 1 : 0

  name   = "tfstate_plan"
  role   = aws_iam_role.ro.id
  policy = data.aws_iam_policy_document.tfstate_plan.json
}

## Provision the inline policies for the read only role
resource "aws_iam_role_policy" "inline_policies_ro" {
  for_each = merge(var.read_only_inline_policies, var.default_inline_policies)

  name   = each.key
  role   = aws_iam_role.ro.id
  policy = each.value
}

## Attach the managed policies to the read only role
resource "aws_iam_role_policy_attachment" "ro" {
  for_each = toset(concat(var.default_managed_policies, var.read_only_policy_arns))

  policy_arn = each.key
  role       = aws_iam_role.ro.name
}
