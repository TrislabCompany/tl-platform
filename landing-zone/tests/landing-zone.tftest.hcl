mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { subscription_id = "081e6efa-cbdd-493d-866e-b85f22419b9a", tenant_id = "e8280d0e-0639-4cc6-b22c-c7f5e24261ec" }
  }
  mock_data "azurerm_role_definition" {
    defaults = { role_definition_id = "11111111-1111-1111-1111-111111111111" }
  }
  mock_data "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/081e6efa-cbdd-493d-866e-b85f22419b9a/resourceGroups/rg-hub-neu/providers/Microsoft.Network/virtualNetworks/vnet-hub-neu" }
  }
  mock_data "azurerm_resources" {
    defaults = { resources = [{ name = "privatelink.blob.core.windows.net", id = "/subscriptions/081e6efa-cbdd-493d-866e-b85f22419b9a/resourceGroups/rg-platform-dns/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net", type = "t", location = "global", resource_group_name = "rg-platform-dns", tags = {} }] }
  }
  mock_resource "azurerm_subscription" {
    defaults = { subscription_id = "22222222-2222-2222-2222-222222222222" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/v" }
  }
}

mock_provider "azurerm" {
  alias = "lz"
  mock_resource "azurerm_resource_group" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg" }
  }
  mock_resource "azurerm_key_vault" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-x-security/providers/Microsoft.KeyVault/vaults/kv" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/v" }
  }
}

mock_provider "azapi" {
  mock_data "azapi_resource_list" {
    defaults = { output = { ids = ["/subscriptions/2/providers/Microsoft.Authorization/roleAssignments/00000000-0000-0000-0000-000000000001"] } }
  }
}

mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = { client_id = "66666666-6666-6666-6666-666666666666", id = "/applications/77777777-7777-7777-7777-777777777777" }
  }
  mock_resource "azuread_service_principal" {
    defaults = { object_id = "88888888-8888-8888-8888-888888888888" }
  }
  mock_data "azuread_group" {
    defaults = { object_id = "33333333-3333-3333-3333-333333333333" }
  }
}

mock_provider "random" {}
mock_provider "time" {}
mock_provider "github" {
  mock_data "github_team" {
    defaults = { id = "123" }
  }
}

variables {
  catalog = {
    owners        = [{ slug = "website-trislab", kind = "product", code = "web", state = "active" }, { slug = "okna-capris", kind = "customer", code = "oc", state = "active" }]
    regions       = [{ name = "northeurope", cloud = "azure", code = "neu", state = "active" }]
    landing_zones = [{ name = "products-sandbox-neu", cidr = "10.32.0.0/20" }, { name = "products-prod-neu", cidr = "10.16.0.0/20" }]
  }
  platform_suffix             = "6884"
  github_owner_id             = "123"
  github_repository_id        = "456"
  az_billing_account          = "ba"
  az_billing_profile          = "bp"
  az_platform_invoice_section = "FLNE-ZNPI-PJA-PGB"
  edge_reader_ids             = ["44444444-4444-4444-4444-444444444444", "55555555-5555-5555-5555-555555555555"]
  lz = {
    name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
    owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
    network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }
    access  = [{ group = "grp-devops", role = "Contributor", pim = true }]
  }
}

