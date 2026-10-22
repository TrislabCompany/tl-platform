# Steps 2 to 5 and 9 of 05-landing-zones.md section 4: the landing zone's
# resource groups and what goes in them (ADR 0022). An experiment has none of
# them (section 4.1). They stay when the landing zone is decommissioned
# (section 7).

locals {
  dedicated_workspace = try(var.lz.observability.dedicated_workspace, false)
  groups              = toset(local.network ? concat(["network", "security"], local.dedicated_workspace ? ["monitoring"] : []) : [])
}

resource "azurerm_resource_group" "this" {
  provider = azurerm.lz
  for_each = local.groups
  name     = "rg-${local.name}-${each.key}"
  location = var.lz.region
  tags     = local.tags

  depends_on = [time_sleep.wait_for_providers]
}

# Every group but the network group, whose spoke the stamps change.
resource "azurerm_management_lock" "this" {
  for_each   = setsubtract(local.groups, ["network"])
  name       = "lock-${azurerm_resource_group.this[each.key].name}"
  scope      = azurerm_resource_group.this[each.key].id
  lock_level = "CanNotDelete"
}

resource "azurerm_network_watcher" "this" {
  provider            = azurerm.lz
  count               = local.network ? 1 : 0
  name                = "nw-${local.name}"
  resource_group_name = azurerm_resource_group.this["network"].name
  location            = var.lz.region
  tags                = local.tags
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

resource "azurerm_virtual_network" "this" {
  provider            = azurerm.lz
  count               = local.network ? 1 : 0
  name                = "vnet-${local.name}"
  resource_group_name = azurerm_resource_group.this["network"].name
  location            = var.lz.region
  address_space       = [var.lz.network.spoke_cidr]
  tags                = local.tags
}

# A missing hub fails the plan here (05 section 3).
data "azurerm_virtual_network" "hub" {
  count               = local.network ? 1 : 0
  name                = "vnet-hub-${local.region_code}"
  resource_group_name = "rg-hub-${local.region_code}"
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm.lz
  count                     = local.connected ? 1 : 0
  name                      = "peer-${local.name}-to-hub-${local.region_code}"
  resource_group_name       = azurerm_resource_group.this["network"].name
  virtual_network_name      = azurerm_virtual_network.this[0].name
  remote_virtual_network_id = data.azurerm_virtual_network.hub[0].id
  allow_forwarded_traffic   = true
}

# The hub half, with "Landing zone hub peering" (ADR 0018).
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count                     = local.connected ? 1 : 0
  name                      = "peer-hub-${local.region_code}-to-${local.name}"
  resource_group_name       = data.azurerm_virtual_network.hub[0].resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub[0].name
  remote_virtual_network_id = azurerm_virtual_network.this[0].id
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
  virtual_network_id  = azurerm_virtual_network.this[0].id
  tags                = local.tags
}

# ---- Step 5: Key Vault --------------------------------------------------------

locals {
  # sb only where sandbox would pass the limit of 24 (03 section 6).
  key_vault_name = local.network ? (
    length("kv-${local.scope}-${local.envtype}-0000") <= 24
    ? "kv-${local.scope}-${local.envtype}-${random_integer.suffix[0].result}"
    : "kv-${local.scope}-sb-${random_integer.suffix[0].result}"
  ) : null
}

resource "azurerm_key_vault" "this" {
  provider                   = azurerm.lz
  count                      = local.network ? 1 : 0
  name                       = local.key_vault_name
  resource_group_name        = azurerm_resource_group.this["security"].name
  location                   = var.lz.region
  tenant_id                  = data.azurerm_client_config.platform.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  tags                       = local.tags
}

# ---- Step 9: dedicated workspace ----------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  provider            = azurerm.lz
  count               = local.network && local.dedicated_workspace ? 1 : 0
  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.this["monitoring"].name
  location            = var.lz.region
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}
