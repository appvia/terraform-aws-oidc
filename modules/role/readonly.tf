locals {
  ## The name of the iam role to create for the readonly - i.e. terraform plans
  readonly_role_name = format("%s-ro", var.name)
  ## All the inline policies to attach to the read only role
  read_only_inline_policies = merge(var.read_only_inline_policies, var.default_inline_policies)
  ## All the read only role managed policy ARNs to attach
  read_only_policy_arns = toset(concat(var.default_managed_policies, var.read_only_policy_arns))
  ## Azure DevOps has no branch/tag/environment claim to separate the read-only role's trust
  ## from the read-write role's (see locals.common_providers.azuredevops), so without this the
  ## same service connection would be trusted by both roles. Suffixing with '-ro' (mirroring
  ## readonly_role_name) requires a dedicated Azure DevOps service connection for the read-only
  ## role, giving real separation between plan and apply pipelines.
  readonly_repositories = var.common_provider == "azuredevops" ? [for repo in local.repositories : format("%s-ro", repo)] : local.repositories
}

## Provision the trust policy for the read only role (if enabled)
data "aws_iam_policy_document" "read_only_assume_role" {
  ## Spoke roles (chained into from the primary account) are only reachable via the primary
  ## role's sts:AssumeRole below, so they skip the direct OIDC trust statement entirely
  dynamic "statement" {
    for_each = local.is_spoke_role ? [] : [1]

    content {
      sid     = "AllowAssumeRoleWithWebIdentity"
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
        for_each = toset(local.readonly_repositories)

        content {
          test     = local.selected_provider.subject_condition_test
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

  ## Allow the counterpart read-only role in the primary (Azure DevOps hub) account to
  ## assume this role, chaining cross-account access from the hub's OIDC-federated role
  dynamic "statement" {
    for_each = contains(keys(local.primary_role_arns), "ro") ? [1] : []

    content {
      sid     = "AllowPrimaryRoleAssume"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = [local.primary_role_arns["ro"]]
      }
    }
  }
}

## Craft an IAM policy with the necessary permissions for terraform plan
data "aws_iam_policy_document" "tfstate_plan" {
  source_policy_documents = [
    data.aws_iam_policy_document.base.json,
  ]
}

## Provision a read only role to run terraform plan
resource "aws_iam_role" "ro" {
  count = var.enable_read_only_role ? 1 : 0

  name                  = local.readonly_role_name
  description           = var.description
  assume_role_policy    = data.aws_iam_policy_document.read_only_assume_role.json
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_only_max_session_duration
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readonly_role_name })
}

## Create an inline policy for the read only role
resource "aws_iam_role_policy" "tfstate_plan_ro" {
  count = var.enable_read_only_role && var.enable_terraform_state ? 1 : 0

  name   = "tfstate_plan"
  role   = aws_iam_role.ro[0].id
  policy = data.aws_iam_policy_document.tfstate_plan.json
}

## Provision the inline policies for the read only role
resource "aws_iam_role_policy" "inline_policies_ro" {
  for_each = var.enable_read_only_role ? local.read_only_inline_policies : {}

  name   = each.key
  role   = aws_iam_role.ro[0].id
  policy = each.value
}

## Attach the managed policies to the read only role
resource "aws_iam_role_policy_attachment" "ro" {
  for_each = var.enable_read_only_role ? local.read_only_policy_arns : toset([])

  policy_arn = each.key
  role       = aws_iam_role.ro[0].name
}

## Grant the primary role permission to assume its counterpart read-only role in any spoke
## account (the trust side of this is the spoke's own trust policy - see local.primary_role_arns)
data "aws_iam_policy_document" "allow_primary_assume_role_ro" {
  count = local.is_primary_role && var.enable_read_only_role ? 1 : 0

  statement {
    sid       = "AllowPrimaryAssumeRole"
    actions   = ["sts:AssumeRole"]
    resources = [format("arn:aws:iam::*:role%s%s", var.role_path, local.readonly_role_name)]
  }
}

resource "aws_iam_role_policy" "allow_primary_assume_role_ro" {
  count = local.is_primary_role && var.enable_read_only_role ? 1 : 0

  name   = "allow_primary_assume_role"
  policy = data.aws_iam_policy_document.allow_primary_assume_role_ro[0].json
  role   = aws_iam_role.ro[0].id
}