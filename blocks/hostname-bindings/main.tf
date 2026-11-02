# Binds the stamp's hostnames with the zone's Cloudflare Origin CA certificate
# (06-stamp-templates.md section 6.6, ADR 0027). global/edge writes the DNS
# records and hands over the certificate; a hostname is bound only when its
# asuid record holds the environment's verification ID and its zone's
# certificate is in the Key Vault, and skipped otherwise. The pipeline's next
# apply of the stamp binds it.

locals {
  # A hostname's zone is its longest suffix whose <ZONE> key, in capitals with
  # _ for . and -, is in origin_cert_versions.
  suffixes = {
    for f in keys(var.hostnames) : f => [
      for i in range(length(split(".", f)) - 1) : join(".", slice(split(".", f), i, length(split(".", f))))
    ]
  }
  zone_of = {
    for f, s in local.suffixes : f => try([for z in s : z if contains(keys(var.origin_cert_versions), upper(replace(z, "/[.-]/", "_")))][0], null)
  }
  zones = { for z in distinct([for z in values(local.zone_of) : z if z != null]) : z => upper(replace(z, "/[.-]/", "_")) }

  bound = {
    for f, app_id in var.hostnames : f => app_id
    if local.zone_of[f] == null ? false : (
      length(data.dns_txt_record_set.asuid[f].records) == 0 ? false : contains(data.dns_txt_record_set.asuid[f].records, var.verification_id)
    )
  }
}

# Empty while global/edge hasn't written the record. To check in the pilot:
# that a name that doesn't exist yet returns an empty result (ADR 0027).
data "dns_txt_record_set" "asuid" {
  for_each = var.hostnames
  host     = "asuid.${each.key}"
}

# <stamp>-origin-<zone>, written again exactly when the zone's version changes.
module "origin_certs" {
  source       = "../kv-secret-access"
  stamp        = var.stamp
  lz_name      = var.lz_name
  principal_id = var.workload_principal_id
  secrets      = { for z, key in local.zones : "origin-${replace(z, ".", "-")}" => { version = var.origin_cert_versions[key], content_type = "application/x-pem-file" } }
  values       = { for z, key in local.zones : "origin-${replace(z, ".", "-")}" => try(var.origin_certs[key], null) }
  tags         = var.tags
}

# Loaded from the Key Vault with id-<stamp>-workload, which is assigned to the
# environment.
resource "azurerm_container_app_environment_certificate" "this" {
  for_each                     = local.zones
  name                         = replace(each.key, ".", "-")
  container_app_environment_id = var.environment_id
  tags                         = var.tags

  certificate_key_vault {
    identity            = var.workload_identity_id
    key_vault_secret_id = module.origin_certs.versionless_ids["origin-${replace(each.key, ".", "-")}"]
  }
}

resource "azurerm_container_app_custom_domain" "this" {
  for_each                                 = local.bound
  name                                     = each.key
  container_app_id                         = each.value
  certificate_binding_type                 = "SniEnabled"
  container_app_environment_certificate_id = azurerm_container_app_environment_certificate.this[local.zone_of[each.key]].id
}
