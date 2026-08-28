# =============================================================================
# AWS Budget Module
# =============================================================================
# Cria um orçamento mensal com alertas por e-mail.
# Limite padrão: USD $10 (~R$ 50 com câmbio de ~5:1).
#
# Recursos criados:
#   - aws_budgets_budget   : Orçamento de custo mensal
#   - aws_sns_topic        : Tópico SNS para notificações alternativas (opcional)
# =============================================================================

# -----------------------------------------------
# Budget de custo mensal
# -----------------------------------------------
resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_amount)
  limit_unit   = var.budget_currency
  time_unit    = var.time_unit

  # -----------------------------------------------
  # Alerta 1: AVISO - 80% do orçamento (previsão)
  # Dispara quando a projeção indica que o gasto
  # atingirá 80% do limite.
  # -----------------------------------------------
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.alert_threshold_warning
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.notification_emails
  }

  # -----------------------------------------------
  # Alerta 2: CRÍTICO - 100% do orçamento (real)
  # Dispara quando o gasto REAL atingir o limite.
  # -----------------------------------------------
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.alert_threshold_critical
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_emails
  }

  # -----------------------------------------------
  # Alerta 3: EXCEDIDO - 110% do orçamento (real)
  # Último recurso caso o limite já tenha sido
  # ultrapassado significativamente.
  # -----------------------------------------------
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 110
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.notification_emails
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-monthly-budget"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}
