# DB Subnet Group (RDS requer 2 Zonas de dispobibilidade)
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "DB subnet group for ToggleMaster RDS"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Generate random master password
resource "random_password" "master_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-${var.environment}-db"
  engine                 = "postgres"
  engine_version         = "16.9"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = 100
  db_name                = var.db_name
  username               = var.db_user
  password               = random_password.master_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  # Compatibilidade AWS Academy
  publicly_accessible                 = false
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project_name
  }
}
