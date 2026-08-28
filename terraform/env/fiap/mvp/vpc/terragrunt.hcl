# Include the root terragrunt configuration
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Define the source module
terraform {
  source = "${get_repo_root()}/terraform/modules/aws/vpc"
}

# Define inputs for the VPC module
inputs = {
  vpc_cidr = "10.10.0.0/16"

  public_subnet_cidrs  = ["10.10.254.0/24"]
  private_subnet_cidrs = ["10.10.2.0/24", "10.10.3.0/24"]
}
