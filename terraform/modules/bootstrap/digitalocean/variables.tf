# terraform/modules/bootstrap/digitalocean/variables.tf

variable "bucket_prefix" {
  description = "Prefix for the Terraform state bucket name"
  type        = string
  default     = "tfstate"
  
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_prefix))
    error_message = "Bucket prefix must be lowercase alphanumeric with hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "multi-cloud-k8s"
}

variable "region" {
  description = "DigitalOcean region for the Spaces bucket"
  type        = string
  default     = "nyc3"
  
  validation {
    condition = contains([
      "nyc1", "nyc3", "ams2", "ams3", "sfo1", "sfo2", "sfo3", 
      "sgp1", "lon1", "fra1", "tor1", "blr1", "syd1"
    ], var.region)
    error_message = "Invalid DigitalOcean region."
  }
}

variable "state_retention_days" {
  description = "Number of days to retain old Terraform state versions"
  type        = number
  default     = 90
  
  validation {
    condition     = var.state_retention_days >= 1 && var.state_retention_days <= 365
    error_message = "State retention days must be between 1 and 365."
  }
}