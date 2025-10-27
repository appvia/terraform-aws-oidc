variable "common_providers" {
  description = "List of common well-known providers to enable, such as github, gitlab"
  type        = list(string)
  default     = []
}

variable "custom_providers" {
  description = "Map of custom provider configurations"
  type = map(object({
    name              = optional(string, null)
    url               = string
    client_id_list    = list(string)
    thumbprint_list   = optional(list(string), [])
    lookup_thumbprint = optional(bool, true)
  }))
  default = {}
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "provider_tags" {
  description = "Nested map of tags to apply to specific providers. Top level keys should match provider names"
  type        = map(map(string))
  default     = {}
}

