mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { subscription_id = "22222222-2222-2222-2222-222222222222" }
  }
  mock_data "azurerm_role_definition" {
    defaults = { role_definition_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_data "azurerm_resources" {
    defaults = { resources = [{ name = "kv-products-sb-1234", id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-products-sandbox-neu-security/providers/Microsoft.KeyVault/vaults/kv-products-sb-1234", type = "Microsoft.KeyVault/vaults", location = "northeurope", resource_group_name = "rg-products-sandbox-neu-security", tags = {} }] }
  }
  # The provider checks IDs even when mocked.
  mock_resource "azurerm_container_app_environment" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-s/providers/Microsoft.App/managedEnvironments/cae-s", custom_domain_verification_id = "VERIFICATION-ID" }
  }
  mock_resource "azurerm_container_app" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-s/providers/Microsoft.App/containerApps/ca-s-web" }
  }
  mock_resource "azurerm_container_app_environment_certificate" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-s/providers/Microsoft.App/managedEnvironments/cae-s/certificates/trislab-com" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-s/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-s", principal_id = "55555555-5555-5555-5555-555555555555" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-l-network/providers/Microsoft.Network/virtualNetworks/vnet-l/subnets/snet-s" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-s/providers/Microsoft.Network/networkSecurityGroups/nsg-s" }
  }
}

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-products-sandbox-neu-security/providers/Microsoft.KeyVault/vaults/kv-products-sb-1234/secrets/s", output = { properties = { secretUri = "https://kv-products-sb-1234.vault.azure.net/secrets/s" } } }
  }
}

# The files the template reads by path (catalog/main.tf).
override_module {
  target = module.catalog
  outputs = {
    folder    = "corporate-site-staging"
    lz_folder = "products-sandbox-neu"
    owners = [
      { slug = "corporate-site", kind = "product", code = "web", state = "active" },
      { slug = "construction", kind = "product", code = "con", state = "active" },
      { slug = "astra-group", kind = "customer", code = "asg", state = "active" },
    ]
    ipam_stamps = {
      products-sandbox-neu = { corporate-site-staging = "10.32.0.0/27", too-small = "10.32.0.32/28" }
      products-prod-neu    = { corporate-site-staging = "10.16.0.0/27" }
      cust-asg-sandbox-neu = { corporate-site-staging = "10.32.32.0/27" }
    }
  }
}

# shr-web-staging, as in 06 section 6.5.
variables {
  config = {
    template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
    environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
    apps = [{
      name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
      caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
    }]
  }
  lz = {
    name   = "products-sandbox-neu", state = "active", archetype = "standard", owner = { products = true }
    region = "northeurope", network = { spoke_cidr = "10.32.0.0/20" }
  }
  tenants = [{
    name      = "corporate-site", customer = "trislab", stamp = "products-sandbox-neu/corporate-site-staging"
    hostnames = [{ fqdn = "staging-corporate-site.trislab.com", app = "web" }]
  }]
  cloudflare_ips          = { ipv4 = ["173.245.48.0/20", "103.21.244.0/22"], ipv6 = ["2400:cb00::/32"] }
  data_access             = { readers = "33333333-3333-3333-3333-333333333333", admins = "44444444-4444-4444-4444-444444444444" }
  github_owner_id         = 123
  ghcr_pull_token_version = 1
}

# network.mode managed: no subnet, NSG or infrastructure resource group of the
# stamp's, no range in catalog/ipam.yaml, and the same Cloudflare-only ingress
# (06 section 6.2, ADR 0058).
run "managed_network" {
  command = apply
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-sandbox-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-sandbox-neu = {} }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.2.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { mode = "managed" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  assert {
    condition     = length(module.network) == 0
    error_message = "a managed stamp has no subnet or NSG"
  }
  assert {
    condition     = azurerm_container_app_environment.this.infrastructure_subnet_id == null && azurerm_container_app_environment.this.infrastructure_resource_group_name == null && azurerm_container_app_environment.this.zone_redundancy_enabled == null
    error_message = "a managed environment has no subnet and no infrastructure resource group name"
  }
  assert {
    condition     = jsonencode([for r in azurerm_container_app.this["web"].ingress[0].ip_security_restriction : [r.action, r.ip_address_range]]) == jsonencode([["Allow", "173.245.48.0/20"], ["Allow", "103.21.244.0/22"]])
    error_message = "a managed stamp's external app still admits only Cloudflare's ipv4 ranges"
  }
  assert {
    condition     = terraform_data.fixed.output.network_mode == "managed" && terraform_data.fixed.output.subnet_cidr == null
    error_message = "the mode is a fixed field of a managed stamp"
  }
}
