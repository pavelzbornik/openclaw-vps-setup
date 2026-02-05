# Terraform version constraints
# This file ensures team members use compatible Terraform versions

terraform {
  required_version = ">= 1.0"

  required_providers {
    discord = {
      source  = "Lucky3028/discord"
      version = "~> 1.7"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 1.4"
    }
  }
}
