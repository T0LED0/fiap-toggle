output "ec2_sg_id" {
  value       = aws_security_group.ec2.id
  description = "The ID of the EC2 Security Group"
}

output "rds_sg_id" {
  value       = aws_security_group.rds.id
  description = "The ID of the RDS Security Group"
}
