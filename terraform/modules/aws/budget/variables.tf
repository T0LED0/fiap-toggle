variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "togglemaster"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, staging, prod)"
  default     = "dev"
}

variable "budget_limit_amount" {
  type        = number
  description = "Maximum monthly cost limit in USD. R$50 ~ USD$10 at conservative exchange rate (~5:1)."
  default     = 10
}

variable "budget_currency" {
  type        = string
  description = "Currency for the budget limit. AWS Budgets only supports USD."
  default     = "USD"
}

variable "notification_emails" {
  type        = list(string)
  description = "List of email addresses to notify when budget thresholds are exceeded"
}

variable "alert_threshold_warning" {
  type        = number
  description = "Percentage of the budget at which a WARNING alert is triggered (forecasted spend)"
  default     = 80
}

variable "alert_threshold_critical" {
  type        = number
  description = "Percentage of the budget at which a CRITICAL alert is triggered (actual spend)"
  default     = 100
}

variable "time_unit" {
  type        = string
  description = "The period for the budget. Options: DAILY, MONTHLY, QUARTERLY, ANNUALLY"
  default     = "MONTHLY"

  validation {
    condition     = contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], var.time_unit)
    error_message = "time_unit must be one of: DAILY, MONTHLY, QUARTERLY, ANNUALLY."
  }
}
