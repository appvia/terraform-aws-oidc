variable "name" {
  type        = string
  description = "Name of the role to create"
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the role being created"
}

variable "common_provider" {
  type        = string
  default     = ""
  description = "The name of a common OIDC provider to be used as the trust for the role"
}

variable "custom_provider" {
  type = object({
    url                    = string
    audiences              = list(string)
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

variable "repositories" {
  type        = list(string)
  description = "List of repositories to be allowed i nthe OIDC federation mapping"
}

variable "unprotected_branch" {
  type        = string
  default     = "*"
  description = "The name (or pattern) of non-protected branches under which the read-only role can be assumed"
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

variable "read_only_inline_policies" {
  type        = map(string)
  default     = {}
  description = "Inline policies map with policy name as key and json as value."
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

variable "permissions_boundary" {
  type        = string
  default     = null
  description = "The ARN of the policy that is used to set the permissions boundary for the IAM role"
}

variable "read_only_tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the read-only role"
}

variable "read_write_tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to the read-write role"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply resoures created by this module"
}
