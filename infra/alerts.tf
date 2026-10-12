# Where alerts go: email to the project admin
resource "azurerm_monitor_action_group" "ops" {
  name                = "ag-trip-tracker-ops"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "tripops"

  email_receiver {
    name                    = "admin-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = azurerm_resource_group.main.tags
}

# Fires when any trip-tracker container restarts (crash, OOM kill, failed liveness probe)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "pod_restarts" {
  name                 = "alert-trip-tracker-pod-restarts"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_log_analytics_workspace.main.location
  scopes               = [azurerm_log_analytics_workspace.main.id]
  description          = "A trip-tracker container restarted in the last 10 minutes"
  severity             = 2
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"

  criteria {
    query                   = <<-KQL
      KubePodInventory
      | where Namespace == "trip-tracker"
      | summarize Restarts = max(ContainerRestartCount) - min(ContainerRestartCount) by Name

      | where Restarts > 0
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled = true

  action {
    action_groups = [azurerm_monitor_action_group.ops.id]
  }

  tags = azurerm_resource_group.main.tags
}
