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

# Random suffix for unique naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DigitalOcean Spaces bucket for Terraform state
resource "digitalocean_spaces_bucket" "tfstate" {
  name   = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
  region = var.region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "delete-old-versions"
    enabled = true

    noncurrent_version_expiration {
      days = var.state_retention_days
    }
  }
}

# ACL for the bucket
resource "digitalocean_spaces_bucket_acl" "tfstate_acl" {
  bucket = digitalocean_spaces_bucket.tfstate.name
  region = digitalocean_spaces_bucket.tfstate.region
  acl    = "private"
}

# Enable versioning
resource "digitalocean_spaces_bucket_versioning" "tfstate_versioning" {
  bucket = digitalocean_spaces_bucket.tfstate.name
  region = digitalocean_spaces_bucket.tfstate.region
  versioning_configuration {
    status = "Enabled"
  }
}

# Tags for the bucket (if supported)
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Purpose     = "tfstate-backend"
  }
}