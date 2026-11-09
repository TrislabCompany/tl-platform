module "catalog" {
  source = "./catalog"
}

locals {
  apps   = { for a in var.config.apps : a.name => a }
  number = var.config.number == null ? "" : var.config.number

  # <scope>-<envtype>-<region code>[-<nn>] (03 section 7.3).
  envtype = try(regex("^.+-(prod|sandbox)-[a-z0-9]+(?:-[0-9]{2})?$", var.lz.name)[0], null)

  product = try(one([for o in module.catalog.owners : o if o.kind == "product" && o.slug == var.config.product && o.state == "active"]), null)
  customer = var.lz.owner.customer == null ? null : try(one([
    for o in module.catalog.owners : o if o.kind == "customer" && o.code == var.lz.owner.customer
  ]), null)

  # <owner-code>-<product-code>-<environment>[-<number>] (06 section 3.2).
  owner_code = var.lz.owner.products ? "shr" : var.lz.owner.customer
  stamp      = join("-", compact([local.owner_code, try(local.product.code, "unregistered"), var.config.environment, local.number]))

  # 03 section 9.
  tags = {
    Product         = var.config.product
    Customer        = local.customer == null ? "trislab" : local.customer.slug
    EnvironmentType = coalesce(local.envtype, "unknown")
    EnvironmentName = var.config.environment
  }

  # 06 section 3.1, 11 section 2.2.
  app_environment = coalesce(var.config.app_environment, local.customer == null ? var.config.environment : "${local.customer.slug}-${var.config.environment}")

  # 06 section 6.2, ADR 0058.
  vnet = var.config.network.mode == "vnet"

  external_apps = [for a in var.config.apps : a.name if a.ingress == "external"]

  # The default hostname goes to the first external app; every other external
  # app gets the derived hostname, with -<app> added to the first label (07
  # section 3.1). Derived only when the default hostname is in the catalog, as
  # global/edge does.
  default_label = join("-", compact([
    var.config.environment, var.config.product, try(local.customer.slug, ""), local.number
  ]))
  default_hostname = "${local.default_label}.trislab.com"
  catalog_hostnames = merge([
    for t in var.tenants : { for h in t.hostnames : h.fqdn => h.app }
  ]...)
  derived_hostnames = contains(keys(local.catalog_hostnames), local.default_hostname) ? {
    for a in slice(local.external_apps, min(1, length(local.external_apps)), length(local.external_apps)) : "${local.default_label}-${a}.trislab.com" => a
  } : {}
  hostnames = merge(local.catalog_hostnames, local.derived_hostnames)

  # The fields that can't change once the stamp exists (06 section 3.1). A
  # vnet stamp keeps the map it was created with, so stamps from before
  # network.mode plan unchanged; a managed one adds the mode.
  fixed = merge({
    template       = var.config.template
    lz             = var.config.lz
    product        = var.config.product
    environment    = var.config.environment
    number         = local.number
    zone_redundant = var.config.zone_redundant
    subnet_cidr    = var.config.network.subnet_cidr
  }, local.vnet ? {} : { network_mode = var.config.network.mode })

  # Each app's caps (06 section 6.5). minreplicas is caps.min_replicas, 0 when
  # not set; zone redundancy, which needs 2, isn't in aca-app v1.x.
  caps = {
    for a in var.config.apps : a.name => {
      cpu          = a.caps.cpu
      memory       = a.caps.memory
      min_replicas = a.caps.min_replicas
      max_replicas = a.caps.max_replicas
      profiles     = coalesce(a.caps.profiles, [a.profile])
    }
  }

  # The placeholder every app starts on (06 section 6.3).
  placeholder_image = "ghcr.io/trislabcompany/platform-placeholder:1.0.0@sha256:d4dc273739987aac86aff1cec676d2d615fc51bf1ab9a4b60cc37ce4a7f89c2f"
}
