include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/terraform/modules/aws/security-groups"
}

dependency "vpc" {
  config_path = "${dirname(get_terragrunt_dir())}/vpc"

  mock_outputs = {
    vpc_id = "mock-vpc-id"
  }
}

locals {
  admin_ip = run_cmd("--terragrunt-quiet", "sh", "-c", "curl -s ifconfig.me || echo 0.0.0.0")
}

inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id

  admin_ip_cidr = ["${local.admin_ip}/32"]
}
