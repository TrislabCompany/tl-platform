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

mock_provider "dns" {
  mock_data "dns_txt_record_set" {
    defaults = { records = [] }
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

# A customer sandbox stamp with two external apps, of two repositories, one of
# them in app_repo_ids.
run "customer_sandbox" {
  command = apply
  override_module {
    target = module.catalog
    outputs = {
      folder      = "construction-dev"
      lz_folder   = "cust-asg-sandbox-neu"
      owners      = [{ slug = "construction", kind = "product", code = "con", state = "active" }, { slug = "astra-group", kind = "customer", code = "asg", state = "active" }]
      ipam_stamps = { cust-asg-sandbox-neu = { construction-dev = "10.32.32.0/27" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "cust-asg-sandbox-neu", product = "construction"
      environment = "dev", tenancy = "dedicated", network = { subnet_cidr = "10.32.32.0/27" }
      apps = [
        { name = "dashboard", repo = "trislab-saas-construction", profile = "Consumption", ingress = "external", port = 8080, caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }, secrets = ["session-key"] },
        { name = "admin", repo = "trislab-saas-construction", profile = "Consumption", ingress = "external", port = 8080, caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 } },
        { name = "api", repo = "trislab-saas-construction-api", profile = "Consumption", ingress = "internal", port = 8080, caps = { cpu = 1, memory = "2Gi", max_replicas = 4 }, env = { LOG_LEVEL = "info" } },
      ]
    }
    lz = {
      name   = "cust-asg-sandbox-neu", state = "active", archetype = "standard", owner = { customer = "asg" }
      region = "northeurope", network = { spoke_cidr = "10.32.32.0/20" }
    }
    tenants = [{
      name      = "astra-group", customer = "astra-group", stamp = "cust-asg-sandbox-neu/construction-dev"
      hostnames = [{ fqdn = "dev-construction-astra-group.trislab.com", app = "dashboard" }]
    }]
    app_repo_ids = { trislab-saas-construction = 987 }
  }
  assert {
    condition     = azurerm_resource_group.this.name == "rg-asg-con-dev" && azurerm_resource_group.this.tags["Customer"] == "astra-group"
    error_message = "customer stamp code and tag"
  }
  assert {
    condition     = module.app_deploy_identity.subjects == { trislab-saas-construction = "repo:TrislabCompany@123/trislab-saas-construction@987:environment:astra-group-dev" }
    error_message = "a credential only for the repository in app_repo_ids, on the customer's Environment"
  }
  assert {
    condition     = local.hostnames == { "dev-construction-astra-group.trislab.com" = "dashboard", "dev-construction-astra-group-admin.trislab.com" = "admin" }
    error_message = "derived hostname"
  }
  assert {
    condition = alltrue([
      for a in azurerm_container_app.this : a.registry[0].server == "ghcr.io" && a.registry[0].username == "tl-ghcr-reader" && a.registry[0].password_secret_name == "ghcr-pull"
    ]) && length(azurerm_container_app.this) == 3
    error_message = "the registry credential on every app"
  }
  assert {
    condition     = sort([for s in azurerm_container_app.this["dashboard"].secret : s.name]) == tolist(["ghcr-pull", "session-key"]) && sort(keys(module.secrets.versionless_ids)) == tolist(["ghcr-pull", "session-key"])
    error_message = "secrets"
  }
  assert {
    condition     = contains([for e in azurerm_container_app.this["dashboard"].template[0].container[0].env : e.name if e.secret_name == "session-key"], "SESSION_KEY")
    error_message = "secret setting"
  }
  assert {
    condition     = !azurerm_container_app.this["api"].ingress[0].external_enabled && contains([for e in azurerm_container_app.this["api"].template[0].container[0].env : e.value if e.name == "LOG_LEVEL"], "info")
    error_message = "internal app"
  }
}

