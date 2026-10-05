output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "postgres_fqdn" {
  description = "Private hostname; resolves only inside the VNet"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "jumpbox_public_ip" {
  value = azurerm_public_ip.jumpbox.ip_address
}

output "acr_login_server" {
  description = "ACR login server used in image names (e.g. <server>/trip-tracker:tag)"
  value       = azurerm_container_registry.main.login_server
}
