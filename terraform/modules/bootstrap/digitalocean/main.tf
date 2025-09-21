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

  # Lifecycle rule to manage old versions
  lifecycle_rule {
    id      = "delete-old-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.state_retention_days
    }
  }
}

# Set bucket ACL to private
resource "digitalocean_spaces_bucket_acl" "tfstate_acl" {
  bucket = digitalocean_spaces_bucket.tfstate.name
  region = digitalocean_spaces_bucket.tfstate.region
  acl    = "private"
}

# Output files for CI/CD integration
resource "local_file" "bucket_name" {
  content  = digitalocean_spaces_bucket.tfstate.name
  filename = "${path.module}/../../../outputs/do-bucket-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate]
}

resource "local_file" "bucket_region" {
  content  = digitalocean_spaces_bucket.tfstate.region
  filename = "${path.module}/../../../outputs/do-region-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate]
}

resource "local_file" "bucket_endpoint" {
  content  = "https://${digitalocean_spaces_bucket.tfstate.region}.digitaloceanspaces.com"
  filename = "${path.module}/../../../outputs/do-endpoint-${var.environment}.txt"
  
  depends_on = [digitalocean_spaces_bucket.tfstate]
}