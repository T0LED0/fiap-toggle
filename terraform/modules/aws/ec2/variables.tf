variable "public_subnet_id" {
  type        = string
  description = "The public subnet ID where the EC2 instance will be created"
}

variable "ec2_sg_id" {
  type        = string
  description = "Security Group ID for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance type"
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "The key pair name to use for the instance"
  default     = null
}

variable "git_repo_url" {
  type        = string
  description = "Git repository URL of the ToggleMaster application"
  default     = "https://github.com/T0LED0/fiap-toggle.git"
}

variable "db_host" {
  type        = string
  description = "The RDS PostgreSQL host"
}

variable "db_name" {
  type        = string
  description = "The RDS database name"
}

variable "db_user" {
  type        = string
  description = "The RDS database user name"
}

variable "db_password" {
  type        = string
  description = "The RDS database password"
  sensitive   = true
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

variable "iam_instance_profile" {
  type        = string
  description = "The IAM Instance Profile to associate with the EC2 instance"
  default     = null
}

variable "use_rds_iam" {
  type        = bool
  description = "Whether to use RDS IAM Authentication instead of static password"
  default     = false
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token (PAT) for cloning private repositories"
  default     = ""
  sensitive   = true
}
