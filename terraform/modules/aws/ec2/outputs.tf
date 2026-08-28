output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "The public IP of the app server"
}

output "public_dns" {
  value       = aws_instance.app.public_dns
  description = "The public DNS of the app server"
}

output "instance_id" {
  value       = aws_instance.app.id
  description = "The instance ID of the app server"
}
