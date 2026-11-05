# Steps 1 to 5 of 06-stamp-templates.md section 6.1, and the checks of section
# 4 that the template owns. The apps, step 6, are in apps.tf.

# Holds the fixed fields as they were when the stamp was created: with its
# input ignored, its output never changes, so the resource group's
# precondition compares it with stamp.yaml (06 section 3.1).
resource "terraform_data" "fixed" {
  input = local.fixed

  lifecycle {
    ignore_changes = [input]
  }
}

# ---- Step 1: resource group, and the checks before apply (section 4) ----------

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.stamp}"
  location = var.lz.region
  tags     = local.tags

  lifecycle {
    precondition {
      condition     = var.config.lz == var.lz.name && var.config.lz == module.catalog.lz_folder
      error_message = "lz must equal the landing zone file's name and the stamp's parent folder, ${module.catalog.lz_folder} (06 section 3.1)."
    }
    precondition {
      condition     = var.lz.state == "active" && var.lz.archetype != "experiment"
      error_message = "Landing zone ${var.lz.name} must be active and not an experiment (06 section 3.1)."
    }
    precondition {
      condition     = local.product != null
      error_message = "product ${var.config.product} must be an active product in catalog/owners.yaml (06 section 3.1)."
    }
    precondition {
      condition     = local.envtype == "prod" ? var.config.environment == "prod" : var.config.environment != "prod"
      error_message = "environment prod is only for a prod landing zone, and only prod is (06 section 3.1)."
    }
    precondition {
      condition     = try(module.catalog.ipam_stamps[var.lz.name][module.catalog.folder], null) == var.config.network.subnet_cidr
      error_message = "network.subnet_cidr must be the range of ${module.catalog.folder} under ${var.lz.name} in catalog/ipam.yaml (06 section 3.1)."
    }
    precondition {
      condition = try(
        tonumber(split("/", var.config.network.subnet_cidr)[1]) <= 27 &&
        tonumber(split("/", var.config.network.subnet_cidr)[1]) >= tonumber(split("/", var.lz.network.spoke_cidr)[1]) &&
        cidrhost("${cidrhost(var.config.network.subnet_cidr, 0)}/${split("/", var.lz.network.spoke_cidr)[1]}", 0) == cidrhost(var.lz.network.spoke_cidr, 0),
        false
      )
      error_message = "network.subnet_cidr must be a /27 or larger inside the spoke ${try(var.lz.network.spoke_cidr, "")} (06 section 6.2)."
    }
    precondition {
      condition     = var.lz.owner.customer == null || var.config.tenancy == "dedicated"
      error_message = "A stamp in a customer landing zone is dedicated (06 section 7)."
    }
    precondition {
      condition     = var.config.tenancy == "shared" || length(var.tenants) == 1
      error_message = "A dedicated stamp has exactly one tenant in catalog/tenants.yaml, not ${length(var.tenants)} (06 section 7)."
    }
    precondition {
      condition     = var.config.ttl == null || local.envtype == "sandbox"
      error_message = "ttl is only for a stamp in a sandbox landing zone (06 section 9)."
    }
    precondition {
      condition     = !can(regex("^pr[1-9][0-9]*$", var.config.environment)) || var.config.ttl != null
      error_message = "A pr<n> stamp needs a ttl (06 section 9)."
    }
    precondition {
      condition     = alltrue([for h, app in local.catalog_hostnames : contains(local.external_apps, app)])
      error_message = "Every hostname in catalog/tenants.yaml goes to an app of the stamp with ingress: external (07 section 2.2)."
    }
    precondition {
      condition     = local.envtype != "prod" || length(var.alert_action_group_ids) > 0
      error_message = "A stamp in a prod landing zone needs alert_action_group_ids, from ALERT_ACTION_GROUP_IDS in lz-${var.lz.name}: production never runs without alerts (06 section 6.8)."
    }
    precondition {
      condition     = var.ghcr_pull_token_version != null
      error_message = "landing zone `${var.lz.name}` has no GHCR pull token yet (06 section 6.3)."
    }
    precondition {
      condition     = terraform_data.fixed.output == local.fixed
      error_message = "template, lz, product, environment, number, zone_redundant and network.subnet_cidr can't change once the stamp exists; a change means a new stamp (06 section 3.1)."
    }
  }
}

# ---- Step 2: network ----------------------------------------------------------

module "network" {
  source              = "../../blocks/stamp-network"
  stamp               = local.stamp
  lz_name             = var.lz.name
  envtype             = local.envtype
  spoke_cidr          = var.lz.network.spoke_cidr
  subnet_cidr         = var.config.network.subnet_cidr
  external            = length(local.external_apps) > 0
  cloudflare_ipv4     = var.cloudflare_ips.ipv4
  resource_group_name = azurerm_resource_group.this.name
  location            = var.lz.region
  tags                = local.tags
}

# ---- Step 3: identities -------------------------------------------------------

# The apps and the environment use it (06 section 6.4).
resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${local.stamp}-workload"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.lz.region
  tags                = local.tags
}

module "app_deploy_identity" {
  source              = "../../blocks/app-deploy-identity"
  stamp               = local.stamp
  resource_group_name = azurerm_resource_group.this.name
  location            = var.lz.region
  repos               = var.config.apps[*].repo
  app_repo_ids        = var.app_repo_ids
  github_owner_id     = var.github_owner_id
  app_environment     = local.app_environment
  app_ids             = { for k, a in azurerm_container_app.this : k => a.id }
  tags                = local.tags
}

# ---- Step 4: secrets ----------------------------------------------------------

# The apps' declared secrets start as placeholders an engineer replaces
# through PIM; <stamp>-ghcr-pull is written again exactly when
# GHCR_PULL_TOKEN_VERSION changes (06 sections 6.3 and 6.4, ADR 0026).
module "secrets" {
  source       = "../../blocks/kv-secret-access"
  stamp        = local.stamp
  lz_name      = var.lz.name
  principal_id = azurerm_user_assigned_identity.workload.principal_id
  secrets = merge(
    { for s in distinct(flatten(var.config.apps[*].secrets)) : s => { version = 1, placeholder = true } },
    { ghcr-pull = { version = coalesce(var.ghcr_pull_token_version, 1) } }
  )
  values = { ghcr-pull = var.ghcr_pull_token }
  tags   = local.tags
}

# ---- Step 5: environment ------------------------------------------------------

# Consumption only and no zone redundancy in aca-app/v1.0.0 (06 section 8).
# Recreating it restarts every app and changes its address and verification
# ID: a stop sign in review.
resource "azurerm_container_app_environment" "this" {
  name                               = "cae-${local.stamp}"
  resource_group_name                = azurerm_resource_group.this.name
  location                           = var.lz.region
  infrastructure_subnet_id           = module.network.subnet_id
  infrastructure_resource_group_name = "rg-${local.stamp}-infra"
  zone_redundancy_enabled            = false
  logs_destination                   = "azure-monitor"
  tags                               = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}
