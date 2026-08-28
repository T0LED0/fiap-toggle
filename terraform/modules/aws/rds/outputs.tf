output "db_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "The database endpoint (host:port)"
}

output "db_address" {
  value       = aws_db_instance.postgres.address
  description = "The database host address"
}

output "db_port" {
  value       = aws_db_instance.postgres.port
  description = "The database port"
}

output "db_name" {
  value       = aws_db_instance.postgres.db_name
  description = "The database name"
}

output "db_password" {
  value       = random_password.master_password.result
  description = "The generated database master password"
  sensitive   = true
}
