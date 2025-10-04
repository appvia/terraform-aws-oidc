
locals {
  ## The name of the iam role to create for the readonly - i.e. terraform plans
  readonly_role_name = format("%s-ro", var.name)
  ## The name of the iam role to create for the readwrite - i.e. terraform apply
  readwrite_role_name = var.name
  ## The name of the iam role to create for the state reader - i.e. terraform remote state
  state_reader_role_name = format("%s-sr", var.name)
}

## Craft a trust policy for the readonly role
data "aws_iam_policy_document" "readonly_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.this.arn
      ]
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
        format(replace(local.selected_provider.subject_reader_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_reader_mapping)) : {
            repo = var.repository
          }[v]
        ]...)
      ]
    }
  }
}

## Provision the read only role
resource "aws_iam_role" "ro" {
  name                  = local.readonly_role_name
  description           = var.description
  assume_role_policy    = data.aws_iam_policy_document.readonly_assume_role.json
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_only_max_session_duration
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readonly_role_name })
}

## Create an inline policy for the read only role
resource "aws_iam_role_policy" "tfstate_plan_ro" {
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

## Attach the read only policies to the read only role
resource "aws_iam_role_policy_attachment" "ro" {
  for_each = toset(concat(var.default_managed_policies, var.read_only_policy_arns))

  policy_arn = each.key
  role       = aws_iam_role.ro.name
}

## Craft the trust policy for the read write role
data "aws_iam_policy_document" "readwrite_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.this.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = format("%s:aud", trimprefix(local.selected_provider.url, "https://"))
      values   = concat(local.selected_provider.audiences, var.additional_audiences)
    }

    condition {
      test     = "StringLike"
      variable = format("%s:sub", trimprefix(local.selected_provider.url, "https://"))
      values = compact([
        var.protected_by.branch != null ? format(replace(local.selected_provider.subject_branch_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_branch_mapping)) : {
            repo = var.repository
            type = "branch"
            ref  = var.protected_by.branch
          }[v]
        ]...) : "",

        var.protected_by.environment != null ? format(replace(local.selected_provider.subject_env_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_env_mapping)) : {
            repo = var.repository
            env  = var.protected_by.environment
          }[v]
        ]...) : "",

        var.protected_by.tag != null ? format(replace(local.selected_provider.subject_tag_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_tag_mapping)) : {
            repo = var.repository
            type = "tag"
            ref  = var.protected_by.tag
          }[v]
        ]...) : ""
      ])
    }
  }
}

## Provision the read write role
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

## Provision the inline terraform policy for the rw role
resource "aws_iam_role_policy" "tfstate_apply_rw" {
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

## Attach the read write policies to the read write role
resource "aws_iam_role_policy_attachment" "rw" {
  for_each = toset(concat(var.read_write_policy_arns, var.default_managed_policies))

  policy_arn = each.key
  role       = aws_iam_role.rw.name
}

## Craft the trust policy for the state reader role
data "aws_iam_policy_document" "state_reader_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity",
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.this.arn
      ]
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
  name               = local.state_reader_role_name
  description        = format("Terraform state reader role for '%s' repo", local.repo_name)
  assume_role_policy = data.aws_iam_policy_document.state_reader_assume_role.json
  path               = var.role_path
  tags               = merge(var.tags, { Name = local.state_reader_role_name })
}

## Attach the state reader policies to the state reader role
resource "aws_iam_role_policy" "sr" {
  name   = "tfstate_remote"
  policy = data.aws_iam_policy_document.tfstate_remote.json
  role   = aws_iam_role.sr.id
}