run "sandbox" {
  command = apply
  assert {
    condition     = azapi_resource_action.invoice_section[0].resource_id == "/providers/Microsoft.Billing/billingAccounts/ba/billingProfiles/bp/invoiceSections/is-products"
    error_message = "invoice section"
  }
  assert {
    condition     = azapi_resource_action.management_group.resource_id == "/providers/Microsoft.Management/managementGroups/mg-lz-standard/subscriptions/22222222-2222-2222-2222-222222222222"
    error_message = "mg"
  }
  assert {
    condition     = azapi_resource_action.remove_creator_owner.method == "DELETE"
    error_message = "owner"
  }
  assert {
    condition     = keys(azurerm_role_assignment.access) == ["grp-devops/Contributor"]
    error_message = "access"
  }
  assert {
    condition     = startswith(azurerm_key_vault.this[0].name, "kv-products-sandbox-")
    error_message = azurerm_key_vault.this[0].name
  }
  assert {
    condition     = local.tags == { Product = "platform", Customer = "trislab", EnvironmentType = "sandbox", EnvironmentName = "sandbox" }
    error_message = "tags"
  }
  assert {
    condition     = length(azurerm_role_assignment.identity) == 7 && length(azurerm_role_assignment.edge) == 2 && length(github_actions_environment_variable.this) == 5
    error_message = "identities"
  }
  assert {
    condition     = azuread_application_federated_identity_credential.this["deploy/lz-products-sandbox-neu"].subject == "repo:TrislabCompany@123/tl-cloud-infrastructure@456:environment:lz-products-sandbox-neu:job_workflow_ref:TrislabCompany/tl-cloud-infrastructure/.github/workflows/shared-apply.yml@refs/heads/main"
    error_message = "subject"
  }
  assert {
    condition     = azurerm_role_assignment.identity["plan-state"].role_definition_id == "/subscriptions/081e6efa-cbdd-493d-866e-b85f22419b9a/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
    error_message = azurerm_role_assignment.identity["plan-state"].role_definition_id
  }
  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.this) == 1 && length(azurerm_management_lock.this) == 1
    error_message = "dns/lock"
  }
  assert {
    condition     = strcontains(data.azapi_resource_list.owners.response_export_values.ids, "properties.principalId == '${data.azurerm_client_config.platform.object_id}'")
    error_message = "only the creator's Owner assignment is removed"
  }
  assert {
    condition     = strcontains(local.data_roles, "090c5cfd-751d-490a-894a-3ce6f1109419") && strcontains(local.deletable_roles, "090c5cfd-751d-490a-894a-3ce6f1109419") && !strcontains(local.stamp_identity_roles, "090c5cfd-751d-490a-894a-3ce6f1109419") && !strcontains(local.stamp_identity_roles, "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1")
    error_message = "service principals get only the stamp identity roles of ADR 0024"
  }
}

run "prod_devops_mapping" {
  command = apply
  variables {
    lz = {
      name    = "products-prod-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-prod-neu", region = "northeurope"
      network = { spoke_cidr = "10.16.0.0/20" }, budget = { monthly_eur = 100 }
      access = [
        { group = "grp-devops", role = "Contributor", pim = true }, { group = "grp-devops", role = "Key Vault Secrets Officer", pim = true },
        { group = "grp-devops", role = "Key Vault Reader", pim = true }, { group = "grp-devops", role = "Reader", pim = true },
      ]
    }
  }
  assert {
    condition     = jsonencode(sort(keys(azurerm_role_assignment.access))) == jsonencode(["grp-devops/Key Vault Reader", "grp-devops/Reader", "grp-platform-admins/Contributor", "grp-platform-admins/Key Vault Secrets Officer"])
    error_message = jsonencode(keys(azurerm_role_assignment.access))
  }
}

run "decommissioned" {
  command = apply
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "decommissioned", decommissioned_on = "2026-11-01", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }
      access  = [{ group = "grp-devops", role = "Contributor", pim = true }]
    }
  }
  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 0 && length(azuread_application.this) == 0 && length(github_repository_environment.this) == 0 && length(azurerm_role_assignment.access) == 0 && length(azurerm_virtual_network.this) == 1 && length(azapi_resource_action.cancel) == 0
    error_message = "decommissioned"
  }
  assert {
    condition     = strcontains(azapi_resource_action.management_group.resource_id, "/mg-decommissioned/")
    error_message = "mg"
  }
}

run "experiment" {
  command = apply
  variables {
    lz = {
      name   = "exp-test", state = "active", cloud = "azure", archetype = "experiment", ttl = "30d"
      owner  = { platform = true }, subscription = "sub-exp-test", budget = { monthly_eur = 50 }
      access = [{ group = "grp-devops", role = "Contributor", pim = true }]
    }
  }
  assert {
    condition     = length(azurerm_resource_group.this) == 0 && length(azurerm_key_vault.this) == 0 && length(azuread_application.this) == 0 && length(azapi_resource_action.invoice_section) == 0
    error_message = "experiment"
  }
  assert {
    condition     = azurerm_subscription.this.billing_scope_id == "/providers/Microsoft.Billing/billingAccounts/ba/billingProfiles/bp/invoiceSections/FLNE-ZNPI-PJA-PGB" && local.tags.EnvironmentName == "experiment"
    error_message = "billing"
  }
  assert {
    condition     = keys(azurerm_role_assignment.access) == ["grp-devops/Contributor"]
    error_message = "access"
  }
}

