locals {
  region       = "us-east-1"
  az           = "us-east-1a"
  az_secondary = "us-east-1b"

  common_tags = {
    owner           = "grupo-2"
    tech-challenger = "fase-1"
    application     = "togglemaster"
  }
}