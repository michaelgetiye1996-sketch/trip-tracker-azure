# AKS (Azure Kubernetes Service) cluster - runs the trip-tracker containers
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-trip-tracker"
  location            = var.workload_location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-trip-tracker"
  kubernetes_version  = "1.36.4" # pinned: upgrades happen only through a reviewed PR
  sku_tier            = "Free"   # no uptime SLA - fine for a class project

  default_node_pool {
    name                        = "system"
    vm_size                     = "Standard_D2als_v7" # 2 vCPU / 4 GB, Gen2 + NVMe
    node_count                  = 1
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_type                = "Managed" # D2als_v7 has no local temp disk, so no ephemeral OS disk
    os_disk_size_gb             = 32        # default is 128 GB - shrink to save cost
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = "10%" # with 1 node this rounds up to 1 extra node during upgrades
    }
  }

  # Cluster's own identity (manages load balancers, disks, etc. in Azure)
  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay" # pods get IPs from a private overlay range, not from the VNet

    pod_cidr          = "192.168.0.0/16" # must not overlap the VNet (10.20.0.0/16)
    service_cidr      = "10.21.0.0/16"
    dns_service_ip    = "10.21.0.10"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer" # nodes reach the internet via the cluster load balancer
  }

  # Sign-in with Entra ID; authorization with Azure RBAC; no shared admin kubeconfig
  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }
  local_account_disabled = true

  # Needed in S5 so the app pod can read Key Vault with workload identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Secrets Store CSI driver: mounts Key Vault secrets into pods (authenticates with workload identity)
  key_vault_secrets_provider {
    secret_rotation_enabled = false
  }

  # Container Insights agent on the nodes; authenticates with managed identity (no workspace key)
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.main.id
    msi_auth_for_monitoring_enabled = true
  }

  tags = azurerm_resource_group.main.tags
}

# Nodes (kubelet identity) can pull images from ACR - no registry password needed
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Me = cluster admin through Azure RBAC (works with kubectl via Entra ID login)
resource "azurerm_role_assignment" "aks_admin_me" {
  scope = azurerm_kubernetes_cluster.main.id

  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = var.admin_object_id
}
