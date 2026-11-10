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

run "no_ghcr_pull_token_version" {
  command = plan
  variables {
    ghcr_pull_token_version = null
  }
  expect_failures = [azurerm_resource_group.this]
}

run "data_refused" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
      data = { postgres = {} }
    }
  }
  expect_failures = [var.config]
}

run "caps_above_consumption" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [var.config]
}

run "lz_not_parent_folder" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-prod-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-sandbox-neu = { corporate-site-staging = "10.32.0.0/27" } }
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "lz_not_active" {
  command = plan
  variables {
    lz = {
      name   = "products-sandbox-neu", state = "decommissioned", archetype = "standard", owner = { products = true }
      region = "northeurope", network = { spoke_cidr = "10.32.0.0/20" }
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "product_not_registered" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-sandbox-neu"
      owners      = [{ slug = "construction", kind = "product", code = "con", state = "active" }]
      ipam_stamps = { products-sandbox-neu = { corporate-site-staging = "10.32.0.0/27" } }
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "prod_in_sandbox" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "prod", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "staging_in_prod" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-prod-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-prod-neu = { corporate-site-staging = "10.16.0.0/27" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-prod-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.16.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
    lz = {
      name   = "products-prod-neu", state = "active", archetype = "standard", owner = { products = true }
      region = "northeurope", network = { spoke_cidr = "10.16.0.0/20" }
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "subnet_not_in_ipam" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.64/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "subnet_smaller_than_27" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "too-small"
      lz_folder   = "products-sandbox-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-sandbox-neu = { too-small = "10.32.0.32/28" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.32/28" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "subnet_outside_spoke" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site-staging"
      lz_folder   = "products-sandbox-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-sandbox-neu = { corporate-site-staging = "10.32.16.0/27" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { subnet_cidr = "10.32.16.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "shared_in_customer_landing_zone" {
  command = plan
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
      environment = "dev", tenancy = "shared", network = { subnet_cidr = "10.32.32.0/27" }
      apps = [{
        name = "web", repo = "trislab-saas-construction", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
    lz = {
      name   = "cust-asg-sandbox-neu", state = "active", archetype = "standard", owner = { customer = "asg" }
      region = "northeurope", network = { spoke_cidr = "10.32.32.0/20" }
    }
    tenants = [{ name = "astra-group", customer = "astra-group", stamp = "cust-asg-sandbox-neu/construction-dev" }]
  }
  expect_failures = [azurerm_resource_group.this]
}

run "dedicated_with_two_tenants" {
  command = plan
  variables {
    tenants = [
      { name = "corporate-site", customer = "trislab", stamp = "products-sandbox-neu/corporate-site-staging" },
      { name = "other", customer = "trislab", stamp = "products-sandbox-neu/corporate-site-staging" },
    ]
  }
  expect_failures = [azurerm_resource_group.this]
}

run "ttl_in_prod" {
  command = plan
  override_module {
    target = module.catalog
    outputs = {
      folder      = "corporate-site"
      lz_folder   = "products-prod-neu"
      owners      = [{ slug = "corporate-site", kind = "product", code = "web", state = "active" }]
      ipam_stamps = { products-prod-neu = { corporate-site = "10.16.0.0/27" } }
    }
  }
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-prod-neu", product = "corporate-site"
      environment = "prod", tenancy = "dedicated", ttl = "7d", network = { subnet_cidr = "10.16.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
    lz = {
      name   = "products-prod-neu", state = "active", archetype = "standard", owner = { products = true }
      region = "northeurope", network = { spoke_cidr = "10.16.0.0/20" }
    }
    tenants = [{ name = "corporate-site", customer = "trislab", stamp = "products-prod-neu/corporate-site" }]
  }
  expect_failures = [azurerm_resource_group.this]
}

run "preview_without_ttl" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.0.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "pr42", tenancy = "dedicated", network = { subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "hostname_to_internal_app" {
  command = plan
  variables {
    tenants = [{
      name      = "corporate-site", customer = "trislab", stamp = "products-sandbox-neu/corporate-site-staging"
      hostnames = [{ fqdn = "staging-corporate-site.trislab.com", app = "api" }]
    }]
  }
  expect_failures = [azurerm_resource_group.this]
}


run "managed_with_subnet" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.2.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { mode = "managed", subnet_cidr = "10.32.0.0/27" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [var.config]
}

run "vnet_without_subnet" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.2.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = {}
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [var.config]
}

run "unknown_network_mode" {
  command = plan
  variables {
    config = {
      template    = "aca-app", version = "v1.2.0", lz = "products-sandbox-neu", product = "corporate-site"
      environment = "staging", tenancy = "dedicated", network = { mode = "private" }
      apps = [{
        name = "web", repo = "trislab-website-corporate-site", profile = "Consumption", ingress = "external", port = 8080
        caps = { cpu = 0.5, memory = "1Gi", max_replicas = 2 }
      }]
    }
  }
  expect_failures = [var.config]
}

# The folder still has its range in catalog/ipam.yaml.
run "managed_with_ipam_range" {
  command = plan
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
  expect_failures = [azurerm_resource_group.this]
}

run "managed_in_regulated_lz" {
  command = plan
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
    lz = {
      name   = "products-sandbox-neu", state = "active", archetype = "regulated", owner = { products = true }
      region = "northeurope", network = { spoke_cidr = "10.32.0.0/20" }
    }
  }
  expect_failures = [azurerm_resource_group.this]
}
