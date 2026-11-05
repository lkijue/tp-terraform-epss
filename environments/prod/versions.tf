terraform {
  required_version = ">= 1.9.0"

  # State stocké dans HCP Terraform (Terraform Cloud) : chiffré, verrouillé,
  # versionné. Organisation HCP Terraform de l'équipe.
  cloud {
    organization = "cloudtech-enzo-sebastian"

    workspaces {
      name = "cloudtech-prod"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

# Authentification : variables d'environnement ARM_CLIENT_ID, ARM_CLIENT_SECRET,
# ARM_TENANT_ID et ARM_SUBSCRIPTION_ID (service principal) définies dans HCP Terraform.
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}
