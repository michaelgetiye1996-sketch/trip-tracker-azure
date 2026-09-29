data "azurerm_subscription" "current" {}

locals {
  tags = {
    project     = var.project
    environment = "dev"
    managed_by  = "terraform"
    course      = "MSIT-5660"
  }
}


resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project}"
  location = var.location
  tags     = local.tags
}
