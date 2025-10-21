locals {
  ## The name of the iam role to create for the readwrite - i.e. terraform apply
  readwrite_role_name = var.name
}

## Craft the trust policy for the read write role
data "aws_iam_policy_document" "readwrite_assume_role" {
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

    dynamic "condition" {
      for_each = toset(local.repositories)

      content {
        test     = "StringLike"
        variable = format("%s:sub", trimprefix(local.selected_provider.url, "https://"))
        values = compact([
          var.protected_by.branch != null ? format(replace(local.selected_provider.subject_branch_mapping, format("/%s/", local.template_keys_regex), "%s"), [
            for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_branch_mapping)) : {
              repo = condition.value
              type = "branch"
              ref  = var.protected_by.branch
            }[v]
          ]...) : "",

          var.protected_by.environment != null ? format(replace(local.selected_provider.subject_env_mapping, format("/%s/", local.template_keys_regex), "%s"), [
            for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_env_mapping)) : {
              repo = condition.value
              env  = var.protected_by.environment
            }[v]
          ]...) : "",

          var.protected_by.tag != null ? format(replace(local.selected_provider.subject_tag_mapping, format("/%s/", local.template_keys_regex), "%s"), [
            for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_tag_mapping)) : {
              repo = condition.value
              type = "tag"
              ref  = var.protected_by.tag
            }[v]
          ]...) : ""
        ])
      }
    }
  }
}

## Provision the read write role used for terraform apply
resource "aws_iam_role" "rw" {
  name                  = local.readwrite_role_name
  description           = var.description
  assume_role_policy    = data.aws_iam_policy_document.readwrite_assume_role.json
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_write_max_session_duration
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readwrite_role_name })
}

## Create an inline policy for the read write role to allow access to the terraform state
resource "aws_iam_role_policy" "tfstate_apply_rw" {
  count = var.enable_terraform_state ? 1 : 0

  name   = "tfstate_apply"
  policy = data.aws_iam_policy_document.tfstate_apply.json
  role   = aws_iam_role.rw.id
}

## Provision the inline policies for the read write role
resource "aws_iam_role_policy" "inline_policies_rw" {
  for_each = merge(var.read_write_inline_policies, var.default_inline_policies)

  name   = each.key
  policy = each.value
  role   = aws_iam_role.rw.id
}

## Attach the managed policies to the read write role
resource "aws_iam_role_policy_attachment" "rw" {
  for_each = toset(compact(concat(var.read_write_policy_arns, var.default_managed_policies)))

  policy_arn = each.key
  role       = aws_iam_role.rw.name
}
