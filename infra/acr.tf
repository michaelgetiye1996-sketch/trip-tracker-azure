# Azure Container Registry - private image store for the trip-tracker app
resource "azurerm_container_registry" "main" {
  name                = "acrtriptracker${random_string.kv_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.workload_location
  sku                 = "Basic"

  # No shared username/password - AKS and pipelines authenticate with Entra ID identities
  admin_enabled = false

  tags = azurerm_resource_group.main.tags
}
