# Configuration root for Terragrunt

# Generate AWS provider block automatically in child modules
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
}
EOF
}

# Configure remote state backend dynamically
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = get_env("TF_STATE_BUCKET", "togglemaster-tfstate")
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = get_env("AWS_DEFAULT_REGION", "us-east-1")
    encrypt = true
  }
}
