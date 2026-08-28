locals {
  # Descobre o ID da conta AWS dinamicamente
  account_id = run_cmd("--terragrunt-quiet", "aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
  region     = get_env("AWS_DEFAULT_REGION", "us-east-1")

  # Monta o nome do bucket dinamicamente
  bucket        = "togglemaster-tfstate-${local.account_id}-${local.region}"
  relative_path = path_relative_to_include()

  # Extrai o nome do projeto dinamicamente a partir da pasta raiz (ex: "fiap")
  project_name = basename(get_parent_terragrunt_dir())

  # Carrega outras variáveis centralizadas, se houver
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "fallback.hcl"))

  # Extrai o environment dinamicamente a partir do nome da pasta de ambiente (ex: "mvp", "dev")
  environment = split("/", local.relative_path)[0]
}

inputs = {
  project_name = local.project_name
  environment  = local.environment
}

# Gera o provider da AWS automaticamente em todos os módulos,
# injetando as common_tags (de account.hcl) como default_tags
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  default_tags {
    tags = jsondecode(<<INNEREOF
${jsonencode(merge(
  try(local.account_vars.locals.common_tags, {}),
  {
    Project     = local.project_name
    Environment = local.environment
  }
))}
INNEREOF
)
  }
}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket  = local.bucket
    key     = "${local.relative_path}/terraform.tfstate"
    region  = local.region
    encrypt = true
  }
}