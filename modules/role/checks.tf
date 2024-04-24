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

check "policy_config" {
  assert {
    condition     = !(length(var.read_only_policy_arns) == 0 && length(var.read_only_inline_policies) == 0)
    error_message = "At lest one of 'read_only_policy_arns' or 'read_only_inline_policies' must be specified"
  }

  assert {
    condition     = !(length(var.read_write_policy_arns) == 0 && length(var.read_write_inline_policies) == 0)
    error_message = "At least one of 'read_write_policy_arns' or 'read_write_inline_policies' must be specified"
  }
}

check "permission_boundary" {
  # Either permission_boundary or permission_boundary_arn must be specified
  assert {
    condition     = !(var.permission_boundary == null && var.permission_boundary_arn == null)
    error_message = "Either 'permission_boundary' or 'permission_boundary_arn' must be specified"
  }

  # Both permission_boundary and permission_boundary_arn cannot be specified 
  assert {
    condition     = !(var.permission_boundary != null && var.permission_boundary_arn != null)
    error_message = "Only one of 'permission_boundary' or 'permission_boundary_arn' may be specified"
  }
}
