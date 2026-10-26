# Steps 1 and 2 of 05-landing-zones.md section 4, and the cancellation of
# section 7.

locals {
  billing_profile = "/providers/Microsoft.Billing/billingAccounts/${var.az_billing_account}/billingProfiles/${var.az_billing_profile}"

  # is-cust-<code>, or is-products for the shared and the graduated products.
  # Sections the module creates use their display name as their ID (ADR 0011).
  invoice_section = var.lz.owner.customer != null ? "is-cust-${var.lz.owner.customer}" : "is-products"

  # The resource providers of 05-landing-zones.md section 4.2.
  resource_providers = toset([
    "Microsoft.Network",
    "Microsoft.KeyVault",
    "Microsoft.Consumption",
    "Microsoft.OperationalInsights",
    "Microsoft.Insights",
    "Microsoft.PolicyInsights",
    "Microsoft.ManagedIdentity",
    "Microsoft.App",
  ])
}

# Step 1. A PUT creates the section, or changes nothing if it exists. Other
# landing zones of the same owner share it, so destroying this resource never
# deletes it.
resource "azapi_resource_action" "invoice_section" {
  count       = local.experiment ? 0 : 1
  type        = "Microsoft.Billing/billingAccounts/billingProfiles/invoiceSections@2024-04-01"
  resource_id = "${local.billing_profile}/invoiceSections/${local.invoice_section}"
  method      = "PUT"
  body = {
    properties = {
      displayName = local.invoice_section
    }
  }
}

# Step 2. A PUT of the alias creates the subscription, or returns it if it
# exists. An action is never read back at plan: reading an alias needs
# Microsoft.Subscription/aliases/write, which spn-landingzones-plan doesn't
# have. Destroying it never cancels the subscription (ADR 0011).
resource "azapi_resource_action" "subscription" {
  type        = "Microsoft.Subscription/aliases@2021-10-01"
  resource_id = "/providers/Microsoft.Subscription/aliases/${var.lz.subscription}"
  method      = "PUT"
  body = {
    properties = {
      displayName  = var.lz.subscription
      billingScope = local.experiment ? "${local.billing_profile}/invoiceSections/${var.az_platform_invoice_section}" : azapi_resource_action.invoice_section[0].resource_id
      workload     = "Production"
      additionalProperties = {
        tags = local.tags
      }
    }
  }
  response_export_values = {
    subscription_id = "properties.subscriptionId"
  }
}

# v0.5.0 and earlier created it with azurerm_subscription. Only the state entry
# goes; the PUT above adopts the alias.
removed {
  from = azurerm_subscription.this

  lifecycle {
    destroy = false
  }
}

# The subscription's ID at plan, once it exists, so nothing keyed on it is
# planned as replaced. Reader on the management groups is enough to list it.
data "azurerm_subscriptions" "this" {
  display_name_contains = var.lz.subscription
}

# A PUT moves the subscription straight from one management group to another.
# azurerm_management_group_subscription_association would move it through the
# tenant root group, where spn-landingzones-apply has no right.
resource "azapi_resource_action" "management_group" {
  type        = "Microsoft.Management/managementGroups/subscriptions@2023-04-01"
  resource_id = "/providers/Microsoft.Management/managementGroups/${local.management_group}/subscriptions/${local.subscription_id}"
  method      = "PUT"
}

# Azure may make the identity that creates a subscription its Owner. That
# assignment, and only that one, is removed, so spn-landingzones-apply keeps
# only the rights it inherits from the management groups (05 section 4, step 2). The list is read
# at apply on the first run, because the subscription doesn't exist at plan.
data "azapi_resource_list" "owners" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  parent_id = local.subscription_scope
  query_parameters = {
    "$filter" = ["atScope()"]
  }
  response_export_values = {
    ids = "value[?properties.scope == '${local.subscription_scope}' && properties.principalId == '${data.azurerm_client_config.platform.object_id}' && ends_with(properties.roleDefinitionId, '/${local.roles["Owner"]}')].id"
  }

  depends_on = [azapi_resource_action.management_group]
}

# Runs once, on the first apply: a DELETE of the Owner assignment, or a
# harmless GET of the subscription if there is none.
resource "azapi_resource_action" "remove_creator_owner" {
  type        = length(data.azapi_resource_list.owners.output.ids) > 0 ? "Microsoft.Authorization/roleAssignments@2022-04-01" : "Microsoft.Resources/subscriptions@2022-12-01"
  resource_id = length(data.azapi_resource_list.owners.output.ids) > 0 ? data.azapi_resource_list.owners.output.ids[0] : local.subscription_scope
  method      = length(data.azapi_resource_list.owners.output.ids) > 0 ? "DELETE" : "GET"

  lifecycle {
    ignore_changes = all
  }
}

# register is idempotent. It returns before the provider is Registered, so
# everything inside the subscription waits for wait_for_providers
# (05 section 4.2).
resource "azapi_resource_action" "register" {
  for_each    = local.resource_providers
  type        = "Microsoft.Resources/providers@2021-04-01"
  resource_id = "${local.subscription_scope}/providers/${each.key}"
  action      = "register"
  method      = "POST"

  depends_on = [azapi_resource_action.remove_creator_owner]
}

# Runs only on the first apply. If a provider takes longer, the first resource
# that needs it fails, and the apply is run again (05 section 6).
resource "time_sleep" "wait_for_providers" {
  create_duration = "3m"

  depends_on = [azapi_resource_action.register]
}

# Section 7: cancelled. A cancelled subscription is read-only, so its resource
# groups are deleted first. OpenTofu can't order the cancel after the deletes of
# the same apply, so the groups are listed at plan, and the cancel comes with
# the next apply once none is left (05 section 6).
data "azapi_resource_list" "groups" {
  count     = local.cancelled ? 1 : 0
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  parent_id = local.subscription_scope
  response_export_values = {
    names = "value[?starts_with(name, 'rg-${local.name}-')].name"
  }
}

# Billing profile contributor may cancel a subscription billed to its profile,
# also in mg-decommissioned (ADR 0011).
resource "azapi_resource_action" "cancel" {
  count       = local.cancelled && try(length(data.azapi_resource_list.groups[0].output.names), 0) == 0 ? 1 : 0
  type        = "Microsoft.Billing/billingAccounts/billingSubscriptions@2024-04-01"
  resource_id = "/providers/Microsoft.Billing/billingAccounts/${var.az_billing_account}/billingSubscriptions/${local.subscription_id}"
  action      = "cancel"
  method      = "POST"
  body = {
    cancellationReason = "Other"
  }
}
