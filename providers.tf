provider "github" {
  token = var.gh_pat
  owner = "pecarmoorg"
}

terraform {
  backend "azurerm" {
    resource_group_name  = "statestoragerg19910"
    storage_account_name = "statestacc19910"
    container_name       = "statestoragecontainer"
    key                  = "github.tfstate"
  }
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}