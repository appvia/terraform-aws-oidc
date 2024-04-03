
locals {
  ## The name of the iam role to create for the readonly 
  readonly_role_name = format("%s-ro", var.name)
  ## The name of the iam role to create for the readwrite
  readwrite_role_name = var.name
  ## The name of the iam role to create for the state reader 
  state_reader_role_name = format("%s-sr", var.name)
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
  assume_role_policy    = data.aws_iam_policy_document.ro.json
  description           = var.description
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_only_max_session_duration
  name                  = local.readonly_role_name
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readonly_role_name })

  dynamic "inline_policy" {
    for_each = var.read_only_inline_policies

    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }
}

## Attach the read only policies to the read only role
resource "aws_iam_role_policy_attachment" "ro" {
  for_each = toset(var.read_only_policy_arns)

  policy_arn = each.key
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
        format(replace(local.selected_provider.subject_branch_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_branch_mapping)) : {
            repo = var.repository
            type = "branch"
            ref  = var.protected_branch
          }[v]
        ]...),

        format(replace(local.selected_provider.subject_tag_mapping, format("/%s/", local.template_keys_regex), "%s"), [
          for v in flatten(regexall(local.template_keys_regex, local.selected_provider.subject_tag_mapping)) : {
            repo = var.repository
            type = "tag"
            ref  = var.protected_tag
          }[v]
        ]...)
      ]
    }
  }
}

resource "aws_iam_role" "rw" {
  assume_role_policy    = data.aws_iam_policy_document.rw.json
  description           = var.description
  force_detach_policies = var.force_detach_policies
  max_session_duration  = var.read_write_max_session_duration
  name                  = local.readwrite_role_name
  path                  = var.role_path
  permissions_boundary  = local.permission_boundary_arn
  tags                  = merge(var.tags, { Name = local.readwrite_role_name })

  dynamic "inline_policy" {
    for_each = var.read_write_inline_policies

    content {
      name   = inline_policy.key
      policy = inline_policy.value
    }
  }
}

resource "aws_iam_role_policy_attachment" "rw" {
  for_each = toset(var.read_write_policy_arns)

  policy_arn = each.key
  role       = aws_iam_role.rw.name
}

data "aws_iam_policy_document" "sr" {
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

resource "aws_iam_role" "sr" {
  assume_role_policy = data.aws_iam_policy_document.sr.json
  description        = format("Terraform state reader role for '%s' repo", local.repo_name)
  name               = local.state_reader_role_name
  path               = var.role_path
  tags               = merge(var.tags, { Name = local.state_reader_role_name })
}
