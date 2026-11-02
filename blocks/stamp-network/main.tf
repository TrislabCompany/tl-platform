# The stamp's subnet in the landing zone's spoke and its NSG with the baseline
# rules of 06-stamp-templates.md section 6.2. The rules come from the landing
# zone's environment type and spoke range; no input changes them (ADR 0013).

locals {
  # The pools of 07 section 6.1. Each environment type denies the other's.
  pools = {
    prod    = "10.16.0.0/12"
    sandbox = "10.32.0.0/12"
  }
  other_pool = local.pools[var.envtype == "prod" ? "sandbox" : "prod"]

  rules = merge(
    {
      stamp = {
        priority = 100, direction = "Inbound", access = "Allow", protocol = "*"
        source   = [var.subnet_cidr], destination = var.subnet_cidr, port = "*"
      }
      load-balancer = {
        priority = 220, direction = "Inbound", access = "Allow", protocol = "*"
        source   = ["AzureLoadBalancer"], destination = "*", port = "*"
      }
      other-envtype-in = {
        priority = 4000, direction = "Inbound", access = "Deny", protocol = "*"
        source   = [local.other_pool], destination = "*", port = "*"
      }
      spoke = {
        priority = 4010, direction = "Inbound", access = "Deny", protocol = "*"
        source   = [var.spoke_cidr], destination = "*", port = "*"
      }
      other-envtype-out = {
        priority = 4000, direction = "Outbound", access = "Deny", protocol = "*"
        source   = ["*"], destination = local.other_pool, port = "*"
      }
    },
    # Cloudflare reaches the environment over IPv4 only (section 6.2).
    var.external ? {
      cloudflare = {
        priority = 200, direction = "Inbound", access = "Allow", protocol = "Tcp"
        source   = var.cloudflare_ipv4, destination = var.subnet_cidr, port = "443"
      }
    } : {}
  )
}

resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.stamp}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each                    = local.rules
  name                        = each.key
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = "*"
  destination_port_range      = each.value.port
  source_address_prefix       = length(each.value.source) == 1 ? each.value.source[0] : null
  source_address_prefixes     = length(each.value.source) == 1 ? null : each.value.source
  destination_address_prefix  = each.value.destination
}

resource "azurerm_subnet" "this" {
  name                 = "snet-${var.stamp}"
  resource_group_name  = "rg-${var.lz_name}-network"
  virtual_network_name = "vnet-${var.lz_name}"
  address_prefixes     = [var.subnet_cidr]

  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id

  depends_on = [azurerm_network_security_rule.this]
}
