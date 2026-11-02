<#
.SYNOPSIS
Writes a stamp's main.tf (06-stamp-templates.md section 2.1 in
tl-cloud-infrastructure).

.DESCRIPTION
Run from the root of tl-cloud-infrastructure:

  pwsh <tl-platform>/stamps/aca-app/generate.ps1 -Stamp stamps/<lz>/<folder> -StateAccount stplatformtfstate<nnnn>

The landing zone and folder come from the path, the template and version from
the folder's stamp.yaml. stamp-check.yml runs the generator of the pinned
release and fails the PR when main.tf differs. The output is tofu fmt clean,
with LF line endings.
#>
param(
  [Parameter(Mandatory)] [string] $Stamp,
  [Parameter(Mandatory)] [string] $StateAccount
)

$ErrorActionPreference = 'Stop'

$path = $Stamp.Replace('\', '/').TrimEnd('/')
if ($path -notmatch '^stamps/([a-z0-9]+(?:-[a-z0-9]+)*)/([a-z0-9]+(?:-[a-z0-9]+)*)$') {
  throw "-Stamp must be stamps/<lz>/<folder>, not $Stamp."
}
$lz = $Matches[1]
$folder = $Matches[2]

if ($StateAccount -notmatch '^stplatformtfstate[1-9][0-9]{3}$') {
  throw "-StateAccount must be stplatformtfstate<nnnn>, not $StateAccount."
}

$yaml = Get-Content -Raw -LiteralPath "$path/stamp.yaml"
$template = [regex]::Match($yaml, '(?m)^template:\s*([a-z-]+)\s*$').Groups[1].Value
$version = [regex]::Match($yaml, '(?m)^version:\s*(v[0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (-not $template -or -not $version) {
  throw "$path/stamp.yaml needs template and version: v<major>.<minor>.<patch>."
}

$content = @"
# $path/main.tf (generated, never hand-edited)
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-platform-state"
    storage_account_name = "$StateAccount"
    container_name       = "tfstate-stamps"
    key                  = "$lz/$folder.tfstate"
    use_oidc             = true
    use_azuread_auth     = true # shared key access is off on the state storage
  }
}

provider "azurerm" {
  features {
    key_vault { recover_soft_deleted_secrets = true }
  }
  use_oidc                        = true # client ID and subscription ID come from the lz-$lz Environment
  storage_use_azuread             = true
  resource_provider_registrations = "none" # the landing zone registers them (05 section 4.2)
}

variable "data_access" { # from DATA_READERS_OBJECT_ID and DATA_ADMINS_OBJECT_ID in lz-$lz
  type = object({ readers = string, admins = string })
}
variable "github_owner_id" { # the run's github.repository_owner_id
  type = number
}
variable "app_repo_ids" { # from APP_REPO_IDS in lz-$lz
  type    = map(number)
  default = {}
}
variable "origin_cert_versions" { # from ORIGIN_CERT_<ZONE>_VERSION in lz-$lz
  type    = map(number)
  default = {}
}
variable "origin_certs" { # from the secrets ORIGIN_CERT_<ZONE> in lz-$lz, apply only
  type      = map(string)
  default   = {}
  sensitive = true
  ephemeral = true
}
variable "ghcr_pull_token_version" { # from GHCR_PULL_TOKEN_VERSION in lz-$lz
  type    = number
  default = null # null fails the plan: the landing zone has no pull token yet (section 6.3)
}
variable "ghcr_pull_token" { # from the secret GHCR_PULL_TOKEN in lz-$lz, apply only
  type      = string
  default   = null
  sensitive = true
  ephemeral = true
}

module "stamp" {
  source = "git::https://github.com/TrislabCompany/tl-platform.git//stamps/$template`?ref=$template/$version"
  config = yamldecode(file("`${path.module}/stamp.yaml"))
  lz     = yamldecode(file("`${path.root}/../../../landing-zones/$lz.yaml"))
  tenants = [for t in yamldecode(file("`${path.root}/../../../catalog/tenants.yaml")).tenants : t
  if t.stamp == "$lz/$folder"]
  cloudflare_ips          = yamldecode(file("`${path.root}/../../../catalog/cloudflare-ips.yaml"))
  data_access             = var.data_access
  github_owner_id         = var.github_owner_id
  app_repo_ids            = var.app_repo_ids
  origin_cert_versions    = var.origin_cert_versions
  origin_certs            = var.origin_certs
  ghcr_pull_token_version = var.ghcr_pull_token_version
  ghcr_pull_token         = var.ghcr_pull_token
}

output "stamp" { value = module.stamp }

"@

[System.IO.File]::WriteAllText((Join-Path (Resolve-Path -LiteralPath $path) 'main.tf'), $content.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
