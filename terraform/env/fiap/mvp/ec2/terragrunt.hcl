include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/aws/ec2"
}

dependency "vpc" {
  config_path = "${dirname(get_terragrunt_dir())}/vpc"

  mock_outputs = {
    public_subnet_ids = ["mock-subnet-1", "mock-subnet-2"]
  }
}

dependency "security_groups" {
  config_path = "${dirname(get_terragrunt_dir())}/security-groups"

  mock_outputs = {
    ec2_sg_id = "mock-sg-id"
  }
}

dependency "rds" {
  config_path = "${dirname(get_terragrunt_dir())}/rds"

  mock_outputs = {
    db_address  = "mock-db.address.com:5432"
    db_name     = "mockdb"
    db_password = "mock-password"
  }
}

inputs = {
  public_subnet_id = dependency.vpc.outputs.public_subnet_ids[0]
  ec2_sg_id        = dependency.security_groups.outputs.ec2_sg_id
  instance_type    = "t3.micro"
  key_name         = get_env("AWS_KEY_NAME", "") # Permite opcionalmente passar uma chave SSH da AWS

  # Repositório de código a ser clonado na inicialização
  git_repo_url = "https://github.com/T0LED0/fiap-toggle.git"

  # Credenciais dinâmicas do banco injetadas automaticamente no script user_data da EC2
  db_host     = dependency.rds.outputs.db_address
  db_name     = dependency.rds.outputs.db_name
  db_user     = "postgres"
  db_password = dependency.rds.outputs.db_password

  iam_instance_profile = "LabInstanceProfile"
  use_rds_iam          = false
  github_token         = get_env("GITHUB_TOKEN", "")
}
