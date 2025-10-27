output "providers" {
  description = "Map of created IAM OIDC providers"
  value = {
    for k, v in aws_iam_openid_connect_provider.this :
    k => {
      arn  = v.arn
      name = local.combined_providers[k].name
    }
  }
}
