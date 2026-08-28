include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/aws/rds"
}

dependency "vpc" {
  config_path = "${dirname(get_terragrunt_dir())}/vpc"

  mock_outputs = {
    private_subnet_ids = ["mock-subnet-1", "mock-subnet-2"]
  }
}

dependency "security_groups" {
  config_path = "${dirname(get_terragrunt_dir())}/security-groups"

  mock_outputs = {
    rds_sg_id = "mock-sg-id"
  }
}

inputs = {
  private_subnet_ids   = dependency.vpc.outputs.private_subnet_ids
  rds_sg_id            = dependency.security_groups.outputs.rds_sg_id
  db_name              = "togglemaster"
  db_user              = "postgres"
  db_instance_class    = "db.t3.micro"
  db_allocated_storage = 20

  iam_database_authentication_enabled = true
}
