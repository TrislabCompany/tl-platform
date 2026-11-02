output "versionless_ids" {
  description = "Name without the stamp prefix -> the secret's versionless URL, for Key Vault references. Whatever uses it waits for the reader's role assignments."
  value       = { for k, s in azurerm_key_vault_secret.this : k => s.versionless_id }

  depends_on = [azurerm_role_assignment.this]
}
