# Step 8 of 05-landing-zones.md section 4: the GitHub Environment lz-<lz>, the
# pipeline identities spn-lz-<lz>-plan and -deploy, and their roles. Removed
# when the landing zone is decommissioned (section 7).

locals {
  identities = local.connected ? {
    plan = {
      workflow = "shared-plan.yml"
      trust    = { pull-request = "pull_request", main = "ref:refs/heads/main" }
    }
    deploy = {
      workflow = "shared-apply.yml"
      trust    = { (local.environment) = "environment:${local.environment}" }
    }
  } : {}

  environment = "lz-${local.name}"

  # The immutable OIDC subject, pinned to main's reusable workflows (ADR 0045).
  subject_prefix = "repo:TrislabCompany@${var.github_owner_id}/tl-cloud-infrastructure@${var.github_repository_id}"
  workflows      = "job_workflow_ref:TrislabCompany/tl-cloud-infrastructure/.github/workflows"

  credentials = merge([
    for id, i in local.identities : {
      for name, context in i.trust : "${id}/${name}" => {
        identity = id
        name     = name
        subject  = "${local.subject_prefix}:${context}:${local.workflows}/${i.workflow}@refs/heads/main"
      }
    }
  ]...)

  # The data access groups (ADR 0052).
  data_groups = (
    var.lz.archetype == "regulated" ? { readers = null, admins = "grp-regulated-admins" } :
    local.prod ? { readers = "grp-data-${local.name}-readers", admins = "grp-data-${local.name}-admins" } :
    { readers = "grp-data-sandbox-readers", admins = "grp-data-sandbox-admins" }
  )
}

# ---- GitHub Environment -------------------------------------------------------

resource "github_repository_environment" "this" {
  count               = local.connected ? 1 : 0
  repository          = "tl-cloud-infrastructure"
  environment         = local.environment
  prevent_self_review = true

  reviewers {
    teams = [tonumber(var.devops_team_id)]
  }
}

data "azuread_group" "data" {
  for_each         = local.connected ? { for k, v in local.data_groups : k => v if v != null } : {}
  display_name     = each.value
  security_enabled = true
}

locals {
  environment_variables = local.connected ? {
    AZURE_CLIENT_ID_PLAN   = azuread_application.this["plan"].client_id
    AZURE_CLIENT_ID_DEPLOY = azuread_application.this["deploy"].client_id
    AZURE_SUBSCRIPTION_ID  = local.subscription_id
    DATA_READERS_OBJECT_ID = try(data.azuread_group.data["readers"].object_id, "")
    DATA_ADMINS_OBJECT_ID  = data.azuread_group.data["admins"].object_id
  } : {}
}

resource "github_actions_environment_variable" "this" {
  for_each      = local.connected ? toset(keys(local.environment_variables)) : toset([])
  repository    = "tl-cloud-infrastructure"
  environment   = github_repository_environment.this[0].environment
  variable_name = each.key
  value         = local.environment_variables[each.key]
}

# ---- Pipeline identities ------------------------------------------------------

# Owned by spn-landingzones-apply: Application.ReadWrite.OwnedBy lets it add a
# service principal and credentials, update and delete only what it owns, and
# doesn't make it the owner of what it creates (ADR 0034).
resource "azuread_application" "this" {
  for_each     = local.identities
  display_name = "spn-lz-${local.name}-${each.key}"
  owners       = [var.landingzones_apply_id]
}

resource "azuread_service_principal" "this" {
  for_each  = local.identities
  client_id = azuread_application.this[each.key].client_id
  owners    = [var.landingzones_apply_id]
}

# After the Environment, so the deploy identity never trusts an Environment
# that doesn't exist yet (ADR 0019).
resource "azuread_application_federated_identity_credential" "this" {
  for_each       = local.credentials
  application_id = azuread_application.this[each.value.identity].id
  display_name   = each.value.name
  issuer         = "https://token.actions.githubusercontent.com"
  audiences      = ["api://AzureADTokenExchange"]
  subject        = each.value.subject

  depends_on = [github_repository_environment.this]
}

# ---- Roles --------------------------------------------------------------------

