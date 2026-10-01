# Jump box: SSH only from the admin's home IP. The internet is denied by the default DenyAllInBound rule.
resource "azurerm_network_security_group" "jumpbox" {
  name                = "nsg-jumpbox"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name                       = "Allow-SSH-From-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ip_cidr
    destination_address_prefix = azurerm_subnet.jumpbox.address_prefixes[0]
  }
}

# Database: PostgreSQL only from AKS and the jump box. The explicit deny overrides the default AllowVnetInBound.
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  security_rule {
    name = "Allow-Postgres-From-App-And-Admin"

    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefixes    = [azurerm_subnet.aks.address_prefixes[0], azurerm_subnet.jumpbox.address_prefixes[0]]
    destination_address_prefix = azurerm_subnet.db.address_prefixes[0]
  }

  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

