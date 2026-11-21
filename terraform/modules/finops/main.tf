# Optimización de costos: apagado fuera de horario + presupuesto con alertas.

# ---- Apagado de recursos no usados: los nodos se escalan a 0 por la noche ----
resource "aws_autoscaling_schedule" "scale_down" {
  count = var.enable_off_hours_schedule ? 1 : 0

  scheduled_action_name  = "${var.name}-off-hours-down"
  autoscaling_group_name = var.node_group_asg_name
  recurrence             = var.scale_down_cron
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
}

resource "aws_autoscaling_schedule" "scale_up" {
  count = var.enable_off_hours_schedule ? 1 : 0

  scheduled_action_name  = "${var.name}-business-hours-up"
  autoscaling_group_name = var.node_group_asg_name
  recurrence             = var.scale_up_cron
  min_size               = var.scale_up_min_size
  max_size               = var.scale_up_max_size
  desired_capacity       = var.scale_up_desired_size
}

# ---- Presupuesto mensual filtrado por la etiqueta Project ----
resource "aws_budgets_budget" "monthly" {
  count = var.monthly_budget_usd > 0 ? 1 : 0

  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    # Formato AWS: "user:<TagKey>$<TagValue>"
    values = [format("user:Project$%s", var.project)]
  }

  dynamic "notification" {
    for_each = length(var.budget_alert_emails) > 0 ? [
      { threshold = 80, type = "ACTUAL" },
      { threshold = 100, type = "FORECASTED" },
    ] : []

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.budget_alert_emails
    }
  }
}

# ---- Detección de anomalías de costo (servicio gratuito de AWS) ----
resource "aws_ce_anomaly_monitor" "services" {
  name              = "${var.name}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "daily" {
  count = length(var.budget_alert_emails) > 0 ? 1 : 0

  name             = "${var.name}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["10"]
    }
  }

  dynamic "subscriber" {
    for_each = var.budget_alert_emails
    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }
}
