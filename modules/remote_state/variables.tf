variable "repository" {
  type        = string
  description = "The name of the repository to lookup remote state for"
}

variable "reader_role_arn" {
  type        = string
  description = "The ARN of the reader role to assume in order to read the remote state"
}

variable "web_identity_token_file" {
  type        = string
  description = "Path to the web identity token file"
}

variable "account_id" {
  type        = string
  default     = null
  description = "Account ID where the remote state bucket is located"
}

variable "region" {
  type        = string
  default     = null
  description = "The region name where the destination resources have been created"
}
