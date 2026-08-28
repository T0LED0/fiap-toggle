output "budget_id" {
  value       = aws_budgets_budget.monthly_cost.id
  description = "The ID of the AWS Budget"
}

output "budget_name" {
  value       = aws_budgets_budget.monthly_cost.name
  description = "The name of the AWS Budget"
}

output "budget_limit_amount" {
  value       = aws_budgets_budget.monthly_cost.limit_amount
  description = "The cost limit amount configured for the budget"
}

output "budget_limit_unit" {
  value       = aws_budgets_budget.monthly_cost.limit_unit
  description = "The currency unit for the budget limit"
}
