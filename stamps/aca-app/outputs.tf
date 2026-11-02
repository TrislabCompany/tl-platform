output "caps" {
  description = "Each app's sizing caps, which platform.yaml is checked against (06 section 6.5)."
  value       = local.caps
}

output "app_deploy_client_id" {
  description = "The client ID of id-<stamp>-appdeploy, which global/github writes into each app repository's Environment (06 section 6.3)."
  value       = module.app_deploy_identity.client_id
}

output "environment_address" {
  description = "The environment's static IP address, which global/edge points the hostnames at (06 section 6.6). For troubleshooting."
  value       = azurerm_container_app_environment.this.static_ip_address
}

output "verification_id" {
  description = "The environment's custom domain verification ID, which the asuid records hold (06 section 6.6). For troubleshooting."
  value       = azurerm_container_app_environment.this.custom_domain_verification_id
}
