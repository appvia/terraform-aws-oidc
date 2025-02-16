variable "account_id" {
  description = "Account ID where the remote state bucket is located"
  type        = string
}

variable "reader_role" {
  description = "The name of the reader role to assume in order to read the remote state"
  type        = string
  default     = null
}

variable "region" {
  description = "The region name where the destination resources have been created"
  type        = string
  default     = null
}

variable "repository" {
  description = "The name of the repository to lookup remote state for"
  type        = string
}

variable "web_identity_token_file" {
  description = "Path to the web identity token file"
  type        = string
  default     = null
}
