variable "name" {
  description = "Name of the role to create"
  type        = string
}

variable "account_id" {
  description = "The AWS account ID to create the role in"
  type        = string
  default     = null
}

variable "enable_terraform_state" {
  description = "Indicates we should create the terraform state and lock file permissions"
  type        = bool
  default     = true
}

variable "enable_key_namespace" {
  description = "Amended the S3 permissions to write to entire key space i.e <REPOSITORY_NAME>/*"
  type        = bool
  default     = false
}

variable "enable_read_only_role" {
  description = "Indicates we should create a read-only role in addition to the read-write role"
  type        = bool
  default     = true
}

variable "default_managed_policies" {
  description = "List of IAM managed policy ARNs to attach to this role/s, both read-only and read-write"
  type        = list(string)
  default     = []
}

variable "default_inline_policies" {
  description = "Inline policies map with policy name as key and json as value, attached to both read-only and read-write roles"
  type        = map(string)
  default     = {}
}

variable "description" {
  description = "Description of the role being created"
  type        = string
}

variable "region" {
  description = "The region in which the role will be used (defaulting to the provider region)"
  type        = string
  default     = null
}

variable "common_provider" {
  description = "The name of a common OIDC provider to be used as the trust for the role"
  type        = string
  default     = "github"

  validation {
    condition     = contains(["github", "gitlab", "azuredevops"], var.common_provider)
    error_message = "Allowed values for common_provider are github, gitlab or azuredevops."
  }
}

variable "azuredevops_organization_id" {
  description = "The Azure DevOps organization ID (GUID, found under Organization Settings) used to build the OIDC issuer URL (https://vstoken.dev.azure.com/<organization_id>). Required when common_provider is 'azuredevops' and custom_provider is not set. Pass the repository/repositories variables as '<organisation-name>/<project-name>/<service-connection-name>'."
  type        = string
  default     = null
}

variable "azuredevops_primary_role_account_id" {
  description = "Account ID of the 'primary' role set (matching this module's role names) that Azure DevOps federates into directly via OIDC. When set, an additional trust statement is added to each role created here (read-write, read-only, state reader) allowing its counterpart in that account to assume it via sts:AssumeRole. Used to chain from a hub account (where the Azure DevOps OIDC provider/service connections are configured) into spoke accounts, e.g. a finops account role trusting the equivalent management-account role. Only valid when common_provider is 'azuredevops', since GitHub/GitLab OIDC providers are configured per-account and don't need this chaining."
  type        = string
  default     = null

}

variable "azuredevops_assume_roles" {
  description = "List of IAM role names in the azuredevops_primary_role_account_id account to trust via sts:AssumeRole. Each name is combined with azuredevops_primary_role_account_id to build the full ARN: the read-write role trusts the name as given, the read-only role trusts the name suffixed with '-ro' (matching this module's own read-only naming convention). Only applies to the read-write and read-only roles - the state reader role (shared_repositories) isn't supported by this variable and always keeps trusting only its naming-convention counterpart. Only valid when common_provider is 'azuredevops', and requires azuredevops_primary_role_account_id to be set."
  type        = list(string)
  default     = []
}

variable "custom_provider" {
  description = "An object representing an `aws_iam_openid_connect_provider` resource"
  type = object({
    url                    = string
    audiences              = list(string)
    subject_reader_mapping = string
    subject_branch_mapping = string
    subject_env_mapping    = string
    subject_tag_mapping    = string
    subject_condition_test = optional(string, "StringLike")
  })

  default = null
}

variable "additional_audiences" {
  description = "Additional audiences to be allowed in the OIDC federation mapping"
  type        = list(string)
  default     = []
}

variable "trust_policy_conditions" {
  description = "Additional IAM conditions applied to every trust policy statement on all roles created by this module (read-write, read-only and state reader). Each entry renders as a `condition` block on the assume role policy, e.g. `{ test = \"StringEquals\", variable = \"aws:SourceVpc\", values = [\"vpc-0123456789abcdef0\"] }` to only permit the role to be assumed from a given VPC. Note: `aws:SourceVpc` / `aws:SourceVpce` are only present when the sts:AssumeRole* call reaches AWS via an interface VPC endpoint - i.e. self-hosted runners inside the VPC. Provider-hosted runners (GitHub/GitLab SaaS) call public STS and will be denied."
  type = list(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = []

  validation {
    condition     = alltrue([for c in var.trust_policy_conditions : length(c.values) > 0])
    error_message = "Each entry in trust_policy_conditions must specify at least one value."
  }

  ## The module owns the ':aud' and ':sub' conditions - a caller supplied condition sharing the
  ## same test and variable would be emitted as a duplicate JSON key, silently clobbering the
  ## repository scoping
  validation {
    condition = alltrue([
      for c in var.trust_policy_conditions :
      !endswith(lower(c.variable), ":aud") && !endswith(lower(c.variable), ":sub")
    ])
    error_message = "trust_policy_conditions must not target the OIDC ':aud' or ':sub' claims - these are managed by the module; use additional_audiences, repository/repositories and protected_by instead."
  }
}

variable "tf_state_suffix" {
  description = "A suffix for the terraform state file, e.g. <repo>-<tf_state_suffix>.tfstate"
  type        = string
  default     = ""
}

variable "repository" {
  description = "Repository to be allowed in the OIDC federation mapping (used when repositories variable is not set)"
  type        = string
  default     = null
}

variable "repositories" {
  description = "A collection of repositories to bind the permissions (if empty, the repository variable is used)"
  type        = list(string)
  default     = []
}

variable "shared_repositories" {
  description = "List of repositories to provide read access to the terraform remote state"
  type        = list(string)
  default     = []
}

variable "protected_by" {
  description = "The branch, environment and/or tag to protect read write role (used when enable_read_only_role is true)"
  type = object({
    branch      = optional(string)
    environment = optional(string)
    tag         = optional(string)
  })
  default = {
    branch      = "main"
    environment = "production"
    tag         = "*"
  }
}

variable "role_path" {
  description = "Path under which to create IAM role."
  type        = string
  default     = "/"
}

variable "read_only_policy_arns" {
  description = "List of IAM policy ARNs to attach to the read-only role"
  type        = list(string)
  default     = []
}

variable "read_only_inline_policies" {
  description = "Inline policies map with policy name as key and json as value."
  type        = map(string)
  default     = {}
}

variable "read_write_policy_arns" {
  description = "List of IAM policy ARNs to attach to the read-write role"
  type        = list(string)
  default     = []
}

variable "read_write_inline_policies" {
  description = "Inline policies map with policy name as key and json as value."
  type        = map(string)
  default     = {}
}

variable "read_only_max_session_duration" {
  description = "The maximum session duration (in seconds) that you want to set for the specified role"
  type        = number
  default     = null
}

variable "read_write_max_session_duration" {
  description = "The maximum session duration (in seconds) that you want to set for the specified role"
  type        = number
  default     = null
}

variable "force_detach_policies" {
  description = "Flag to force detachment of policies attached to the IAM role."
  type        = bool
  default     = true
}

variable "permission_boundary" {
  description = "The name of the policy that is used to set the permissions boundary for the IAM role"
  type        = string
  default     = null
}

variable "permission_boundary_arn" {
  description = "The full ARN of the permission boundary to attach to the role"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply resources created by this module"
  type        = map(string)
}
