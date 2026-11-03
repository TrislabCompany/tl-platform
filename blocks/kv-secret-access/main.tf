# Writes secrets <stamp>-<name> into the landing zone's Key Vault and gives the
# workload identity Key Vault Secrets User on each one, not on the vault
# (06-stamp-templates.md section 6.4). Values are write-only, so they never
# reach the state; each is written again exactly when its version changes.
#
# Through Azure Resource Manager, not the Key Vault: Resource Manager never
# returns a secret's value, so the plan identity refreshes it with Reader.
# azurerm_key_vault_secret reads the value on every refresh, which Key Vault
# Reader can't (ADR 0024).

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
resource "azapi_resource" "this" {
  for_each  = var.secrets
  type      = "Microsoft.KeyVault/vaults/secrets@2024-11-01"
  parent_id = local.key_vault_id
  name      = "${var.stamp}-${each.key}"
  tags      = var.tags
  body = {
    properties = { contentType = each.value.content_type }
  }
  sensitive_body = {
    properties = { value = each.value.placeholder ? "placeholder" : try(coalesce(var.values[each.key]), "not-passed-at-plan") }
  }
  sensitive_body_version = { "properties.value" = tostring(each.value.version) }
  response_export_values = ["properties.secretUri"]

  # An update sends the value only when its version changes, so the content
  # type and tags are written with the value, never on their own.
  lifecycle {
    ignore_changes = [body, tags]
  }
}

# The secrets of stamps from aca-app/v1.0.1 and earlier.
moved {
  from = azurerm_key_vault_secret.this
  to   = azapi_resource.this
}

resource "azurerm_role_assignment" "this" {
  for_each           = var.secrets
  scope              = azapi_resource.this[each.key].id
  role_definition_id = local.key_vault_secrets_user
  principal_id       = var.principal_id
  principal_type     = "ServicePrincipal"
}
