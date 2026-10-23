# Step 6 of 05-landing-zones.md section 4. It stays when the landing zone is
# decommissioned or cancelled, and goes with the subscription (section 7).

resource "azurerm_consumption_budget_subscription" "this" {
  name            = "budget-${local.name}"
  subscription_id = local.subscription_scope
  amount          = var.lz.budget.monthly_eur
  time_grain      = "Monthly"

  # A budget starts on the first of a month and keeps its start date.
  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp())
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      threshold      = notification.value
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Actual"
      contact_groups = [local.ag_finops]
    }
  }

  lifecycle {
    ignore_changes = [time_period]
  }

  depends_on = [time_sleep.wait_for_providers]
}
