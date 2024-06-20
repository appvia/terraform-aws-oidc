// The following locals contain the configuration for built-in well-known OIDC providers
locals {
  // Configuration for common built-in providers
  common_providers = {
    // Public GitHub OIDC
    github = {
      name = "GitHub"
      url  = "https://token.actions.githubusercontent.com"
      client_id_list = [
        "sts.amazonaws.com",
      ]
    }

    // Public GitLab OIDC
    gitlab = {
      name = "GitLab"
      url  = "https://gitlab.com"
      client_id_list = [
        "https://gitlab.com",
      ]
    }

    // Public Bitbucket OIDC
    bitbucket = {
      name = "Bitbucket"
      url  = "https://api.bitbucket.org/2.0/workspaces/${var.workspace_name}/pipelines-config/identity/oidc"
      client_id_list = [
        "ari:cloud:bitbucket::workspace/${var.workspace_uuid}",
      ]
    }
  }
}

// The following locals contain run-time computed values and should not be changed
locals {
  // Map of common providers and settings for providers
  // that have been enabled by the module caller
  normalised_common_providers = {
    for k, v in local.common_providers : k => v
    if contains([
      for p in var.common_providers : lower(trimspace(p))
    ], k)
  }

  // Cleanup up the custom providers and normalize the key
  normalised_custom_providers = {
    for k, v in var.custom_providers :
    trimspace(lower(k)) => merge(v, {
      name = coalesce(v.name, k)
    })
  }

  // Combined providers to create
  combined_providers = merge(
    local.normalised_common_providers,
    local.normalised_custom_providers,
  )

  // Map of provider names to certificate thumbprints
  thumbprints = {
    for k, v in data.tls_certificate.thumbprint :
    k => [
      element(v.certificates, 0).sha1_fingerprint,
    ]
  }
}
