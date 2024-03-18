check "provider_config" {
  assert {
    condition     = length(var.common_providers) > 0 || length(var.custom_providers) > 0
    error_message = "At least one common_providers must be enabled or custom_providers defined"
  }
}

// Lookup certificate thumbprint
data "tls_certificate" "thumbprint" {
  for_each = {
    for k, v in local.combined_providers :
    k => v if lookup(v, "lookup_thumbprint", true)
  }

  url = each.value["url"]
}

// Create IAM OIDC provider
resource "aws_iam_openid_connect_provider" "this" {
  for_each = local.combined_providers

  url            = each.value["url"]
  client_id_list = each.value["client_id_list"]

  thumbprint_list = concat(
    lookup(local.thumbprints, each.key, []),
    lookup(each.value, "thumbprint_list", []),
  )

  tags = merge({
    Name = lookup(each.value, "name", each.key)
  }, var.tags, lookup(var.provider_tags, each.key, {}))
}
