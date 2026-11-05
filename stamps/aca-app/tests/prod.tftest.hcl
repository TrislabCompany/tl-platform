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

# shr-web-prod: the alert rules of 06 section 6.8 exist in a prod landing zone.
override_module {
  target = module.catalog
  outputs = {
    folder    = "corporate-site"
    lz_folder = "products-prod-neu"
    owners    = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
    ipam_stamps = {
      products-prod-neu = { corporate-site = "10.16.0.0/27" }
    }
  }
}

variables {
  config = {
    template    = "aca-app", version = "v1.1.0", lz = "products-prod-neu", product = "corporate-site"
    environment = "prod", tenancy = "dedicated", network = { subnet_cidr = "10.16.0.0/27" }
    apps = [{
      name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
      caps = { cpu = 0.5, memory = "1Gi", min_replicas = 1, max_replicas = 2 }
    }]
  }
  lz = {
    name   = "products-prod-neu", state = "active", archetype = "standard", owner = { products = true }
    region = "northeurope", network = { spoke_cidr = "10.16.0.0/20" }
  }
  tenants = [{
    name      = "corporate-site", customer = "trislab", stamp = "products-prod-neu/corporate-site"
    hostnames = [{ fqdn = "prod-corporate-site.trislab.com", app = "web" }]
  }]
  cloudflare_ips          = { ipv4 = ["173.245.48.0/20"], ipv6 = ["2400:cb00::/32"] }
  data_access             = { readers = "33333333-3333-3333-3333-333333333333", admins = "44444444-4444-4444-4444-444444444444" }
  github_owner_id         = 123
  ghcr_pull_token_version = 1
  alert_action_group_ids  = ["/subscriptions/66666666-6666-6666-6666-666666666666/resourceGroups/rg-platform-management/providers/microsoft.insights/actionGroups/ag-platform"]
}

run "prod_alerts" {
  command = plan
  assert {
    condition     = azurerm_monitor_metric_alert.restarts["web"].name == "shr-web-prod-web-restarts" && azurerm_monitor_metric_alert.server_errors["web"].name == "shr-web-prod-web-server-errors" && azurerm_monitor_metric_alert.no_replica["web"].name == "shr-web-prod-web-no-replica"
    error_message = "names"
  }
  assert {
    condition     = one(azurerm_monitor_metric_alert.restarts["web"].criteria).metric_name == "RestartCount" && one(azurerm_monitor_metric_alert.restarts["web"].criteria).threshold == 3 && azurerm_monitor_metric_alert.restarts["web"].window_size == "PT15M"
    error_message = "restarts"
  }
  assert {
    condition     = one(azurerm_monitor_metric_alert.server_errors["web"].criteria).metric_name == "Requests" && one(one(azurerm_monitor_metric_alert.server_errors["web"].criteria).dimension).values == tolist(["5xx"])
    error_message = "server errors"
  }
  assert {
    condition     = one(azurerm_monitor_metric_alert.no_replica["web"].criteria).metric_name == "Replicas" && one(azurerm_monitor_metric_alert.no_replica["web"].criteria).operator == "LessThan" && azurerm_monitor_metric_alert.no_replica["web"].window_size == "PT5M"
    error_message = "no replica"
  }
  assert {
    condition     = alltrue([for a in [azurerm_monitor_metric_alert.restarts["web"], azurerm_monitor_metric_alert.server_errors["web"], azurerm_monitor_metric_alert.no_replica["web"]] : [for x in a.action : x.action_group_id] == var.alert_action_group_ids])
    error_message = "every rule goes to ag-platform"
  }
  assert {
    condition     = azurerm_container_app.this["web"].tags["SizingCaps"] == "cpu=0.5;memory=1Gi;minreplicas=1;maxreplicas=2;profiles=Consumption"
    error_message = azurerm_container_app.this["web"].tags["SizingCaps"]
  }
}

# Scale to zero: no replica is normal, so there is no No replica rule.
run "prod_scale_to_zero" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.1.0", lz = "products-prod-neu", product = "corporate-site"
      environment = "prod", tenancy = "dedicated", network = { subnet_cidr = "10.16.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  assert {
    condition     = length(azurerm_monitor_metric_alert.restarts) == 1 && length(azurerm_monitor_metric_alert.server_errors) == 1 && length(azurerm_monitor_metric_alert.no_replica) == 0
    error_message = "rules"
  }
}

# An app without ingress gets only the Restarts rule.
run "prod_worker" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.1.0", lz = "products-prod-neu", product = "corporate-site"
      environment = "prod", tenancy = "dedicated", network = { subnet_cidr = "10.16.0.0/27" }
      apps = [{
        name = "worker", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "none"
        caps = { cpu = 0.5, memory = "1Gi", min_replicas = 1, max_replicas = 2 }
      }]
    }
    tenants = [{ name = "corporate-site", customer = "trislab", stamp = "products-prod-neu/corporate-site" }]
  }
  assert {
    condition     = keys(azurerm_monitor_metric_alert.restarts) == ["worker"] && length(azurerm_monitor_metric_alert.server_errors) == 0 && length(azurerm_monitor_metric_alert.no_replica) == 0
    error_message = "rules"
  }
}

# Production never runs without alerts.
run "prod_without_action_group" {
  command = plan
  variables {
    alert_action_group_ids = []
  }
  expect_failures = [azurerm_resource_group.this]
}

run "min_above_max" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.1.0", lz = "products-prod-neu", product = "corporate-site"
      environment = "prod", tenancy = "dedicated", network = { subnet_cidr = "10.16.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", min_replicas = 3, max_replicas = 2 }
      }]
    }
  }
  expect_failures = [var.config]
}

run "not_an_action_group" {
  command = plan
  variables {
    alert_action_group_ids = ["ag-platform"]
  }
  expect_failures = [var.alert_action_group_ids]
}