# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.94.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  subscription_id = "05431236-577b-4c75-9f9b-058ef2431e96"
  client_id       = "5c97a815-9792-4a1d-bb9f-5e3b24b2c20b"
  client_secret   = "Lqg8Q~ABPRvfs_FFjgtpKzm_hrj6R1VG4WutFbJH"
  tenant_id       = "bb97c8b6-2d78-4ec5-87f6-28a2c5f89267"
  features {}
}