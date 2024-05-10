module "common_provider_example" {
  source = "../../modules/role"

  // Basic role details
  name        = "test-common-role"
  description = "Creates a role using the GitHub OIDC provider"

  // Name of the common OIDC provider to use
  common_provider = "github"
  // Relative path to the repository for the given provider
  repository = "appvia/something"
  // Set the permission boundary for both the read-only and read-write role
  permission_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  // List of policy ARNs to attach to the read-only role
  read_only_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
  ]
  // List of policy ARNs to attach to the read-write role
  read_write_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]

  read_only_inline_policies = {
    "additional" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
          ]
          Resource = "*"
        },
      ]
    })
  }

  read_write_inline_policies = {
    "additional" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:ListBucket",
          ]
          Resource = "*"
        },
      ]
    })
  }

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
