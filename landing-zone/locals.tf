data "azurerm_client_config" "platform" {}

locals {
  name       = var.lz.name
  experiment = var.lz.archetype == "experiment"
  active     = var.lz.state == "active"

  # <scope>-<envtype>-<region code>[-<nn>] (03 section 7.3). An experiment has
  # no envtype and counts as sandbox.
  parts       = local.experiment ? null : regex("^(.+)-(prod|sandbox)-([a-z0-9]+)(?:-[0-9]{2})?$", local.name)
  scope       = local.experiment ? null : local.parts[0]
  envtype     = local.experiment ? "sandbox" : local.parts[1]
  region_code = local.experiment ? null : local.parts[2]
  prod        = local.envtype == "prod"

  # Steps 3 to 5, 8 and 9 exist only outside experiments (05 section 4.1). The
  # hub peering, the DNS links, the pipeline identities, the Environment and
  # the access grants only while active (05 section 7).
  network   = !local.experiment
  connected = local.network && local.active

  customer = var.lz.owner.customer == null ? null : one([
    for o in var.catalog.owners : o if o.kind == "customer" && o.code == var.lz.owner.customer
  ])

  # The landing zone's own resources (05 section 2, 03 section 9).
  tags = {
    Product         = "platform"
    Customer        = local.customer == null ? "trislab" : local.customer.slug
    EnvironmentType = local.envtype
    EnvironmentName = local.experiment ? "experiment" : local.envtype
  }

  management_group = (
    !local.active ? "mg-decommissioned" :
    local.experiment ? "mg-experiments" :
    var.lz.archetype == "regulated" ? "mg-lz-regulated" : "mg-lz-standard"
  )

  # The platform's resources, found by name in sub-platform, so the plan needs
  # no read right on them.
  platform_subscription = "/subscriptions/${data.azurerm_client_config.platform.subscription_id}"
  ag_finops             = "${local.platform_subscription}/resourceGroups/rg-platform-governance/providers/Microsoft.Insights/actionGroups/ag-finops"
  tfstate_stamps        = "${local.platform_subscription}/resourceGroups/rg-platform-state/providers/Microsoft.Storage/storageAccounts/stplatformtfstate${var.platform_suffix}/blobServices/default/containers/tfstate-stamps"

  subscription_id    = azurerm_subscription.this.subscription_id
  subscription_scope = "/subscriptions/${local.subscription_id}"

  # Built-in role IDs. Role assignments name roles by ID, so nothing is looked
  # up in a subscription that doesn't exist yet.
  roles = {
    "Reader"                                  = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    "Contributor"                             = "b24988ac-6180-42a0-ab88-20f7382dd24c"
    "Owner"                                   = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
    "Key Vault Reader"                        = "21090545-7ca7-4776-b22c-e363652d74d2"
    "Key Vault Secrets Officer"               = "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
    "Key Vault Secrets User"                  = "4633458b-17de-408a-b874-0445c86b69e6"
    "Role Based Access Control Administrator" = "f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    "Storage Blob Data Reader"                = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
    "Storage Blob Data Contributor"           = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    "Azure Service Bus Data Sender"           = "69a216fc-b8fb-44d8-bc22-1f3c2cd27a39"
    "Azure Service Bus Data Receiver"         = "4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0"
    "Azure Service Bus Data Owner"            = "090c5cfd-751d-490a-894a-3ce6f1109419"
  }
}

# Custom roles of platform/azure/governance.
data "azurerm_role_definition" "edge_stamp_reader" {
  name  = "Edge stamp reader"
  scope = "/providers/Microsoft.Management/managementGroups/mg-landingzones"
}

data "azurerm_role_definition" "stamp_app_deploy" {
  name  = "Stamp app deploy"
  scope = "/providers/Microsoft.Management/managementGroups/mg-landingzones"
}
