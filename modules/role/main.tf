check "provider_config" {
  assert {
    condition     = !(var.common_provider == "" && var.custom_provider == null)
    error_message = "Either 'common_provider' or 'custom_provider' must be specified"
  }

  assert {
    condition     = !(var.common_provider != "" && var.custom_provider != null)
    error_message = "Only one of 'common_provider' or 'custom_provider' may be specified"
  }
}

data "aws_iam_openid_connect_provider" "this" {
  url = local.selected_provider.url
}

data "aws_iam_policy_document" "ro" {
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
        for repo in var.repositories :
        format(replace(local.selected_provider.subject_branch_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_branch_mapping)) : {
            repo = repo
            type = "branch"
            ref  = var.unprotected_branch
          }[v]
        ]...)
      ]
    }
  }
}

resource "aws_iam_role" "ro" {
  name               = format("%s-ro", var.name)
  path               = var.role_path
  description        = var.description
  assume_role_policy = data.aws_iam_policy_document.ro.json

  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_only_max_session_duration
  permissions_boundary  = var.permissions_boundary

  dynamic "inline_policy" {
    for_each = var.read_only_inline_policies

    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }

  tags = merge(var.tags, var.read_only_tags, {
    Name = format("%s-ro", var.name)
  })
}

resource "aws_iam_role_policy_attachment" "ro" {
  policy_arn = aws_iam_policy.tfstate_plan.arn
  role       = aws_iam_role.ro.name
}

data "aws_iam_policy_document" "rw" {
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
        for repo in var.repositories :
        format(replace(local.selected_provider.subject_branch_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_branch_mapping)) : {
            repo = repo
            type = "branch"
            ref  = var.protected_branch
          }[v]
        ]...)
      ]
    }

    condition {
      test     = "StringLike"
      variable = format("%s:sub", trimprefix(local.selected_provider.url, "https://"))
      values = [
        for repo in var.repositories :
        format(replace(local.selected_provider.subject_tag_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_tag_mapping)) : {
            repo = repo
            type = "tag"
            ref  = var.protected_tag
          }[v]
        ]...)
      ]
    }
  }
}

resource "aws_iam_role" "rw" {
  name               = format("%s-rw", var.name)
  path               = var.role_path
  description        = var.description
  assume_role_policy = data.aws_iam_policy_document.rw.json

  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_write_max_session_duration
  permissions_boundary  = var.permissions_boundary

  dynamic "inline_policy" {
    for_each = var.read_write_inline_policies

    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }

  tags = merge(var.tags, var.read_write_tags, {
    Name = format("%s-rw", var.name)
  })
}

resource "aws_iam_role_policy_attachment" "rw" {
  policy_arn = aws_iam_policy.tfstate_apply.arn
  role       = aws_iam_role.rw.name
}
