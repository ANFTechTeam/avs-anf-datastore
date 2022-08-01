terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
        }
        azapi = {
            source  = "azure/azapi"
        }
    }
}

provider "azurerm" {
    features {}
    skip_provider_registration = "true"
}

provider "azapi" {
    skip_provider_registration = "true"
}

