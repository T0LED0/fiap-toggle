locals {
  common_tags = {
    Owner = "Grupo-2"
    App   = "togglemaster"
  }
}
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<CONTENT
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = jsondecode(<<INNEREOF
${jsonencode(local.common_tags)}
INNEREOF
)
  }
}
CONTENT
}
