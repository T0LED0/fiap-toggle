variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.10.0.0/16"
}

variable "project_name" {
  type        = string
  description = "Name of the project to be used in resource tags"
  default     = "togglemaster"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g. dev, prod)"
  default     = "dev"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
  default     = ["10.10.254.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets. AWS RDS requires at least two subnets in different availability zones."
  default     = ["10.10.2.0/24", "10.10.3.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to deploy subnets. If empty, the first available AZs in the region will be used."
  default     = []
}
