variable "stamp" {
  description = "The stamp code, the prefix of every secret name (03 section 7.4)."
  type        = string
}

variable "lz_name" {
  description = "The landing zone's name, whose Key Vault is in rg-<lz>-security."
  type        = string
}

variable "principal_id" {
  description = "The principal ID of id-<stamp>-workload."
  type        = string
}

variable "secrets" {
  description = "Name without the stamp prefix -> version and content type. A placeholder is written once with the text placeholder and never changed by the template (06 section 6.4); every other value comes from values."
  type = map(object({
    version      = number
    content_type = optional(string, "")
    placeholder  = optional(bool, false)
  }))

  validation {
    condition     = alltrue([for k in keys(var.secrets) : can(regex("^[a-z0-9][a-z0-9-]*$", k))])
    error_message = "A secret name has lowercase letters, digits and -."
  }
}

variable "values" {
  description = "Name -> value of the secrets that aren't placeholders. Ephemeral, so it never reaches a saved plan or the state; null at plan."
  type        = map(string)
  default     = {}
  sensitive   = true
  ephemeral   = true
}

variable "tags" {
  description = "The four mandatory tags."
  type        = map(string)
}
