variable "common_providers" {
  type        = list(string)
  default     = []
  description = "List of common well-known providers to enable, such as github, gitlab"
}

variable "custom_providers" {
  type = map(object({
    name              = optional(string, null)
    url               = string
    client_id_list    = list(string)
    thumbprint_list   = optional(list(string), [])
    lookup_thumbprint = optional(bool, true)
  }))
  default     = {}
  description = "Map of custom provider configurations"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Map of tags to apply to all resources"
}

variable "provider_tags" {
  type        = map(map(string))
  default     = {}
  description = "Nested map of tags to apply to specific providers. Top level keys should match provider names"
}

// bitbucket

variable "workspace_uuid" {
  description = "Workspace UUID. You can get it in the repository settings in the OpenID connect provider. Don't include the brackets and make sure it is lower cased."
  type        = string
  default     = ""

  validation {
    condition     = length(var.workspace_uuid) == 0 || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.workspace_uuid))
    error_message = "The UUID format is not matching. Make sure it is lowercased and brackets are not included. Here's a valid example: 8a1f1c70-cbc0-452c-81ce-07534945e18b."
  }
}

variable "workspace_name" {
  description = "The name of the workspace."
  type        = string
  default     = ""
}