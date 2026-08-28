#!/usr/bin/env bash
# =============================================================================
# 2-terragrunt.sh — Executor de comandos Terragrunt (plan / apply / destroy)
# =============================================================================
# Executa 'terragrunt run --all <comando>' no ambiente e módulo desejados,
# carregando automaticamente as credenciais AWS do .envrc correspondente.
#
# Uso:
#   ./2-terragrunt.sh [OPÇÕES]
#
# Exemplos:
#   ./2-terragrunt.sh                          # menu interativo
#   ./2-terragrunt.sh -e fiap -s mvp -c plan   # plan no ambiente mvp
#   ./2-terragrunt.sh -e fiap -s prd -c apply  # apply no ambiente prd
#   ./2-terragrunt.sh -e fiap -s mvp -c destroy --auto-approve
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Cores e helpers de output  (mesmo padrão do 1-prepare.sh)
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${BLUE}  $*${RESET}"; \
            echo -e "${BOLD}${BLUE}════════════════════════════════════════${RESET}"; }
divider() { echo -e "${CYAN}────────────────────────────────────────${RESET}"; }

# ---------------------------------------------------------------------------
# Diretórios base (calculados a partir da localização do script)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/.."
ENV_DIR="${TERRAFORM_DIR}/env"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ENVIRONMENT=""          # ex: fiap
STAGE=""                # ex: mvp | hml | prd
COMMAND=""              # plan | apply | destroy
EXTRA_ARGS=()           # argumentos extras passados ao terragrunt
AUTO_APPROVE=false
NON_INTERACTIVE=false

# ---------------------------------------------------------------------------
# Ajuda
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF

${BOLD}Uso:${RESET}
  $(basename "$0") [OPÇÕES]

${BOLD}Opções:${RESET}
  -e, --environment  <env>    Ambiente (ex: fiap)             [obrigatório]
  -s, --stage        <stage>  Stage (mvp | hml | prd)         [obrigatório]
  -c, --command      <cmd>    Comando terragrunt              [obrigatório]
                              Valores aceitos: plan | apply | destroy
      --auto-approve          Passa --non-interactive e
                              -auto-approve ao OpenTofu (apply/destroy)
  -y, --yes                   Alias de --auto-approve
  -h, --help                  Exibe esta ajuda

${BOLD}Exemplos:${RESET}
  $(basename "$0") -e fiap -s mvp -c plan
  $(basename "$0") -e fiap -s mvp -c apply --auto-approve
  $(basename "$0") -e fiap -s prd -c destroy -y

EOF
}

# ---------------------------------------------------------------------------
# Parse de argumentos
# ---------------------------------------------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
      -s|--stage)       STAGE="$2";       shift 2 ;;
      -c|--command)     COMMAND="$2";     shift 2 ;;
      --auto-approve|-y|--yes) AUTO_APPROVE=true; shift ;;
      -h|--help)        usage; exit 0 ;;
      --) shift; EXTRA_ARGS+=("$@"); break ;;
      -*) warn "Opção desconhecida: $1 (ignorada)"; shift ;;
      *)  EXTRA_ARGS+=("$1"); shift ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Menu interativo para selecionar ambiente, stage e comando
