# The inputs of 06-stamp-templates.md section 2, all passed by the generated
# main.tf (section 2.1), and nothing else.

variable "config" {
  description = "The decoded stamp.yaml (06 sections 3.1 and 3.3)."
  type = object({
    template        = string
    version         = string
    lz              = string
    product         = string
    environment     = string
    number          = optional(string)
    tenancy         = string
    zone_redundant  = optional(bool, false)
    app_environment = optional(string)
    ttl             = optional(string)
    network = object({
      subnet_cidr = string
    })
    apps = list(object({
      name    = string
      repo    = string
      profile = string
      ingress = optional(string, "internal")
      port    = optional(number)
      caps = object({
        cpu          = number
        memory       = string
        max_replicas = number
        profiles     = optional(list(string))
      })
      secrets = optional(list(string), [])
      env     = optional(map(string), {})
    }))
    workload_profiles = optional(any)
    data              = optional(any)
  })

  validation {
    condition     = var.config.template == "aca-app"
    error_message = "template must be aca-app."
  }

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.config.version))
    error_message = "version must be v<major>.<minor>.<patch>."
  }

  validation {
    condition     = can(regex("^(dev|test|uat|perf|demo|staging|prod|pr[1-9][0-9]*)$", var.config.environment))
    error_message = "environment must be dev, test, uat, perf, demo, staging, pr<n> or prod (06 section 3.1)."
  }

  validation {
    condition     = var.config.number == null || can(regex("^(0[1-9]|[1-9][0-9])$", var.config.number))
    error_message = "number must be two digits, 01 to 99, written as a string in stamp.yaml (06 section 3.1)."
  }

  validation {
    condition     = contains(["shared", "dedicated"], var.config.tenancy)
    error_message = "tenancy must be shared or dedicated (06 section 7)."
  }

  # aca-app/v1.0.0 has the Consumption profile only, no zone redundancy and no
  # backing services (06 section 8).
  validation {
    condition     = !var.config.zone_redundant && var.config.workload_profiles == null
    error_message = "aca-app/v1.0.0 has no zone_redundant: true and no workload_profiles (06 section 8)."
  }

  validation {
    condition     = var.config.data == null
    error_message = "aca-app/v1.0.0 has no data; aca-app/v1.1.0 adds it (06 section 8)."
  }

  validation {
    condition     = var.config.ttl == null || can(regex("^[1-9][0-9]*[hd]$", var.config.ttl))
    error_message = "ttl must be <n>h or <n>d (06 section 3.1)."
  }

  validation {
    condition = var.config.ttl == null || try(
      endswith(var.config.ttl, "h") ? tonumber(trimsuffix(var.config.ttl, "h")) <= 720 : tonumber(trimsuffix(var.config.ttl, "d")) <= 30,
      false
    )
    error_message = "ttl is at most 30d (06 section 9)."
  }

  validation {
    condition     = length(var.config.apps) >= 1 && length(var.config.apps) <= 10
    error_message = "apps must have 1 to 10 entries (06 section 3.3)."
  }

  validation {
    condition     = alltrue([for a in var.config.apps : can(regex("^[a-z][a-z0-9]{1,9}$", a.name))]) && length(distinct(var.config.apps[*].name)) == length(var.config.apps)
    error_message = "Each apps[].name is 2 to 10 lowercase letters and digits, starting with a letter, and unique in the stamp (06 section 3.3)."
  }

  # The service names of svc-container stay free for aca-app/v1.1.0 (06
  # section 6.7).
  validation {
    condition     = length(setintersection(var.config.apps[*].name, ["postgres", "cache", "messaging", "storage", "search"])) == 0
    error_message = "postgres, cache, messaging, storage and search are reserved for backing services (06 section 6.7)."
  }

  validation {
    condition     = alltrue([for a in var.config.apps : a.profile == "Consumption" && (a.caps.profiles == null || a.caps.profiles == ["Consumption"])])
    error_message = "aca-app/v1.0.0 has the Consumption profile only (06 section 8)."
  }

  validation {
    condition     = alltrue([for a in var.config.apps : contains(["external", "internal", "none"], a.ingress)])
    error_message = "apps[].ingress must be external, internal or none (06 section 3.3)."
  }

  validation {
    condition = alltrue([
      for a in var.config.apps : a.ingress == "none" ? a.port == null : try(a.port >= 1 && a.port <= 65535 && floor(a.port) == a.port, false)
    ])
    error_message = "apps[].port, 1 to 65535, is set exactly when ingress isn't none (06 section 3.3)."
  }

  # The limits of Consumption (06 section 3.3).
  validation {
    condition = alltrue([
      for a in var.config.apps : a.caps.cpu > 0 && a.caps.cpu <= 4 && try(tonumber(regex("^([0-9]+(?:\\.[0-9]+)?)Gi$", a.caps.memory)[0]) <= 8, false)
    ])
    error_message = "apps[].caps must fit Consumption: cpu above 0 and at most 4, memory <n>Gi at most 8Gi (06 section 3.3)."
  }

  validation {
    condition     = alltrue([for a in var.config.apps : a.caps.max_replicas >= 1 && a.caps.max_replicas <= 300 && floor(a.caps.max_replicas) == a.caps.max_replicas])
    error_message = "apps[].caps.max_replicas must be 1 to 300 (06 section 3.3)."
  }

  # ghcr-pull and origin-<zone> are the template's own secrets (06 section 6.4).
  validation {
    condition = alltrue(flatten([
      for a in var.config.apps : [for s in a.secrets : can(regex("^[a-z0-9][a-z0-9-]*$", s)) && s != "ghcr-pull" && !startswith(s, "origin-")]
    ]))
    error_message = "apps[].secrets are lowercase letters, digits and -, and not ghcr-pull or origin-* (06 section 6.4)."
  }

  validation {
    condition     = alltrue(flatten([for a in var.config.apps : [for k in keys(a.env) : can(regex("^[A-Z_][A-Z0-9_]*$", k)) && !startswith(k, "PLATFORM_")]]))
    error_message = "apps[].env names are capitals, digits and _, and don't start with PLATFORM_, which the template sets (06 section 6.3)."
  }
}

