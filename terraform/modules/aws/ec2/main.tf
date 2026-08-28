locals {
  git_repo_url = var.github_token != "" ? replace(var.git_repo_url, "https://", "https://${var.github_token}@") : var.git_repo_url
}

# 1. Fetch latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. EC2 Instance
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.ec2_sg_id]
  key_name                    = var.key_name
  associate_public_ip_address  = true
  iam_instance_profile         = var.iam_instance_profile
  user_data_replace_on_change  = true

  user_data = <<-EOF
#!/bin/bash
# Redirecionar toda saída para o log ANTES de qualquer coisa
exec > /var/log/user-data.log 2>&1
set -euo pipefail
trap 'echo "[ERROR] Script falhou na linha $LINENO — exit code: $?" >> /var/log/user-data.log' ERR

echo "[START] $(date) — Iniciando user data script"

# Update OS package index
apt-get update -y

# Install git, python and dependencies
apt-get install -y git python3-pip python3-venv postgresql-client

# Prepare app directory
mkdir -p /opt/fiap
chown -R ubuntu:ubuntu /opt/fiap
cd /opt/fiap

# Clone the code repository
sudo -u ubuntu git clone ${local.git_repo_url} toggle-master-monolith
cd toggle-master-monolith

# Setup Virtual Environment and install requirements
sudo -u ubuntu python3 -m venv venv
sudo -u ubuntu /opt/fiap/toggle-master-monolith/venv/bin/pip install --upgrade pip
sudo -u ubuntu /opt/fiap/toggle-master-monolith/venv/bin/pip install -r app/requirements.txt

# Save sensitive database variables in restricted environment file
cat > /opt/fiap/toggle-master-monolith/.env <<EOT
DB_HOST=${var.db_host}
DB_NAME=${var.db_name}
DB_USER=${var.db_user}
DB_PASSWORD=${var.db_password}
USE_RDS_IAM=${var.use_rds_iam}
AWS_REGION=us-east-1
EOT
chmod 600 /opt/fiap/toggle-master-monolith/.env

# Export variables directly for the current script session (safely quoted)
export DB_HOST=${var.db_host}
export DB_NAME=${var.db_name}
export DB_USER=${var.db_user}
export DB_PASSWORD='${var.db_password}'
export USE_RDS_IAM=${var.use_rds_iam}
export AWS_REGION=us-east-1

# Wait loop until PostgreSQL is ready to accept connections
export PGSSLMODE=require
export PGPASSWORD='${var.db_password}'
until pg_isready -h ${var.db_host} -p 5432 -U ${var.db_user}; do
  echo "Aguardando o banco de dados RDS PostgreSQL ficar operacional..."
  sleep 5
done

# Setup IAM application user in database using master credentials if IAM auth is enabled
if [ "${var.use_rds_iam}" = "true" ]; then
  psql -h ${var.db_host} -U ${var.db_user} -d ${var.db_name} -c "CREATE USER toggle_app_user LOGIN;" || true
  psql -h ${var.db_host} -U ${var.db_user} -d ${var.db_name} -c "GRANT rds_iam TO toggle_app_user;"
  psql -h ${var.db_host} -U ${var.db_user} -d ${var.db_name} -c "GRANT ALL PRIVILEGES ON DATABASE ${var.db_name} TO toggle_app_user;"
  psql -h ${var.db_host} -U ${var.db_user} -d ${var.db_name} -c "GRANT ALL PRIVILEGES ON SCHEMA public TO toggle_app_user;"

  # Update DB_USER in the environment file to the new user
  sed -i 's/DB_USER=.*/DB_USER=toggle_app_user/' /opt/fiap/toggle-master-monolith/.env
  # Remove the master DB password from the environment file for security
  sed -i '/DB_PASSWORD=/d' /opt/fiap/toggle-master-monolith/.env
  
  # Update current session export to match IAM user for flask init-db
  export DB_USER=toggle_app_user
  unset DB_PASSWORD
fi

cd /opt/fiap/toggle-master-monolith/app
/opt/fiap/toggle-master-monolith/venv/bin/flask init-db

# Write systemd service configuration file
cat > /etc/systemd/system/toggle-master.service <<EOT
[Unit]
Description=ToggleMaster Flask Application running under Gunicorn
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/fiap/toggle-master-monolith/app
EnvironmentFile=/opt/fiap/toggle-master-monolith/.env
ExecStart=/opt/fiap/toggle-master-monolith/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:3000 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOT

# Reload and enable the systemd daemon service
systemctl daemon-reload
systemctl enable toggle-master
systemctl start toggle-master
EOF


  tags = {
    Name        = "${var.project_name}-${var.environment}-app-server"
    Environment = var.environment
    Project     = var.project_name
  }
}
