# Step 7 of 05-landing-zones.md section 4: the access entries, as direct role
# assignments on the subscription while pim is false. In prod, grp-devops then
# gets Reader, and its other roles go to grp-platform-admins (ADR 0053).
# Removed when the landing zone is decommissioned (section 7).

locals {
  access = local.active ? {
    for a in distinct(flatten([
      for a in var.lz.access : local.prod && a.group == "grp-devops" ? concat(
        [{ group = "grp-devops", role = "Reader" }],
        a.role == "Reader" ? [] : [{ group = "grp-platform-admins", role = a.role }],
      ) : [{ group = a.group, role = a.role }]
    ])) : "${a.group}/${a.role}" => a
  } : {}
}

data "azuread_group" "access" {
  for_each         = toset([for a in local.access : a.group])
  display_name     = each.key
  security_enabled = true
}

resource "azurerm_role_assignment" "access" {
  for_each           = local.access
  scope              = local.subscription_scope
  role_definition_id = "${local.subscription_scope}/providers/Microsoft.Authorization/roleDefinitions/${local.roles[each.value.role]}"
  principal_id       = data.azuread_group.access[each.value.group].object_id
  principal_type     = "Group"

  depends_on = [azapi_resource_action.management_group]
}
