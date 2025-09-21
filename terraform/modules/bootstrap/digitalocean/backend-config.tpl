# Backend configuration for DigitalOcean Spaces
# Generated automatically by bootstrap module

bucket                      = "${bucket_name}"
key                        = "${environment}/terraform.tfstate"
region                     = "us-east-1"
endpoint                   = "https://${region}.digitaloceanspaces.com"
skip_credentials_validation = true
skip_metadata_api_check    = true
skip_region_validation     = true
force_path_style           = false

# Usage: terraform init -backend-config=backend-config-${environment}.hcl