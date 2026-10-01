locals {
  # Runs once on first boot: installs the PostgreSQL client and the Azure CLI.
  jumpbox_cloud_init = <<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - postgresql-client
      - jq
    runcmd:
      - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  CLOUDINIT
}

resource "azurerm_public_ip" "jumpbox" {
  name                = "pip-jumpbox"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "jumpbox" {
  name                = "nic-jumpbox"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags

  ip_configuration {

    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox.id
  }
}

# Admin jump box: key-only SSH, its own Entra ID identity, no passwords anywhere.
resource "azurerm_linux_virtual_machine" "jumpbox" {
  name                            = "vm-jumpbox"
  location                        = var.workload_location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_F1als_v7"
  disk_controller_type            = "NVMe"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.jumpbox.id]
  custom_data                     = base64encode(local.jumpbox_cloud_init)
  tags                            = local.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"

    offer   = "ubuntu-24_04-lts"
    sku     = "server"
    version = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {}
}

# Least privilege: the jump box can READ secrets, not change or delete them.
resource "azurerm_role_assignment" "jumpbox_kv_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.jumpbox.identity[0].principal_id
}

# Cost guardrail: shut down every night at 11 PM Eastern.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "jumpbox" {
  virtual_machine_id    = azurerm_linux_virtual_machine.jumpbox.id
  location              = var.workload_location
  enabled               = true
  daily_recurrence_time = "2300"
  timezone              = "Eastern Standard Time"

  notification_settings {
    enabled = false
  }
}
