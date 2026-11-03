output "versionless_ids" {
  description = "Name without the stamp prefix -> the secret's versionless URL, for Key Vault references. Whatever uses it waits for the reader's role assignments."
  value       = { for k, s in azapi_resource.this : k => s.output.properties.secretUri }

  depends_on = [azurerm_role_assignment.this]
}
