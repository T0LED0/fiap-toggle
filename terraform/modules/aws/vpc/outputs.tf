output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the created VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of the private subnets"
}

output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "The ID of the public route table"
}

output "private_route_table_id" {
  value       = aws_route_table.private.id
  description = "The ID of the private route table"
}
