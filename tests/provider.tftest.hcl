mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [
        {
          sha1_fingerprint = "1234567890abcdef1234567890abcdef12345678"
        }
      ]
    }
  }
}

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "common_providers" {
  command = plan

  module {
    source = "./modules/provider"
  }

  variables {
    common_providers = [
      "github",
      "gitlab",
    ]
  }

  assert {
    condition     = contains(keys(aws_iam_openid_connect_provider.this), "github")
    error_message = "github provider expected to be defined"
  }

  assert {
    condition     = contains(keys(aws_iam_openid_connect_provider.this), "gitlab")
    error_message = "gitlab provider expected to be defined"
  }

  assert {
    condition     = contains(keys(data.tls_certificate.thumbprint), "github")
    error_message = "github automatic thumbprint expected to be defined"
  }

  assert {
    condition     = contains(keys(data.tls_certificate.thumbprint), "gitlab")
    error_message = "gitlab automatic thumbprint expected to be defined"
  }
}

run "custom_providers_with_lookup" {
  command = plan

  module {
    source = "./modules/provider"
  }

  variables {
    custom_providers = {
      github = {
        name = "CustomGitHub"
        url  = "https://token.actions.githubusercontent.com"
        client_id_list = [
          "sts.amazonaws.com"
        ]
      }
    }
  }

  assert {
    condition     = contains(keys(aws_iam_openid_connect_provider.this), "github")
    error_message = "github provider expected to be defined"
  }

  assert {
    condition     = contains(keys(data.tls_certificate.thumbprint), "github")
    error_message = "github automatic thumbprint expected to be defined"
  }
}

run "custom_providers_without_lookup" {
  command = plan

  module {
    source = "./modules/provider"
  }

  variables {
    custom_providers = {
      custom_github = {
        name = "CustomGitHub"
        url  = "https://token.actions.githubusercontent.com"
        client_id_list = [
          "sts.amazonaws.com"
        ]
        lookup_thumbprint = false
      }
    }
  }

  assert {
    condition     = contains(keys(aws_iam_openid_connect_provider.this), "custom_github")
    error_message = "custom provider expected to be defined"
  }

  assert {
    condition     = !contains(keys(data.tls_certificate.thumbprint), "custom_github")
    error_message = "custom provider not expected to do certificate thumbprint lookup"
  }
}

run "provider_tags" {
  command = plan

  module {
    source = "./modules/provider"
  }

  variables {
    common_providers = [
      "github",
    ]

    custom_providers = {
      gitlab = {
        name = "GitLab"
        url  = "https://gitlab.com"
        client_id_list = [
          "https://gitlab.com"
        ]
      }
    }
  }

  assert {
    condition     = aws_iam_openid_connect_provider.this["github"].tags.Name == "GitHub"
    error_message = "expected GitHub provider to have matching name tag"
  }

  assert {
    condition     = aws_iam_openid_connect_provider.this["gitlab"].tags.Name == "GitLab"
    error_message = "expected custom GitLab provider to have matching name tag"
  }
}

run "provider_no_tags" {
  command = plan

  module {
    source = "./modules/provider"
  }

  variables {
    custom_providers = {
      gitlab = {
        url = "https://gitlab.com"
        client_id_list = [
          "https://gitlab.com"
        ]
      }
    }
  }

  assert {
    condition     = aws_iam_openid_connect_provider.this["gitlab"].tags.Name == "gitlab"
    error_message = "expected custom provider with no name set to have key as Name tag"
  }
}
