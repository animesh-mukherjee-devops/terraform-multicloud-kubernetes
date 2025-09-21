# terraform/modules/bootstrap/digitalocean/main.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.34"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# Random suffix for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DigitalOcean Spaces bucket for Terraform state
resource "digitalocean_spaces_bucket" "tfstate" {
  name   = "${var.bucket_prefix}-${var.environment}-${random_id.bucket_suffix.hex}"
  region = var.region

  # Enable versioning for state history
  versioning {
    enabled = true
  }

  # Set ACL directly on the bucket (newer provider approach)
  acl = "private"

  # Force destroy to allow deletion even with objects
  force_destroy = true
}

# Create outputs directory
resource "local_file" "create_outputs_dir" {
  content  = ""
  filename = "${path.module}/../../../outputs/.gitkeep"
}

# Output files for CI/CD integration
resource "local_file" "bucket_name" {
  content  = digitalocean_spaces_bucket.tfstate.name
  filename = "${path.module}/../../../outputs/do-bucket-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate, local_file.create_outputs_dir]
}

resource "local_file" "bucket_region" {
  content  = digitalocean_spaces_bucket.tfstate.region
  filename = "${path.module}/../../../outputs/do-region-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate, local_file.create_outputs_dir]
}

resource "local_file" "bucket_endpoint" {
  content  = "https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com"
  filename = "${path.module}/../../../outputs/do-endpoint-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate, local_file.create_outputs_dir]
}

# Create backend configuration file
resource "local_file" "backend_config" {
  content = templatefile("${path.module}/backend-config.tpl", {
    bucket_name = digitalocean_spaces_bucket.tfstate.name
    region      = digitalocean_spaces_bucket.tfstate.region
    environment = var.environment
  })
  filename = "${path.module}/../../../outputs/backend-config-${var.environment}.hcl"
  
  depends_on = [digitalocean_spaces_bucket.tfstate, local_file.create_outputs_dir]
}