# Step 6 of 06-stamp-templates.md section 6.1: one ca-<stamp>-<app> per app,
# then the hostnames of the external apps.

locals {
  platform_settings = {
    PLATFORM_STAMP       = local.stamp
    PLATFORM_ENVIRONMENT = var.config.environment
    PLATFORM_TENANCY     = var.config.tenancy
    PLATFORM_TENANTS     = join(",", var.tenants[*].name)
  }
}

# Every app starts on the placeholder with the smallest size. From the first
# app deploy, the images, sizing and profile belong to the app repository's
# CI, so they are ignored here (06 section 6.3).
resource "azurerm_container_app" "this" {
  for_each                     = local.apps
  name                         = "ca-${local.stamp}-${each.key}"
  resource_group_name          = azurerm_resource_group.this.name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  workload_profile_name        = each.value.profile
  tags = merge(local.tags, {
    SizingCaps = "cpu=${local.caps[each.key].cpu};memory=${local.caps[each.key].memory};minreplicas=${local.caps[each.key].min_replicas};maxreplicas=${local.caps[each.key].max_replicas};profiles=${join(",", local.caps[each.key].profiles)}"
  })

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }

  # Key Vault references, read through the workload identity (section 6.4).
  dynamic "secret" {
    for_each = toset(concat(each.value.secrets, ["ghcr-pull"]))
    content {
      name                = secret.key
      identity            = azurerm_user_assigned_identity.workload.id
      key_vault_secret_id = module.secrets.versionless_ids[secret.key]
    }
  }

  # Every image in GHCR is private, the placeholder too (section 6.3).
  registry {
    server               = "ghcr.io"
    username             = "tl-ghcr-reader"
    password_secret_name = "ghcr-pull"
  }

  dynamic "ingress" {
    for_each = each.value.ingress == "none" ? [] : [each.value]
    content {
      external_enabled = ingress.value.ingress == "external"
      target_port      = ingress.value.port
      transport        = "auto"

      traffic_weight {
        latest_revision = true
        percentage      = 100
      }
    }
  }

  template {
    min_replicas = 0
    max_replicas = 1

    container {
      name   = each.key
      image  = local.placeholder_image
      cpu    = 0.25
      memory = "0.5Gi"

      dynamic "env" {
        for_each = merge(each.value.env, local.platform_settings)
        content {
          name  = env.key
          value = env.value
        }
      }

      # A secret session-key appears as SESSION_KEY (section 6.4).
      dynamic "env" {
        for_each = toset(each.value.secrets)
        content {
          name        = upper(replace(env.key, "-", "_"))
          secret_name = env.key
        }
      }

      dynamic "liveness_probe" {
        for_each = each.value.ingress == "none" ? [] : [each.value.port]
        content {
          transport = "HTTP"
          port      = liveness_probe.value
          path      = "/healthz"
        }
      }

      dynamic "readiness_probe" {
        for_each = each.value.ingress == "none" ? [] : [each.value.port]
        content {
          transport = "HTTP"
          port      = readiness_probe.value
          path      = "/readyz"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      workload_profile_name,
      template[0].min_replicas,
      template[0].max_replicas,
      template[0].container[0].image,
      template[0].container[0].cpu,
      template[0].container[0].memory,
      template[0].init_container,
    ]
  }
}

module "hostname_bindings" {
  source                = "../../blocks/hostname-bindings"
  stamp                 = local.stamp
  lz_name               = var.lz.name
  hostnames             = { for h, app in local.hostnames : h => azurerm_container_app.this[app].id if contains(local.external_apps, app) }
  environment_id        = azurerm_container_app_environment.this.id
  verification_id       = azurerm_container_app_environment.this.custom_domain_verification_id
  workload_identity_id  = azurerm_user_assigned_identity.workload.id
  workload_principal_id = azurerm_user_assigned_identity.workload.principal_id
  origin_cert_versions  = var.origin_cert_versions
  origin_certs          = var.origin_certs
  tags                  = local.tags
}
