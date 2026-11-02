# Writes secrets <stamp>-<name> into the landing zone's Key Vault and gives the
# workload identity Key Vault Secrets User on each one, not on the vault
# (06-stamp-templates.md section 6.4). Values are write-only, so they never
# reach the state; each is written again exactly when its version changes.

# The vault's suffix is in the landing zone's state, so it is found by type in
# rg-<lz>-security.
data "azurerm_resources" "key_vault" {
  resource_group_name = "rg-${var.lz_name}-security"
  type                = "Microsoft.KeyVault/vaults"
}

locals {
  key_vault_id = one(data.azurerm_resources.key_vault.resources).id

  key_vault_secrets_user = "${regex("^/subscriptions/[^/]+", local.key_vault_id)}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6"
}

# Only the apply job gets the Environment's secrets, but the provider needs a
# value at plan too; nothing is written at plan, so a stand-in is enough.
resource "azurerm_key_vault_secret" "this" {
  for_each         = var.secrets
  name             = "${var.stamp}-${each.key}"
  key_vault_id     = local.key_vault_id
  content_type     = each.value.content_type
  value_wo         = each.value.placeholder ? "placeholder" : try(coalesce(var.values[each.key]), "not-passed-at-plan")
  value_wo_version = each.value.version
  tags             = var.tags
}

resource "azurerm_role_assignment" "this" {
  for_each           = var.secrets
  scope              = azurerm_key_vault_secret.this[each.key].resource_versionless_id
  role_definition_id = local.key_vault_secrets_user
  principal_id       = var.principal_id
  principal_type     = "ServicePrincipal"
}
