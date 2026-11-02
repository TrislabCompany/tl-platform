output "subnet_id" {
  description = "The ID of snet-<stamp>, with the NSG attached."
  value       = azurerm_subnet_network_security_group_association.this.subnet_id
}

output "rules" {
  description = "The NSG's rules by name, as written."
  value       = local.rules
}
