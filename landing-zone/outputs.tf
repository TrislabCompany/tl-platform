output "subscription_id" {
  description = "The subscription's ID, for the root's azurerm provider alias lz."
  value       = azurerm_subscription.this.subscription_id
}
