# Static public IP + DNS name for the trip-tracker app (the URL submitted for grading).
# Lives in OUR resource group, so it survives the Kubernetes Service (or even the cluster) being recreated.
resource "azurerm_public_ip" "app" {
  name                = "pip-trip-tracker-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.workload_location
  allocation_method   = "Static"
  sku                 = "Standard" # must match the AKS Standard load balancer
  domain_name_label   = "trip-tracker-${random_string.kv_suffix.result}"
  tags                = azurerm_resource_group.main.tags
}

# Lets the cluster's identity attach this IP to the AKS load balancer
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
