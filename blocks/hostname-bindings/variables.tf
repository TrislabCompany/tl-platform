variable "stamp" {
  description = "The stamp code (06 section 3.2)."
  type        = string
}

variable "lz_name" {
  description = "The landing zone's name, whose Key Vault takes the certificates."
  type        = string
}

variable "hostnames" {
  description = "Hostname -> ID of the container app it goes to, which has ingress: external."
  type        = map(string)
}

variable "environment_id" {
  description = "The ID of cae-<stamp>."
  type        = string
}

variable "verification_id" {
  description = "The environment's custom domain verification ID, which the asuid records hold."
  type        = string
}

variable "workload_identity_id" {
  description = "The resource ID of id-<stamp>-workload, which the environment loads the certificates with."
  type        = string
}

variable "workload_principal_id" {
  description = "The principal ID of id-<stamp>-workload."
  type        = string
}

variable "origin_cert_versions" {
  description = "<ZONE> -> version of the zone's origin certificate, from ORIGIN_CERT_<ZONE>_VERSION in lz-<lz>."
  type        = map(number)
}

variable "origin_certs" {
  description = "<ZONE> -> the PEM certificate and its private key, from the secrets ORIGIN_CERT_<ZONE> in lz-<lz>, on apply only."
  type        = map(string)
  default     = {}
  sensitive   = true
  ephemeral   = true
}

variable "tags" {
  description = "The four mandatory tags."
  type        = map(string)
}
