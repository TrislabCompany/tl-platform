variable "stamp" {
  description = "The stamp code (06 section 3.2)."
  type        = string
}

variable "resource_group_name" {
  description = "rg-<stamp>."
  type        = string
}

variable "location" {
  description = "The landing zone's region."
  type        = string
}

variable "repos" {
  description = "The apps[].repo of the stamp, one entry per app."
  type        = list(string)
}

variable "app_repo_ids" {
  description = "Repository name -> numeric repository ID, from APP_REPO_IDS in lz-<lz>."
  type        = map(number)
}

variable "github_owner_id" {
  description = "The organization's numeric ID."
  type        = number
}

variable "app_environment" {
  description = "The GitHub Environment of the app repositories that the identity trusts (06 section 3.1)."
  type        = string
}

variable "app_ids" {
  description = "App name -> ID of ca-<stamp>-<app>, each of which gets \"Stamp app deploy\"."
  type        = map(string)
}

variable "tags" {
  description = "The four mandatory tags."
  type        = map(string)
}
