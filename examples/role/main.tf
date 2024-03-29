module "common_provider_example" {
  source  = "appvia/oidc/aws//modules/role"
  version = "0.0.16"

  // Basic role details
  name        = "test-common-role"
  description = "Creates a role using the GitHub OIDC provider"

  // Name of the common OIDC provider to use
  common_provider = "github"

  // Relative path to the repository for the given provider
  repository = "appvia/something"

  // Set the permission boundary for both the read-only and read-write role
  permission_boundary = "AdministratorAccess"

  // List of policy ARNs to attach to the read-only role
  read_only_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]

  // List of policy ARNs to attach to the read-write role
  read_write_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  // List of additional repositories which will be able to read the remote
  // terraform state, created by this role.
  shared_repositories = [
    "appvia/repo-1",
    "appvia/repo-2",
  ]

  // Tags to apply to the role
  tags = {
    Name = "Example Common Provider"
  }
}