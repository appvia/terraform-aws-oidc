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
