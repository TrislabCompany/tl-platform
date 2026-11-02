output "client_id" {
  description = "The client ID of id-<stamp>-appdeploy, which global/github writes into each app repository's Environment."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "subjects" {
  description = "Repository -> the subject of its federated credential. A repository not yet in app_repo_ids has none."
  value       = { for k, c in azurerm_federated_identity_credential.this : k => c.subject }
}