locals {
  # ADR 0024: the deploy identity may assign the stamp identity roles to
  # service principals, and the data roles to the landing zone's data groups,
  # and delete an assignment of any of them.
  stamp_identity_role_ids = [
    local.roles["Key Vault Secrets User"],
    data.azurerm_role_definition.stamp_app_deploy.role_definition_id,
    local.roles["Azure Service Bus Data Sender"],
    local.roles["Azure Service Bus Data Receiver"],
    local.roles["Storage Blob Data Contributor"],
  ]
  data_role_ids = [
    local.roles["Azure Service Bus Data Owner"],
    local.roles["Storage Blob Data Reader"],
    local.roles["Storage Blob Data Contributor"],
  ]
  stamp_identity_roles = join(", ", local.stamp_identity_role_ids)
  data_roles           = join(", ", local.data_role_ids)
  deletable_roles      = join(", ", distinct(concat(local.stamp_identity_role_ids, local.data_role_ids)))
  data_group_ids       = join(", ", [for g in data.azuread_group.data : g.object_id])

  deploy_grant_condition = trimspace(<<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.stamp_identity_roles}}
      AND
      @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.data_roles}}
      AND
      @Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${local.data_group_ids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.deletable_roles}}
     )
    )
  EOT
  )

  # ADR 0032, as in 08-pipeline.md section 7: each identity reads, writes and
  # lists only the blobs under <lz>/. The plan identity's has only the read
  # and list parts.
  blobs = "Microsoft.Storage/storageAccounts/blobServices/containers/blobs"
  state_path_condition = {
    for id, write in { plan = false, deploy = true } : id => trimspace(<<-EOT
      (
       (
        !(ActionMatches{'${local.blobs}/read'} AND NOT SubOperationMatches{'Blob.List'})%{if write}
        AND !(ActionMatches{'${local.blobs}/write'})
        AND !(ActionMatches{'${local.blobs}/add/action'})
        AND !(ActionMatches{'${local.blobs}/delete'})%{endif}
       )
       OR
       (@Resource[${local.blobs}:path] StringStartsWith '${local.name}/')
      )
      AND
      (
       !(ActionMatches{'${local.blobs}/read'} AND SubOperationMatches{'Blob.List'})
       OR
       (@Request[${local.blobs}:prefix] StringStartsWith '${local.name}/')
      )
    EOT
    )
  }

  identity_roles = local.connected ? {
    plan-reader = {
      identity = "plan", scope = local.subscription_scope, role = local.roles["Reader"], condition = null
    }
    plan-key-vault = {
      identity = "plan", scope = azapi_resource.key_vault[0].id, role = local.roles["Key Vault Reader"], condition = null
    }
    plan-state = {
      identity = "plan", scope = local.tfstate_stamps, role = local.roles["Storage Blob Data Reader"], condition = local.state_path_condition["plan"]
    }
    deploy-contributor = {
      identity = "deploy", scope = local.subscription_scope, role = local.roles["Contributor"], condition = null
    }
    deploy-grant = {
      identity = "deploy", scope = local.subscription_scope, role = local.roles["Role Based Access Control Administrator"], condition = local.deploy_grant_condition
    }
    deploy-key-vault = {
      identity = "deploy", scope = azapi_resource.key_vault[0].id, role = local.roles["Key Vault Secrets Officer"], condition = null
    }
    deploy-state = {
      identity = "deploy", scope = local.tfstate_stamps, role = local.roles["Storage Blob Data Contributor"], condition = local.state_path_condition["deploy"]
    }
  } : {}
}

resource "azurerm_role_assignment" "identity" {
  for_each           = local.identity_roles
  scope              = each.value.scope
  role_definition_id = "${regex("^/subscriptions/[^/]+", each.value.scope)}/providers/Microsoft.Authorization/roleDefinitions/${each.value.role}"
  principal_id       = azuread_service_principal.this[each.value.identity].object_id
  principal_type     = "ServicePrincipal"
  condition          = each.value.condition
  condition_version  = each.value.condition == null ? null : "2.0"

  depends_on = [azapi_resource_action.management_group]
}

# "Edge stamp reader" for spn-global-plan and spn-global-apply (ADR 0027).
resource "azurerm_role_assignment" "edge" {
  for_each           = local.connected ? toset(var.edge_reader_ids) : toset([])
  scope              = local.subscription_scope
  role_definition_id = "${local.subscription_scope}/providers/Microsoft.Authorization/roleDefinitions/${data.azurerm_role_definition.edge_stamp_reader.role_definition_id}"
  principal_id       = each.key
  principal_type     = "ServicePrincipal"

  depends_on = [azapi_resource_action.management_group]
}
