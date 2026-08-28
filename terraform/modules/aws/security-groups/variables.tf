variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where security groups will be created"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "togglemaster"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
}

variable "admin_ip_cidr" {
  type        = list(string)
  description = "CIDR blocks allowed to access the EC2 instance via SSH"
  default     = ["0.0.0.0/0"]
}