variable "lz" {
  description = "The decoded landing-zones/<lz>.yaml (05 section 2). Only the fields the template reads are typed."
  type = object({
    name      = string
    state     = string
    archetype = string
    owner = object({
      customer = optional(string)
      product  = optional(string)
      products = optional(bool, false)
      platform = optional(bool, false)
    })
    region = optional(string)
    network = optional(object({
      spoke_cidr = string
    }))
  })
}

variable "tenants" {
  description = "The entries of catalog/tenants.yaml whose stamp is this one (07 section 2.2)."
  type = list(object({
    name     = string
    customer = string
    stamp    = string
    hostnames = optional(list(object({
      fqdn = string
      app  = string
    })), [])
  }))
}

variable "cloudflare_ips" {
  description = "The decoded catalog/cloudflare-ips.yaml (07 section 12)."
  type = object({
    ipv4 = list(string)
    ipv6 = list(string)
  })
}

variable "data_access" {
  description = "The object IDs of the landing zone's data access groups. Unused until the managed data blocks (06 section 6.7)."
  type = object({
    readers = string
    admins  = string
  })
}

variable "github_owner_id" {
  description = "The organization's numeric ID, for the federated credentials' subject (06 section 6.3)."
  type        = number
}

variable "app_repo_ids" {
  description = "Repository name -> numeric repository ID, from APP_REPO_IDS in lz-<lz>."
  type        = map(number)
  default     = {}
}

variable "origin_cert_versions" {
  description = "<ZONE> -> version of the zone's origin certificate, from ORIGIN_CERT_<ZONE>_VERSION in lz-<lz>."
  type        = map(number)
  default     = {}
}

variable "edge_hostnames" {
  description = "The hostnames whose records global/edge has written, from EDGE_HOSTNAMES in lz-<lz>. The template binds only these (06 section 6.6)."
  type        = list(string)
  default     = []
}

variable "origin_certs" {
  description = "<ZONE> -> the PEM certificate and its private key, from the secrets ORIGIN_CERT_<ZONE> in lz-<lz>, on apply only."
  type        = map(string)
  default     = {}
  sensitive   = true
  ephemeral   = true
}

variable "ghcr_pull_token_version" {
  description = "The version of the GHCR pull token, from GHCR_PULL_TOKEN_VERSION in lz-<lz>. Null fails the plan (06 section 6.3)."
  type        = number
  default     = null
}

variable "ghcr_pull_token" {
  description = "The GHCR pull token, from the secret GHCR_PULL_TOKEN in lz-<lz>, on apply only."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}
