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
  mock_resource "azurerm_key_vault_secret" {
    defaults = { versionless_id = "https://kv-products-sb-1234.vault.azure.net/secrets/s", resource_versionless_id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-products-sandbox-neu-security/providers/Microsoft.KeyVault/vaults/kv-products-sb-1234/secrets/s" }
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

run "shr_web_staging" {
  command = apply
  assert {
    condition     = azurerm_resource_group.this.name == "rg-shr-web-staging" && azurerm_container_app_environment.this.name == "cae-shr-web-staging" && azurerm_container_app.this["web"].name == "ca-shr-web-staging-web"
    error_message = "names"
  }
  assert {
    condition     = azurerm_resource_group.this.tags == tomap({ Product = "corporate-site", Customer = "trislab", EnvironmentType = "sandbox", EnvironmentName = "staging" })
    error_message = "tags"
  }
  assert {
    condition     = azurerm_container_app.this["web"].tags["SizingCaps"] == "cpu=0.5;memory=1Gi;minreplicas=0;maxreplicas=2;profiles=Consumption"
    error_message = azurerm_container_app.this["web"].tags["SizingCaps"]
  }
  assert {
    condition     = jsonencode(output.caps) == jsonencode({ web = { cpu = 0.5, max_replicas = 2, memory = "1Gi", min_replicas = 0, profiles = ["Consumption"] } })
    error_message = "caps"
  }
  assert {
    condition     = azurerm_container_app.this["web"].template[0].container[0].image == "ghcr.io/trislabcompany/platform-placeholder:1.0.0@sha256:d4dc273739987aac86aff1cec676d2d615fc51bf1ab9a4b60cc37ce4a7f89c2f"
    error_message = "placeholder image"
  }
  assert {
    condition     = azurerm_container_app.this["web"].template[0].container[0].cpu == 0.25 && azurerm_container_app.this["web"].template[0].container[0].memory == "0.5Gi"
    error_message = "smallest size"
  }
  assert {
    condition     = azurerm_container_app.this["web"].template[0].container[0].liveness_probe[0].path == "/healthz" && azurerm_container_app.this["web"].template[0].container[0].readiness_probe[0].path == "/readyz" && azurerm_container_app.this["web"].template[0].container[0].readiness_probe[0].port == 8080
    error_message = "probes"
  }
  assert {
    condition = {
      for e in azurerm_container_app.this["web"].template[0].container[0].env : e.name => e.value
      } == {
      PLATFORM_STAMP = "shr-web-staging", PLATFORM_ENVIRONMENT = "staging", PLATFORM_TENANCY = "dedicated", PLATFORM_TENANTS = "corporate-site"
    }
    error_message = "settings"
  }
  assert {
    condition     = azurerm_container_app.this["web"].ingress[0].external_enabled && azurerm_container_app.this["web"].ingress[0].target_port == 8080
    error_message = "ingress"
  }
  assert {
    condition     = azurerm_container_app_environment.this.infrastructure_resource_group_name == "rg-shr-web-staging-infra" && !azurerm_container_app_environment.this.zone_redundancy_enabled
    error_message = "environment"
  }
  assert {
    condition     = jsonencode(keys(module.secrets.versionless_ids)) == jsonencode(["ghcr-pull"])
    error_message = "secrets"
  }
  assert {
    condition     = jsonencode(module.network.rules["other-envtype-in"].source) == jsonencode(["10.16.0.0/12"]) && module.network.rules["other-envtype-out"].destination == "10.16.0.0/12" && jsonencode(module.network.rules["spoke"].source) == jsonencode(["10.32.0.0/20"])
    error_message = "isolation rules"
  }
  assert {
    condition     = module.app_deploy_identity.subjects == {}
    error_message = "no federated credential before global/github writes the repository's ID"
  }
  assert {
    condition     = module.hostname_bindings.bound == []
    error_message = "no binding without the certificate and the asuid record"
  }
}

# Rule 200 admits the ipv4 list, and only on port 443.
run "cloudflare_rule" {
  command = plan
  assert {
    condition     = jsonencode(module.network.rules["cloudflare"].source) == jsonencode(["173.245.48.0/20", "103.21.244.0/22"]) && module.network.rules["cloudflare"].port == "443" && module.network.rules["cloudflare"].priority == 200
    error_message = "rule 200"
  }
}

run "no_external_app_no_rule_200" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "worker", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "none"
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
    tenants = [{ name = "corporate-site", customer = "trislab", stamp = "products-sandbox-neu/corporate-site-staging" }]
  }
  assert {
    condition     = !contains(keys(module.network.rules), "cloudflare")
    error_message = "rule 200"
  }
}

run "binding_skipped_without_edge_hostname" {
  command = apply
  variables {
    origin_cert_versions = { TRISLAB_COM = 1 }
  }
  assert {
    condition     = module.hostname_bindings.bound == []
    error_message = "bound without the edge hostname"
  }
}

run "binding_made_with_edge_hostname" {
  command = apply
  variables {
    origin_cert_versions = { TRISLAB_COM = 1 }
    edge_hostnames       = ["staging-corporate-site.trislab.com"]
  }
  assert {
    condition     = jsonencode(module.hostname_bindings.bound) == jsonencode(["staging-corporate-site.trislab.com"])
    error_message = "not bound"
  }
}

run "binding_skipped_without_certificate" {
  command = apply
  variables {
    edge_hostnames = ["staging-corporate-site.trislab.com"]
  }
  assert {
    condition     = module.hostname_bindings.bound == []
    error_message = "bound without the certificate"
  }
}

# The state from shr_web_staging is still there: a changed fixed field fails.
run "fixed_field_changed" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-sandbox-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-sandbox-neu = { corporate-site-staging = "10.32.0.0/27" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", number = "02", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}
