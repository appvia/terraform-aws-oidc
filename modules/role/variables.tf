variable "name" {
  type        = string
  description = "Name of the role to create"
}

variable "description" {
  type        = string
  description = "Description of the role being created"
}

variable "region" {
  type        = string
  description = "The region in which the role will be used (defaulting to the provider region)"
  default     = null
}

variable "common_provider" {
  type        = string
  default     = "github"
  description = "The name of a common OIDC provider to be used as the trust for the role"
}

variable "custom_provider" {
  type = object({
    url                    = string
    audiences              = list(string)
    subject_reader_mapping = string
    subject_branch_mapping = string
    subject_tag_mapping    = string
  })

  default     = null
  description = "An object representing an `aws_iam_openid_connect_provider` resource"
}

variable "additional_audiences" {
  type        = list(string)
  default     = []
  description = "Additional audiences to be allowed in the OIDC federation mapping"
}

variable "enable_branch_suffix_on_statefile" {
  type        = bool
  default     = false
  description = "Add the protected branch as a suffix on the statefile name, e.g. <repo>-<branch>.tfstate"
}

variable "repository" {
  type        = string
  description = "List of repositories to be allowed in the OIDC federation mapping"
}

variable "shared_repositories" {
  type        = list(string)
  default     = []
  description = "List of repositories to provide read access to the remote state"
}

variable "protected_branch" {
  type        = string
  default     = "main"
  description = "The name of the protected branch under which the read-write role can be assumed"
}

variable "protected_tag" {
  type        = string
  default     = "*"
  description = "The name of the protected tag under which the read-write role can be assume"
}

variable "role_path" {
  type        = string
  default     = null
  description = "Path under which to create IAM role."
}

variable "read_only_policy_arns" {
  type        = list(string)
  default     = []
  description = "List of IAM policy ARNs to attach to the read-only role"
}

variable "read_only_inline_policies" {
  type        = map(string)
  default     = {}
  description = "Inline policies map with policy name as key and json as value."
}

variable "read_write_policy_arns" {
  type        = list(string)
  default     = []
  description = "List of IAM policy ARNs to attach to the read-write role"
}

variable "read_write_inline_policies" {
  type        = map(string)
  default     = {}
  description = "Inline policies map with policy name as key and json as value."
}

variable "read_only_max_session_duration" {
  type        = number
  default     = null
  description = "The maximum session duration (in seconds) that you want to set for the specified role"
}

variable "read_write_max_session_duration" {
  type        = number
  default     = null
  description = "The maximum session duration (in seconds) that you want to set for the specified role"
}

variable "force_detach_policies" {
  type        = bool
  default     = null
  description = "Flag to force detachment of policies attached to the IAM role."
}

variable "permission_boundary" {
  type        = string
  description = "The name of the policy that is used to set the permissions boundary for the IAM role"
  default     = null
}

variable "permission_boundary_arn" {
  type        = string
  description = "The full ARN of the permission boundary to attach to the role"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply resoures created by this module"
}
