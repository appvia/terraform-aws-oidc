
## Provision a role with multiple repositories
module "repository" {
  source = "../../modules/role"

  name                 = "lz-aws-landing-zones-platform"
  description          = "Creates a role with multiple repositories"
  tags                 = {}
  enable_key_namespace = true
  repositories = [
    "appvia/lz-aws-platform-landing-zones",
    "appvia/lz-aws-application-landing-zones",
    "appvia/lz-aws-sandbox-landing-zones",
  ]
  permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  read_only_policy_arns   = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  read_write_policy_arns  = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
