variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where RDS should reside. Must contain at least two subnets in different AZs."
}

variable "rds_sg_id" {
  type        = string
  description = "The security group ID allowed to connect to RDS"
}

variable "db_name" {
  type        = string
  description = "The database name"
  default     = "togglemaster"
}

variable "db_user" {
  type        = string
  description = "Database administrator username"
  default     = "postgres"
}


variable "db_instance_class" {
  type        = string
  description = "The instance type of the RDS database"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "Allocated storage in gigabytes"
  default     = 20
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

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Whether to enable IAM Database Authentication on the RDS instance"
  default     = false
}
