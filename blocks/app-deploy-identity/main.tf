# id-<stamp>-appdeploy, what app CI signs in as (06-stamp-templates.md section
# 6.3): one federated credential per app repository whose ID global/github has
# written into app_repo_ids, and "Stamp app deploy" on each of the stamp's apps
# and nothing else (ADR 0024, ADR 0038). A repository not yet in the map gets
# its credential on a later apply.

data "azurerm_client_config" "current" {}

# A custom role of platform/azure/governance.
data "azurerm_role_definition" "stamp_app_deploy" {
  name  = "Stamp app deploy"
  scope = "/providers/Microsoft.Management/managementGroups/mg-landingzones"
}

resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.stamp}-appdeploy"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# GitHub's immutable subject (ADR 0045).
resource "azurerm_federated_identity_credential" "this" {
  for_each                  = { for r in toset(var.repos) : r => var.app_repo_ids[r] if contains(keys(var.app_repo_ids), r) }
  name                      = each.key
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  issuer                    = "https://token.actions.githubusercontent.com"
  audience                  = ["api://AzureADTokenExchange"]
  subject                   = "repo:TrislabCompany@${var.github_owner_id}/${each.key}@${each.value}:environment:${var.app_environment}"
}

resource "azurerm_role_assignment" "this" {
  for_each           = var.app_ids
  scope              = each.value
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${data.azurerm_role_definition.stamp_app_deploy.role_definition_id}"
  principal_id       = azurerm_user_assigned_identity.this.principal_id
  principal_type     = "ServicePrincipal"
}
