# terraform/modules/bootstrap/digitalocean/outputs.tf

output "bucket_name" {
  description = "Name of the created Spaces bucket"
  value       = digitalocean_spaces_bucket.tfstate.name
}

output "bucket_region" {
  description = "Region of the created Spaces bucket"
  value       = digitalocean_spaces_bucket.tfstate.region
}

output "bucket_endpoint" {
  description = "Endpoint URL for the Spaces bucket"
  value       = "https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com"
}

output "bucket_domain_name" {
  description = "Domain name of the bucket"
  value       = digitalocean_spaces_bucket.tfstate.bucket_domain_name
}

output "bucket_urn" {
  description = "Uniform Resource Name for the bucket"
  value       = digitalocean_spaces_bucket.tfstate.urn
}

output "backend_config" {
  description = "Backend configuration for Terraform remote state"
  value = {
    bucket                      = digitalocean_spaces_bucket.tfstate.name
    key                        = "${var.environment}/terraform.tfstate"
    region                     = "us-east-1"  # Required for S3 compatibility
    endpoint                   = "https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check    = true
    skip_region_validation     = true
    force_path_style           = false
  }
}

output "backend_config_file" {
  description = "Path to the backend configuration file"
  value       = "${path.module}/../../../outputs/backend-config-${var.environment}.hcl"
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# Instructions for using the backend
output "usage_instructions" {
  description = "Instructions for using the created backend"
  value = <<-EOT
    To use this backend in your Terraform configuration:
    
    1. Add this to your main.tf:
       terraform {
         backend "s3" {}
       }
    
    2. Initialize with backend config:
       terraform init -backend-config=outputs/backend-config-${var.environment}.hcl
    
    3. Or use individual parameters:
       terraform init \
         -backend-config="bucket=${digitalocean_spaces_bucket.tfstate.name}" \
         -backend-config="key=${var.environment}/terraform.tfstate" \
         -backend-config="region=us-east-1" \
         -backend-config="endpoint=https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com" \
         -backend-config="skip_credentials_validation=true" \
         -backend-config="skip_metadata_api_check=true" \
         -backend-config="skip_region_validation=true"
  EOT
}