# ---------------------------------------------------------------------------
interactive_menu() {
  echo ""
  echo -e "${BOLD}${CYAN}  Terragrunt — Seleção de Ambiente${RESET}"
  divider

  # ── Ambiente ──────────────────────────────────────────────────────────────
  if [[ -z "$ENVIRONMENT" ]]; then
    local envs=()
    while IFS= read -r -d '' d; do
      envs+=("$(basename "$d")")
    done < <(find "$ENV_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [[ ${#envs[@]} -eq 0 ]]; then
      error "Nenhum ambiente encontrado em: ${ENV_DIR}"
    fi

    echo -e "\n${BOLD}Ambientes disponíveis:${RESET}"
    local i=1
    for e in "${envs[@]}"; do
      echo "  ${i}) ${e}"
      ((i++))
    done

    local choice
    printf "\nEscolha o ambiente [1-%d]: " "${#envs[@]}"
    read -r choice
    [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#envs[@]}" ]] \
      || error "Opção inválida: ${choice}"
    ENVIRONMENT="${envs[$((choice-1))]}"
  fi

  # ── Stage ──────────────────────────────────────────────────────────────────
  if [[ -z "$STAGE" ]]; then
    local env_path="${ENV_DIR}/${ENVIRONMENT}"
    [[ -d "$env_path" ]] || error "Ambiente não encontrado: ${env_path}"

    local stages=()
    while IFS= read -r -d '' d; do
      stages+=("$(basename "$d")")
    done < <(find "$env_path" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [[ ${#stages[@]} -eq 0 ]]; then
      error "Nenhum stage encontrado em: ${env_path}"
    fi

    echo -e "\n${BOLD}Stages disponíveis em '${ENVIRONMENT}':${RESET}"
    local i=1
    for s in "${stages[@]}"; do
      echo "  ${i}) ${s}"
      ((i++))
    done

    local choice
    printf "\nEscolha o stage [1-%d]: " "${#stages[@]}"
    read -r choice
    [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#stages[@]}" ]] \
      || error "Opção inválida: ${choice}"
    STAGE="${stages[$((choice-1))]}"
  fi

  # ── Comando ────────────────────────────────────────────────────────────────
  if [[ -z "$COMMAND" ]]; then
    echo -e "\n${BOLD}Comandos disponíveis:${RESET}"
    echo "  1) plan"
    echo "  2) apply"
    echo "  3) destroy"

    local choice
    printf "\nEscolha o comando [1-3]: "
    read -r choice
    case "$choice" in
      1) COMMAND="plan"    ;;
      2) COMMAND="apply"   ;;
      3) COMMAND="destroy" ;;
      *) error "Opção inválida: ${choice}" ;;
    esac
  fi

  # ── Auto-approve para apply/destroy ───────────────────────────────────────
  if [[ "$AUTO_APPROVE" == false && ( "$COMMAND" == "apply" || "$COMMAND" == "destroy" ) ]]; then
    echo ""
    printf "${YELLOW}Deseja passar --auto-approve? [s/N]: ${RESET}"
    read -r aa_choice
    [[ "$aa_choice" =~ ^[sS]$ ]] && AUTO_APPROVE=true
  fi
}

# ---------------------------------------------------------------------------
# Carregar variáveis de um arquivo .envrc (parser manual)
# ---------------------------------------------------------------------------
_load_envrc_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    local clean_line
    clean_line="$(echo "$line" | sed 's/^[[:space:]]*export[[:space:]]*//')"
    [[ "$clean_line" =~ ^# ]]       && continue   # comentário
    [[ "$clean_line" =~ ^source ]]  && continue   # ignora source_up_if_exists
    [[ "$clean_line" != *=* ]]      && continue   # sem '='
    local var_name var_value
    var_name="${clean_line%%=*}"
    var_value="${clean_line#*=}"
    # Remove aspas simples ou duplas ao redor do valor
    var_value="${var_value#\'}"; var_value="${var_value%\'}"
    var_value="${var_value#\"}"; var_value="${var_value%\"}"
    # Expandir referências de variáveis shell (ex: ${HOME}, $USER)
    var_value="$(eval echo "$var_value" 2>/dev/null)" || continue
    [[ -n "$var_name" && -n "$var_value" ]] && export "${var_name}=${var_value}"
  done < "$file"
}


# ---------------------------------------------------------------------------
# Carregar credenciais do .envrc pai e do ambiente selecionado
# Replica o comportamento do 'source_up_if_exists' do direnv
# ---------------------------------------------------------------------------
load_aws_credentials() {
  local parent_envrc="${ENV_DIR}/.envrc"
  local envrc_file="${ENV_DIR}/${ENVIRONMENT}/.envrc"

  # 1. Carregar o .envrc pai (TG_DOWNLOAD_DIR, GITHUB_TOKEN, etc.)
  if [[ -f "$parent_envrc" ]]; then
    info "Carregando variáveis do .envrc pai: ${parent_envrc}"
    _load_envrc_file "$parent_envrc"
  fi

  # 2. Carregar o .envrc do ambiente (AWS_*, DB_PASSWORD, etc.)
  if [[ ! -f "$envrc_file" ]]; then
    warn "Arquivo de credenciais não encontrado: ${envrc_file}"
    warn "Certifique-se de preencher o .envrc antes de executar."
    return
  fi

  info "Carregando credenciais de: ${envrc_file}"

  # Autorizar .envrc com direnv (se disponível)
  if command -v direnv &>/dev/null; then
    local envrc_dir
    envrc_dir="$(dirname "$envrc_file")"
    (cd "$envrc_dir" && direnv allow . 2>/dev/null) || true
  fi

  _load_envrc_file "$envrc_file"

  # Validações básicas
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
    warn "AWS_ACCESS_KEY_ID não definida em ${envrc_file}."
  fi
  if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    warn "AWS_SECRET_ACCESS_KEY não definida em ${envrc_file}."
  fi
  if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
    warn "AWS_DEFAULT_REGION não definida. Usando padrão: us-east-1"
    export AWS_DEFAULT_REGION="us-east-1"
  fi
  if [[ -z "${AWS_SESSION_TOKEN:-}" ]]; then
    warn "AWS_SESSION_TOKEN não definido. No AWS Academy este campo é obrigatório."
  else
    warn "AWS Academy: credenciais temporárias expiram após ~4h. Atualize o .envrc a cada nova sessão."
  fi

  # Verificar identidade AWS
  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    && success "Identidade AWS validada. Account ID: ${account_id}" \
    || warn "Não foi possível validar as credenciais AWS. Verifique o .envrc."

  # Garantir que TG_DOWNLOAD_DIR é um caminho absoluto expandido
  # (evita que ${HOME} literal corrumpa o cache do Terragrunt)
  if [[ -n "${TG_DOWNLOAD_DIR:-}" ]]; then
    TG_DOWNLOAD_DIR="$(eval echo "${TG_DOWNLOAD_DIR}")"
    export TG_DOWNLOAD_DIR
    info "TG_DOWNLOAD_DIR: ${TG_DOWNLOAD_DIR}"
  fi
}


# ---------------------------------------------------------------------------
# Validar entradas
# ---------------------------------------------------------------------------
validate_inputs() {
  local work_dir="${ENV_DIR}/${ENVIRONMENT}/${STAGE}"

  [[ -n "$ENVIRONMENT" ]] || error "Ambiente não especificado. Use -e <env> ou o menu interativo."
  [[ -n "$STAGE"       ]] || error "Stage não especificado. Use -s <stage> ou o menu interativo."
  [[ -n "$COMMAND"     ]] || error "Comando não especificado. Use -c <plan|apply|destroy>."

  case "$COMMAND" in
    plan|apply|destroy) ;;
    *) error "Comando inválido: '${COMMAND}'. Use: plan | apply | destroy" ;;
  esac

  [[ -d "$work_dir" ]] \
    || error "Diretório do stage não encontrado: ${work_dir}"
}

# ---------------------------------------------------------------------------
# Confirmação de segurança para comandos destrutivos
# ---------------------------------------------------------------------------
confirm_destructive() {
  if [[ "$COMMAND" == "destroy" && "$AUTO_APPROVE" == false ]]; then
    echo ""
    echo -e "${RED}${BOLD}⚠️  ATENÇÃO: você está prestes a executar 'destroy' no stage '${STAGE}'!${RESET}"
    echo -e "${RED}   Isso removerá TODA a infraestrutura do ambiente ${ENVIRONMENT}/${STAGE}.${RESET}"
    echo ""
    printf "${YELLOW}Digite 'destroy' para confirmar: ${RESET}"
    read -r confirm
    [[ "$confirm" == "destroy" ]] || { info "Operação cancelada pelo usuário."; exit 0; }
  fi
}

# ---------------------------------------------------------------------------
# Executar terragrunt run --all <comando>
# ---------------------------------------------------------------------------
run_terragrunt() {
  local work_dir="${ENV_DIR}/${ENVIRONMENT}/${STAGE}"

  header "Executando: terragrunt run --all ${COMMAND}"
  info  "Ambiente : ${BOLD}${ENVIRONMENT}${RESET}"
  info  "Stage    : ${BOLD}${STAGE}${RESET}"
  info  "Diretório: ${work_dir}"
  divider

  # Monta os argumentos extras do comando
  local tg_args=("run" "--all" "$COMMAND")

  # Para apply e destroy, adicionar flags de aprovação quando solicitado
  if [[ "$AUTO_APPROVE" == true ]]; then
    case "$COMMAND" in
      apply|destroy)
        tg_args+=(
          "--non-interactive"
          "--"
          "-auto-approve"
        )
        ;;
    esac
  fi

  # Anexar quaisquer argumentos extras passados pelo usuário
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    tg_args+=("${EXTRA_ARGS[@]}")
  fi

  echo ""
  info "Comando completo: terragrunt ${tg_args[*]}"
  divider
  echo ""

  # Executa o terragrunt a partir do diretório do stage
  (
    cd "$work_dir"
    terragrunt "${tg_args[@]}"
  )

  echo ""
  divider
  success "Comando '${COMMAND}' concluído com sucesso para ${ENVIRONMENT}/${STAGE}!"
}

# ---------------------------------------------------------------------------
# Exibir resumo da execução ao final
# ---------------------------------------------------------------------------
print_summary() {
  echo ""
  header "Resumo"
  echo -e "  ${BOLD}Ambiente :${RESET} ${ENVIRONMENT}"
  echo -e "  ${BOLD}Stage    :${RESET} ${STAGE}"
  echo -e "  ${BOLD}Comando  :${RESET} ${COMMAND}"
  echo -e "  ${BOLD}Diretório:${RESET} ${ENV_DIR}/${ENVIRONMENT}/${STAGE}"
  echo ""

  case "$COMMAND" in
    plan)
      info "Para aplicar as mudanças planejadas, execute:"
      echo "  $(basename "$0") -e ${ENVIRONMENT} -s ${STAGE} -c apply"
      ;;
    apply)
      info "Para desfazer, execute:"
      echo "  $(basename "$0") -e ${ENVIRONMENT} -s ${STAGE} -c destroy"
      ;;
    destroy)
      warn "Infraestrutura destruída. Para recriar, execute:"
      echo "  $(basename "$0") -e ${ENVIRONMENT} -s ${STAGE} -c apply"
      ;;
  esac
  echo ""
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
main() {
  header "Terragrunt — ToggleMaster"

  parse_args "$@"

  # Se algum parâmetro obrigatório estiver faltando, vai para o menu interativo
  if [[ -z "$ENVIRONMENT" || -z "$STAGE" || -z "$COMMAND" ]]; then
    NON_INTERACTIVE=false
    interactive_menu
  else
    NON_INTERACTIVE=true
  fi

  validate_inputs
  load_aws_credentials
  confirm_destructive
  run_terragrunt
  print_summary
}

main "$@"
