# What the template reads from the repository besides its inputs: the stamp's
# folder and landing zone from its path, the owners from catalog/owners.yaml
# and the stamp ranges from catalog/ipam.yaml. path.root is the stamp folder,
# stamps/<lz>/<folder>. A module of its own, so the tests replace it.
#
# A missing file reads as empty, so tofu validate works in the template's own
# folder; in a stamp, the product and range checks then fail and name the file.

locals {
  root   = abspath(path.root)
  ipam   = yamldecode(try(file("${path.root}/../../../catalog/ipam.yaml"), "{}"))
  owners = yamldecode(try(file("${path.root}/../../../catalog/owners.yaml"), "{}"))
}

output "folder" {
  description = "The stamp folder's name."
  value       = basename(local.root)
}

output "lz_folder" {
  description = "The name of the stamp folder's parent, stamps/<lz>."
  value       = basename(dirname(local.root))
}

output "owners" {
  description = "The owners of catalog/owners.yaml."
  value       = try(local.owners.owners, [])
}

output "ipam_stamps" {
  description = "Landing zone name -> its stamps map of catalog/ipam.yaml, folder -> range."
  value       = { for l in try(local.ipam.landing_zones, []) : l.name => try(l.stamps, {}) }
}
