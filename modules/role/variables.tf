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
  })

  default = null
}

variable "additional_audiences" {
  description = "Additional audiences to be allowed in the OIDC federation mapping"
  type        = list(string)
  default     = []
}

variable "tf_state_suffix" {
  description = "A suffix for the terraform statefile, e.g. <repo>-<tf_state_suffix>.tfstate"
  type        = string
  default     = ""
}

variable "repository" {
  description = "Repository to be allowed in the OIDC federation mapping"
  type        = string
  default     = null
}

variable "shared_repositories" {
  description = "List of repositories to provide read access to the remote state"
  type        = list(string)
  default     = []
}

variable "protected_by" {
  description = "The branch, environment and/or tag to protect the role against"
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
  default     = null
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
  default     = null
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
  description = "Tags to apply resoures created by this module"
  type        = map(string)
}
