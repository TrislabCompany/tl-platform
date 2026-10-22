variable "lz" {
  description = "The decoded landing-zones/<lz>.yaml (05-landing-zones.md section 2)."
  type = object({
    name      = string
    state     = string
    cloud     = string
    archetype = string
    owner = object({
      customer = optional(string)
      product  = optional(string)
      products = optional(bool, false)
      platform = optional(bool, false)
    })
    subscription = optional(string)
    region       = optional(string)
    network = optional(object({
      spoke_cidr = string
    }))
    budget = object({
      monthly_eur     = number
      notify_customer = optional(bool, false)
    })
    access = optional(list(object({
      group = string
      role  = string
      pim   = optional(bool, false)
    })), [])
    observability = optional(object({
      dedicated_workspace = optional(bool, false)
    }))
    production_data   = optional(bool)
    decommissioned_on = optional(string)
    hold_days         = optional(number)
    ttl               = optional(string)
  })

  validation {
    condition     = var.lz.cloud == "azure"
    error_message = "This release builds only Azure landing zones. GCP is built with the first GCP customer (ADR 0008)."
  }

  validation {
    condition     = contains(["active", "decommissioned", "cancelled"], var.lz.state)
    error_message = "state must be active, decommissioned or cancelled (05-landing-zones.md section 7)."
  }

  validation {
    condition     = var.lz.state == "active" || var.lz.decommissioned_on != null
    error_message = "A landing zone that isn't active needs decommissioned_on (05-landing-zones.md section 2)."
  }

  validation {
    condition     = contains(["standard", "regulated", "experiment"], var.lz.archetype)
    error_message = "archetype must be standard, regulated or experiment (05-landing-zones.md section 2)."
  }

  validation {
    condition     = length([for k, v in var.lz.owner : k if v != null && v != false]) == 1
    error_message = "owner must be exactly one of customer, product, products or platform (05-landing-zones.md section 2)."
  }

  validation {
    condition     = var.lz.subscription == "sub-${var.lz.name}"
    error_message = "subscription must be sub- followed by name (05-landing-zones.md section 2)."
  }

  validation {
    condition = (var.lz.archetype == "experiment") == (
      can(regex("^exp-[a-z0-9]{2,12}$", var.lz.name)) && var.lz.owner.platform
    )
    error_message = "An experiment, and only an experiment, is named exp-<topic> and owned by { platform: true } (ADR 0051)."
  }

  validation {
    condition = var.lz.archetype != "experiment" || (
      var.lz.region == null && var.lz.network == null && var.lz.observability == null
    )
    error_message = "An experiment has no region, network or observability (05-landing-zones.md section 4.1)."
  }

  # 90 days when the file is added, raised by PR to at most 180 in total
  # (ADR 0051). The 90 is checked against main by policy/catalog.rego.
  validation {
    condition = var.lz.archetype != "experiment" || (
      can(regex("^[1-9][0-9]*d$", var.lz.ttl)) && try(tonumber(trimsuffix(var.lz.ttl, "d")) <= 180, false)
    )
    error_message = "An experiment needs ttl as <n>d, at most 180d in total (ADR 0051)."
  }

  validation {
    condition     = var.lz.archetype != "experiment" || var.lz.budget.monthly_eur <= 200
    error_message = "An experiment's budget is at most 200 EUR a month (14-operating-model.md section 3)."
  }

  validation {
    condition = var.lz.archetype == "experiment" || (
      var.lz.region != null && var.lz.network != null
    )
    error_message = "A landing zone needs region and network.spoke_cidr (05-landing-zones.md section 2)."
  }

  validation {
    condition     = var.lz.archetype != "regulated" || try(var.lz.observability.dedicated_workspace, false)
    error_message = "A regulated landing zone needs observability.dedicated_workspace: true (05-landing-zones.md section 2)."
  }

  # Set at all, true or false, only in prod, as policy/catalog.rego checks.
  validation {
    condition     = var.lz.production_data == null || can(regex("-prod-", var.lz.name))
    error_message = "production_data is set only in a prod landing zone (05-landing-zones.md section 2)."
  }

  validation {
    condition     = var.lz.ttl == null || var.lz.archetype == "experiment"
    error_message = "ttl is set only on an experiment (05-landing-zones.md section 2)."
  }

  # <scope> is products, cust-<code> or prdt-<code> (03 section 7.3).
  validation {
    condition = var.lz.archetype == "experiment" || try(regex("^(.+)-(?:prod|sandbox)-", var.lz.name)[0], "") == (
      var.lz.owner.products ? "products" :
      var.lz.owner.customer != null ? "cust-${var.lz.owner.customer}" :
      var.lz.owner.product != null ? "prdt-${var.lz.owner.product}" : "-"
    )
    error_message = "The name's scope must match owner: products for { products: true }, cust-<code> for a customer, prdt-<code> for a product (03 section 7.3)."
  }

  # Deferred until the first regulated landing zone: its customer-managed key
  # isn't built yet (05-landing-zones.md section 4, step 5).
  validation {
    condition     = var.lz.archetype != "regulated"
    error_message = "archetype regulated is built with the first regulated landing zone, with its customer-managed key."
  }

  validation {
    condition     = var.lz.budget.monthly_eur > 0 && floor(var.lz.budget.monthly_eur) == var.lz.budget.monthly_eur
    error_message = "budget.monthly_eur must be a whole number of euros above 0 (05-landing-zones.md section 2)."
  }

  validation {
    condition     = !var.lz.budget.notify_customer || var.lz.owner.customer != null
    error_message = "budget.notify_customer is for customer landing zones only (05-landing-zones.md section 2)."
  }

  # Deferred until the first customer landing zone: reading contacts-<code>
  # needs a right on kv-platform that isn't granted yet (README of tl-platform).
  validation {
    condition     = !var.lz.budget.notify_customer
    error_message = "budget.notify_customer is built with the first customer landing zone that sets it."
  }

  validation {
    condition = alltrue([
      for a in var.lz.access : contains(["Reader", "Contributor", "Key Vault Reader", "Key Vault Secrets Officer"], a.role)
    ])
    error_message = "An access role must be Reader, Contributor, Key Vault Reader or Key Vault Secrets Officer (05-landing-zones.md section 4, step 7)."
  }
}

