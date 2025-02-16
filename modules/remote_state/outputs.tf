output "outputs" {
  description = "The outputs from the terraform_remote_state data source."
  value       = data.terraform_remote_state.this.outputs
}

output "bucket_name" {
  description = "The name of the S3 bucket where the Terraform state is stored."
  value       = local.tf_state_bucket
}

output "bucket_key" {
  description = "The key of the S3 bucket where the Terraform state is stored."
  value       = local.tf_state_key
}
