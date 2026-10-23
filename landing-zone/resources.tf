# Steps 2 to 5 and 9 of 05-landing-zones.md section 4: the landing zone's
# resource groups and what goes in them (ADR 0022). An experiment has none of
# them (section 4.1). They stay when the landing zone is decommissioned, and
# are deleted when it is cancelled, before the cancel (section 7).
#
# What goes into the subscription is written with azapi, addressed by its
# parent's full ID. An azurerm provider for the subscription would need its ID
# at plan, before the apply that creates the subscription (05 section 4).

locals {
  dedicated_workspace = try(var.lz.observability.dedicated_workspace, false)
  groups              = toset(local.network ? concat(["network", "security"], local.dedicated_workspace ? ["monitoring"] : []) : [])
}

resource "azapi_resource" "resource_group" {
  for_each  = local.groups
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  parent_id = local.subscription_scope
  name      = "rg-${local.name}-${each.key}"
  location  = var.lz.region
  tags      = local.tags

  depends_on = [time_sleep.wait_for_providers]
}

# Every group but the network group, whose spoke the stamps change. A lock
# blocks deleting what is in its group, so it depends on the Key Vault and the
# workspace: it is created after them and deleted before them.
resource "azurerm_management_lock" "this" {
  for_each   = setsubtract(local.groups, ["network"])
  name       = "lock-${azapi_resource.resource_group[each.key].name}"
  scope      = azapi_resource.resource_group[each.key].id
  lock_level = "CanNotDelete"

  depends_on = [azapi_resource.key_vault, azapi_resource.workspace]
}

resource "azapi_resource" "network_watcher" {
  count     = local.network ? 1 : 0
  type      = "Microsoft.Network/networkWatchers@2024-05-01"
  parent_id = azapi_resource.resource_group["network"].id
  name      = "nw-${local.name}"
  location  = var.lz.region
  tags      = local.tags
  body = {
    properties = {}
  }
}

# Step 3 (03 section 6).
resource "random_integer" "suffix" {
  count = local.network ? 1 : 0
  min   = 1000
  max   = 9999

  keepers = {
    region = var.lz.region
  }
}

# ---- Step 4: spoke, hub peering and private DNS links -------------------------

# The stamps add their subnets to the spoke. A PUT of the spoke without them
# would delete them, so the spoke is never updated in place: its range and
# tags don't change after it is created (07 section 6).
resource "azapi_resource" "spoke" {
  count     = local.network ? 1 : 0
  type      = "Microsoft.Network/virtualNetworks@2024-05-01"
  parent_id = azapi_resource.resource_group["network"].id
  name      = "vnet-${local.name}"
  location  = var.lz.region
  tags      = local.tags
  body = {
    properties = {
      addressSpace = {
        addressPrefixes = [var.lz.network.spoke_cidr]
      }
    }
  }

  lifecycle {
    ignore_changes = [body, tags]
  }
}

# A missing hub fails the plan here (05 section 3).
data "azurerm_virtual_network" "hub" {
  count               = local.network ? 1 : 0
  name                = "vnet-hub-${local.region_code}"
  resource_group_name = "rg-hub-${local.region_code}"
}

resource "azapi_resource" "spoke_to_hub" {
  count     = local.connected ? 1 : 0
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01"
  parent_id = azapi_resource.spoke[0].id
  name      = "peer-${local.name}-to-hub-${local.region_code}"
  body = {
    properties = {
      remoteVirtualNetwork      = { id = data.azurerm_virtual_network.hub[0].id }
      allowVirtualNetworkAccess = true
      allowForwardedTraffic     = true
    }
  }
}

# The hub half, with "Landing zone hub peering" (ADR 0018).
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count                     = local.connected ? 1 : 0
  name                      = "peer-hub-${local.region_code}-to-${local.name}"
  resource_group_name       = data.azurerm_virtual_network.hub[0].resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub[0].name
  remote_virtual_network_id = azapi_resource.spoke[0].id
  allow_forwarded_traffic   = true
}

# Every privatelink.* zone, with "Landing zone DNS link" (ADR 0020).
data "azurerm_resources" "dns_zones" {
  count               = local.connected ? 1 : 0
  resource_group_name = "rg-platform-dns"
  type                = "Microsoft.Network/privateDnsZones"
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each            = local.connected ? { for z in data.azurerm_resources.dns_zones[0].resources : z.name => z.id if startswith(z.name, "privatelink.") } : {}
  name                = "vnetl-${local.name}"
  private_dns_zone_id = each.value
  virtual_network_id  = azapi_resource.spoke[0].id
  tags                = local.tags
}

# ---- Step 5: Key Vault --------------------------------------------------------

locals {
  # sb replaces sandbox only where sandbox would pass the limit of 24. A prod
  # name has no short form, so a scope too long for it fails (03 section 6).
  key_vault_envtype = local.network && local.envtype == "sandbox" && length("kv-${local.scope}-sandbox-0000") > 24 ? "sb" : local.envtype
  key_vault_name    = local.network ? "kv-${local.scope}-${local.key_vault_envtype}-${random_integer.suffix[0].result}" : null
}

# The public endpoint stays open, because the GitHub-hosted runners that write
# the stamps' secrets have no fixed address. Only Entra ID sign-in with Azure
# RBAC is allowed (05 section 4, step 5).
resource "azapi_resource" "key_vault" {
  count     = local.network ? 1 : 0
  type      = "Microsoft.KeyVault/vaults@2023-07-01"
  parent_id = azapi_resource.resource_group["security"].id
  name      = local.key_vault_name
  location  = var.lz.region
  tags      = local.tags
  body = {
    properties = {
      tenantId                  = data.azurerm_client_config.platform.tenant_id
      sku                       = { family = "A", name = "standard" }
      enableRbacAuthorization   = true
      softDeleteRetentionInDays = 90
      enablePurgeProtection     = true
      publicNetworkAccess       = "Enabled"
      networkAcls               = { defaultAction = "Allow", bypass = "AzureServices" }
      accessPolicies            = []
    }
  }

  lifecycle {
    precondition {
      condition     = length("kv-${local.scope}-${local.key_vault_envtype}-0000") <= 24
      error_message = "The Key Vault name kv-${local.scope}-${local.key_vault_envtype}-<nnnn> is longer than 24 characters (03 section 6)."
    }
  }
}

# ---- Step 9: dedicated workspace ----------------------------------------------

resource "azapi_resource" "workspace" {
  count     = local.network && local.dedicated_workspace ? 1 : 0
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  parent_id = azapi_resource.resource_group["monitoring"].id
  name      = "log-${local.name}"
  location  = var.lz.region
  tags      = local.tags
  body = {
    properties = {
      sku             = { name = "PerGB2018" }
      retentionInDays = 30
    }
  }
}
