# Data Collection Rule (DCR): what Container Insights collects and where it goes.
# Cost-tuned: 5-minute interval, kube-system excluded, no legacy ContainerLog stream.
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "MSCI-${var.workload_location}-${azurerm_kubernetes_cluster.main.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_log_analytics_workspace.main.location # DCR lives with the workspace
  description         = "Container Insights for aks-trip-tracker"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = local.ci_streams
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = local.ci_streams
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "5m"
          namespaceFilteringMode = "Exclude"
          namespaces             = ["kube-system", "gatekeeper-system", "azure-arc"]
          enableContainerLogV2   = true

        }
      })
    }
  }

  tags = azurerm_resource_group.main.tags
}

# Links the cluster to the rule
resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.main.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}

locals {
  ci_streams = [
    "Microsoft-ContainerLogV2",    # app stdout/stderr
    "Microsoft-KubeEvents",        # scheduling, pulls, crashes
    "Microsoft-KubePodInventory",  # pod status/restarts
    "Microsoft-KubeNodeInventory", # node status
    "Microsoft-Perf",              # CPU/memory
    "Microsoft-InsightsMetrics",   # metrics for portal charts
  ]
}
