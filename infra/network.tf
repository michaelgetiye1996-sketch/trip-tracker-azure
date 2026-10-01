resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project}"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                            = "snet-aks"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [cidrsubnet(var.vnet_cidr, 6, 0)]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "db" {
  name                            = "snet-db"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [cidrsubnet(var.vnet_cidr, 8, 4)]
  default_outbound_access_enabled = false
  service_endpoints               = ["Microsoft.Storage"]

  delegation {
    name = "postgres-flexible"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "jumpbox" {

  name                            = "snet-jumpbox"
  resource_group_name             = azurerm_resource_group.main.name
  virtual_network_name            = azurerm_virtual_network.main.name
  address_prefixes                = [cidrsubnet(var.vnet_cidr, 8, 5)]
  default_outbound_access_enabled = false
}
