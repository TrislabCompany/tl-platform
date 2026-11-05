# The alert rules of 06-stamp-templates.md section 6.8, in a prod landing zone
# only, so production never runs without alerts. A sandbox stamp creates none.
# They go to the action groups in alert_action_group_ids: ag-platform, and the
# product team's shared mailbox once the catalog has one.

locals {
  alerts_on = local.envtype == "prod"

  # Restarts: every app. Server errors: every app with ingress. No replica:
  # every app with ingress whose lower replica limit is above 0, which only the
  # caps can promise (the deploy refuses a min_replicas below them).
  restart_alerts = local.alerts_on ? local.apps : {}
  ingress_alerts = local.alerts_on ? { for k, a in local.apps : k => a if a.ingress != "none" } : {}
  replica_alerts = { for k, a in local.ingress_alerts : k => a if local.caps[k].min_replicas > 0 }
}

resource "azurerm_monitor_metric_alert" "restarts" {
  for_each            = local.restart_alerts
  name                = "${local.stamp}-${each.key}-restarts"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_container_app.this[each.key].id]
  description         = "ca-${local.stamp}-${each.key}: its replicas restarted more than 3 times in 15 minutes (06 section 6.8)."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "RestartCount"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 3
  }

  dynamic "action" {
    for_each = toset(var.alert_action_group_ids)
    content {
      action_group_id = action.value
    }
  }
}

# Azure Monitor can't divide one metric by another, so the "more than 5 per
# cent of requests" of section 6.8 is a count until the observability
# platform app: 5 or more answers with 5xx in 15 minutes, the nearest window
# to 10 minutes that a metric alert has.
resource "azurerm_monitor_metric_alert" "server_errors" {
  for_each            = local.ingress_alerts
  name                = "${local.stamp}-${each.key}-server-errors"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_container_app.this[each.key].id]
  description         = "ca-${local.stamp}-${each.key}: 5 or more requests answered with 5xx in 15 minutes (06 section 6.8)."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 4

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  dynamic "action" {
    for_each = toset(var.alert_action_group_ids)
    content {
      action_group_id = action.value
    }
  }
}

resource "azurerm_monitor_metric_alert" "no_replica" {
  for_each            = local.replica_alerts
  name                = "${local.stamp}-${each.key}-no-replica"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_container_app.this[each.key].id]
  description         = "ca-${local.stamp}-${each.key}: no running replica for 5 minutes, although its lower replica limit is ${local.caps[each.key].min_replicas} (06 section 6.8)."
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.tags

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Replicas"
    aggregation      = "Maximum"
    operator         = "LessThan"
    threshold        = 1
  }

  dynamic "action" {
    for_each = toset(var.alert_action_group_ids)
    content {
      action_group_id = action.value
    }
  }
}