variable "catalog" {
  description = "The decoded catalog/ files: owners and regions from owners.yaml and regions.yaml, and landing_zones from ipam.yaml (07 sections 5, 9 and 10)."
  type = object({
    owners = list(object({
      slug  = string
      kind  = string
      code  = string
      state = string
    }))
    regions = list(object({
      name  = string
      cloud = string
      code  = string
      state = string
    }))
    landing_zones = optional(list(object({
      name = string
      cidr = string
    })), [])
  })

  validation {
    condition = anytrue([
      for o in var.catalog.owners : o.state == "active" && (
        (o.kind == "customer" && o.code == var.lz.owner.customer) || (o.kind == "product" && o.code == var.lz.owner.product)
      )
    ]) || var.lz.owner.products || var.lz.owner.platform
    error_message = "The owner's code must be an active entry of that kind in catalog/owners.yaml (05-landing-zones.md section 2)."
  }

  validation {
    condition = var.lz.archetype == "experiment" || anytrue([
      for r in var.catalog.regions : r.cloud == "azure" && r.state == "active" && r.name == var.lz.region && r.code == try(regex("^.+-(?:prod|sandbox)-([a-z0-9]+)(?:-(?:0[2-9]|[1-9][0-9]))?$", var.lz.name)[0], "")
    ])
    error_message = "region must be the active entry in catalog/regions.yaml whose code is the region code in name (05-landing-zones.md section 3)."
  }

  validation {
    condition = var.lz.archetype == "experiment" || anytrue([
      for l in var.catalog.landing_zones : l.name == var.lz.name && l.cidr == try(var.lz.network.spoke_cidr, "")
    ])
    error_message = "network.spoke_cidr must equal the landing zone's range in catalog/ipam.yaml (05-landing-zones.md section 3)."
  }
}

variable "platform_suffix" {
  description = "The 4-digit suffix of the platform's global names, such as kv-platform-<nnnn> and stplatformtfstate<nnnn> (03 section 6)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]{3}$", var.platform_suffix))
    error_message = "platform_suffix must be 4 digits."
  }
}

variable "github_owner_id" {
  description = "The organization's numeric ID, for the immutable OIDC subject (ADR 0045)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_owner_id))
    error_message = "github_owner_id must be a number."
  }
}

variable "github_repository_id" {
  description = "The numeric ID of tl-cloud-infrastructure, for the immutable OIDC subject (ADR 0045)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.github_repository_id))
    error_message = "github_repository_id must be a number."
  }
}

variable "devops_team_id" {
  description = "The numeric ID of the GitHub team devops, the reviewers of lz-<lz> (ADR 0031). Passed in, because the GitHub Apps have no organization permission to read teams (ADR 0019)."
  type        = string

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.devops_team_id))
    error_message = "devops_team_id must be a number."
  }
}

variable "az_billing_account" {
  description = "The billing account name, AZ_BILLING_ACCOUNT (ADR 0011)."
  type        = string

  validation {
    condition     = var.az_billing_account != ""
    error_message = "az_billing_account is empty. Is the repository variable AZ_BILLING_ACCOUNT set?"
  }
}

variable "az_billing_profile" {
  description = "The billing profile name, AZ_BILLING_PROFILE (ADR 0011)."
  type        = string

  validation {
    condition     = var.az_billing_profile != ""
    error_message = "az_billing_profile is empty. Is the repository variable AZ_BILLING_PROFILE set?"
  }
}

variable "az_platform_invoice_section" {
  description = "The ID of the invoice section is-platform, which experiments are billed to. It was made by hand, so its ID isn't its display name (ADR 0011)."
  type        = string

  validation {
    condition     = var.az_platform_invoice_section != ""
    error_message = "az_platform_invoice_section is empty."
  }
}

variable "edge_reader_ids" {
  description = "The object IDs of spn-global-plan and spn-global-apply, which get \"Edge stamp reader\" on the subscription (ADR 0027). Passed in, because the landingzones identities can't read service principals."
  type        = list(string)

  validation {
    condition     = length(var.edge_reader_ids) == 2
    error_message = "edge_reader_ids must hold the object IDs of spn-global-plan and spn-global-apply."
  }
}

variable "pim" {
  description = "Whether the Trislab groups get PIM-eligible instead of direct role assignments. False until Entra ID P2 is bought (ADR 0053)."
  type        = bool
  default     = false

  validation {
    condition     = !var.pim
    error_message = "The PIM-eligible assignments are written when Entra ID P2 is bought (ADR 0053)."
  }
}