run "cancelled_experiment" {
  command = apply
  variables {
    lz = {
      name  = "exp-test", state = "cancelled", decommissioned_on = "2026-11-01", cloud = "azure", archetype = "experiment", ttl = "30d"
      owner = { platform = true }, subscription = "sub-exp-test", budget = { monthly_eur = 50 }
    }
  }
  assert {
    condition     = azapi_resource_action.cancel[0].resource_id == "/providers/Microsoft.Billing/billingAccounts/ba/billingSubscriptions/22222222-2222-2222-2222-222222222222"
    error_message = "cancel"
  }
}

run "wrong_cidr" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.16.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  expect_failures = [var.catalog]
}

run "wrong_region" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "italynorth"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  expect_failures = [var.catalog]
}

run "experiment_too_long" {
  command = plan
  variables {
    lz = {
      name  = "exp-test", state = "active", cloud = "azure", archetype = "experiment", ttl = "200d"
      owner = { platform = true }, subscription = "sub-exp-test", budget = { monthly_eur = 50 }
    }
  }
  expect_failures = [var.lz]
}

run "experiment_over_budget" {
  command = plan
  variables {
    lz = {
      name  = "exp-test", state = "active", cloud = "azure", archetype = "experiment", ttl = "30d"
      owner = { platform = true }, subscription = "sub-exp-test", budget = { monthly_eur = 500 }
    }
  }
  expect_failures = [var.lz]
}

run "production_data_in_sandbox" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }, production_data = false
    }
  }
  expect_failures = [var.lz]
}

run "ttl_outside_experiment" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard", ttl = "30d"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  expect_failures = [var.lz]
}

run "owner_not_scope" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { customer = "oc" }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  expect_failures = [var.lz]
}

run "regulated_not_built" {
  command = plan
  variables {
    lz = {
      name    = "products-prod-neu", state = "active", cloud = "azure", archetype = "regulated"
      owner   = { products = true }, subscription = "sub-products-prod-neu", region = "northeurope"
      network = { spoke_cidr = "10.16.0.0/20" }, budget = { monthly_eur = 100 }, observability = { dedicated_workspace = true }
    }
  }
  expect_failures = [var.lz]
}

run "budget_not_whole" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 99.5 }
    }
  }
  expect_failures = [var.lz]
}

run "budget_zero" {
  command = plan
  variables {
    lz = {
      name    = "products-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { products = true }, subscription = "sub-products-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.32.0.0/20" }, budget = { monthly_eur = 0 }
    }
  }
  expect_failures = [var.lz]
}

run "key_vault_sandbox_short_form" {
  command = apply
  variables {
    catalog = {
      owners        = [{ slug = "long-customer", kind = "customer", code = "abcdef", state = "active" }]
      regions       = [{ name = "northeurope", cloud = "azure", code = "neu", state = "active" }]
      landing_zones = [{ name = "cust-abcdef-sandbox-neu", cidr = "10.48.0.0/20" }]
    }
    lz = {
      name    = "cust-abcdef-sandbox-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { customer = "abcdef" }, subscription = "sub-cust-abcdef-sandbox-neu", region = "northeurope"
      network = { spoke_cidr = "10.48.0.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  assert {
    condition     = startswith(azurerm_key_vault.this[0].name, "kv-cust-abcdef-sb-")
    error_message = azurerm_key_vault.this[0].name
  }
}

run "key_vault_prod_too_long" {
  command = plan
  variables {
    catalog = {
      owners        = [{ slug = "long-customer", kind = "customer", code = "abcdefghijkl", state = "active" }]
      regions       = [{ name = "northeurope", cloud = "azure", code = "neu", state = "active" }]
      landing_zones = [{ name = "cust-abcdefghijkl-prod-neu", cidr = "10.48.0.0/20" }]
    }
    lz = {
      name    = "cust-abcdefghijkl-prod-neu", state = "active", cloud = "azure", archetype = "standard"
      owner   = { customer = "abcdefghijkl" }, subscription = "sub-cust-abcdefghijkl-prod-neu", region = "northeurope"
      network = { spoke_cidr = "10.48.0.0/20" }, budget = { monthly_eur = 100 }
    }
  }
  expect_failures = [azurerm_key_vault.this]
}
