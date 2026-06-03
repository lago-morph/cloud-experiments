terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Authentication is supplied via environment variables so no secrets land on
# disk or in version control:
#   ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
provider "azurerm" {
  features {}

  # Don't attempt subscription-wide resource provider registration: locked-down
  # lab subscriptions forbid it (and the needed providers are already
  # registered). Safe to keep on for normal subscriptions too.
  resource_provider_registrations = "none"
}
