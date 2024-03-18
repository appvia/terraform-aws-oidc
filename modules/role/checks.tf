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
