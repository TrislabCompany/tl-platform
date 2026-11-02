variable "stamp" {
  description = "The stamp code (06 section 3.2)."
  type        = string
}

variable "lz_name" {
  description = "The landing zone's name, whose spoke vnet-<lz> in rg-<lz>-network takes the subnet."
  type        = string
}

variable "envtype" {
  description = "The landing zone's environment type, prod or sandbox."
  type        = string

  validation {
    condition     = contains(["prod", "sandbox"], var.envtype)
    error_message = "envtype must be prod or sandbox."
  }
}

variable "spoke_cidr" {
  description = "The landing zone's spoke range."
  type        = string
}

variable "subnet_cidr" {
  description = "The stamp's range, network.subnet_cidr."
  type        = string
}

variable "external" {
  description = "Whether an app has ingress: external, which opens port 443 to Cloudflare (rule 200)."
  type        = bool
}

variable "cloudflare_ipv4" {
  description = "The ipv4 list of catalog/cloudflare-ips.yaml."
  type        = list(string)
}

variable "resource_group_name" {
  description = "rg-<stamp>, which holds the NSG."
  type        = string
}

variable "location" {
  description = "The landing zone's region."
  type        = string
}

variable "tags" {
  description = "The four mandatory tags."
  type        = map(string)
}
