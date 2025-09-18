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

output "bucket_urn" {
  description = "Uniform Resource Name for the bucket"
  value       = digitalocean_spaces_bucket.tfstate.urn
}

output "backend_config" {
  description = "Backend configuration for Terraform remote state"
  value = {
    bucket                      = digitalocean_spaces_bucket.tfstate.name
    key                        = "kubernetes/terraform.tfstate"
    region                     = "us-east-1"  # Required for S3 compatibility
    endpoint                   = "https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check    = true
    skip_region_validation     = true
    force_path_style           = false
  }
  sensitive = false
}