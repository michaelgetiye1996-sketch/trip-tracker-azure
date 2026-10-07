# Identity for the trip-tracker pods (Entra ID workload identity)
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-trip-tracker-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.workload_location
  tags                = azurerm_resource_group.main.tags
}

# Trust: tokens issued by THIS cluster for the service account trip-tracker/trip-tracker
# can be exchanged for Entra ID tokens of the identity above. No secret involved.
resource "azurerm_federated_identity_credential" "app" {
  name                      = "fic-trip-tracker-app"
  user_assigned_identity_id = azurerm_user_assigned_identity.app.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject                   = "system:serviceaccount:trip-tracker:trip-tracker"
}

# The app identity may READ secrets (not list/write/delete) from the project vault
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
