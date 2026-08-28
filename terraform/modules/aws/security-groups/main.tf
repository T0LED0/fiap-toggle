# 1. Security Group EC2 (Aplicação)
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for ToggleMaster EC2 instance"
  vpc_id      = var.vpc_id

  # Regra de entrda: SSH
  ingress {
    description = "Allow SSH from specific admin IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_ip_cidr
  }

  # Regra de entrada: Aplicação
  ingress {
    description = "Allow HTTP on port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de saída: Todo trafego
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# 2. Security Group RDS PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for ToggleMaster RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Regra de entrada: PostgreSQL apenas do Security Group do EC2
  ingress {
    description     = "Allow PostgreSQL traffic only from EC2 SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # Regra de saída: Todo trafego
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-rds-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}
