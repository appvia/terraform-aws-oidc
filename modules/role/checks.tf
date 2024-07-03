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

check "protected_by_config" {
  assert {
    condition     = !(var.protected_by.branch == null && var.protected_by.environment == null && var.protected_by.tag == null)
    error_message = "At least one of 'protected_by.branch', 'protected_by.environment', or 'protected_by.tag' must be specified"
  }

  assert {
    condition     = !(var.protected_by.branch == "")
    error_message = "'protected_by.branch' must not be an empty string"
  }

  assert {
    condition     = !(var.protected_by.environment == "")
    error_message = "'protected_by.environment' must not be an empty string"
  }

  assert {
    condition     = !(var.protected_by.tag == "")
    error_message = "'protected_by.tag' must not be an empty string"
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
