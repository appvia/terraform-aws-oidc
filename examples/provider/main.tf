module "common_provider_example" {
  source  = "appvia/oidc/aws//modules/provider"
  version = "0.0.16"

  // List of common OIDC providers to enable
  common_providers = [
    "github",
    "gitlab",
  ]

  // Per-provider tags to apply to the OIDC provider
  provider_tags = {
    github = {
      Provider = "GitHub Only Tag"
    }

    gitlab = {
      Provider = "GitLab Only Tag"
    }
  }

  // Tags to apply to all providers
  tags = {
    Name = "Example Common Provider"
  }
}

module "custom_provider_example" {
  source  = "appvia/oidc/aws//modules/provider"
  version = "0.0.16"

  // Custom provider configuration
  custom_providers = {
    gitlab = {
      // Friendly name of the provider
      name = "GitLab"

      // Root URL of the OpenID Connect identity provider
      url = "https://gitlab.example.org"

      // Client ID (audience)
      client_id_list = [
        "https://gitlab.example.org",
      ]

      // List of certificate thumbprints for the provider.
      // If these are not specified, the module will attempt
      // to look up the current thumbprint automatically.
      thumbprint_list = [
        "92bed42098f508e91f47f321f6607e4b",
      ]
    }
  }

  // Tags to provide to all providers
  tags = {
    Name = "Example Custom Provider"
  }
}
