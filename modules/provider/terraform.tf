terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    # tflint-ignore: terraform_required_providers
    tls = {
      source = "hashicorp/tls"
    }
  }
}
