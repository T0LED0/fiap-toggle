#!/usr/bin/env bash
# =============================================================================
# 1-prepare.sh — Instalador de ferramentas IaC
# =============================================================================
# Instala automaticamente:
#   - OpenTofu  (runtime compatível com Terraform)
#   - Terragrunt (wrapper DRY sobre o OpenTofu/Terraform)
#   - direnv    (carrega o arquivo .envrc automaticamente)
#   - AWS CLI v2 (interface de linha de comando da AWS)
#
# Suporte: macOS · Linux (Debian/Ubuntu/Fedora/Arch) · Windows (WSL2 / Git Bash)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Versões fixas — ajuste conforme necessário
# ---------------------------------------------------------------------------
OPENTOFU_VERSION="${OPENTOFU_VERSION:-1.9.1}"
TERRAGRUNT_VERSION="${TERRAGRUNT_VERSION:-0.77.20}"

# ---------------------------------------------------------------------------
# Cores e helpers de output
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${BLUE}  $*${RESET}"; \
            echo -e "${BOLD}${BLUE}════════════════════════════════════════${RESET}"; }

# ---------------------------------------------------------------------------
# Detectar sistema operacional e arquitetura
# ---------------------------------------------------------------------------
detect_os() {
  OS="unknown"
  ARCH="$(uname -m 2>/dev/null || echo unknown)"

  case "$(uname -s 2>/dev/null)" in
    Darwin)  OS="macos" ;;
    Linux)
      # Checar se está dentro do WSL
      if grep -qi microsoft /proc/version 2>/dev/null; then
        OS="wsl"
      else
        OS="linux"
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows_bash" ;;
    *)
      # Fallback para variável de ambiente do Windows
      [[ -n "${WINDIR:-}" || -n "${windir:-}" ]] && OS="windows_bash" ;;
  esac

  # Normalizar arquitetura
  case "$ARCH" in
    x86_64|amd64)    ARCH="amd64" ;;
    aarch64|arm64)   ARCH="arm64" ;;
    armv7l)          ARCH="arm"   ;;
    *)               warn "Arquitetura '$ARCH' pode não ter binários pré-compilados." ;;
  esac

  info "Sistema detectado: ${BOLD}${OS}${RESET} / ${BOLD}${ARCH}${RESET}"
}

# ---------------------------------------------------------------------------
# Detectar gerenciador de pacotes Linux
# ---------------------------------------------------------------------------
detect_pkg_manager() {
  if   command -v apt-get &>/dev/null; then PKG_MANAGER="apt"
  elif command -v dnf     &>/dev/null; then PKG_MANAGER="dnf"
  elif command -v yum     &>/dev/null; then PKG_MANAGER="yum"
  elif command -v pacman  &>/dev/null; then PKG_MANAGER="pacman"
  elif command -v zypper  &>/dev/null; then PKG_MANAGER="zypper"
  else PKG_MANAGER="unknown"
  fi
}

# ---------------------------------------------------------------------------
# Verificar se um binário já está instalado e com a versão correta
# ---------------------------------------------------------------------------
is_installed() {
  local cmd="$1"
  command -v "$cmd" &>/dev/null
}

# ---------------------------------------------------------------------------
# Instalar dependências básicas (curl, unzip, wget)
# ---------------------------------------------------------------------------
install_base_deps() {
  info "Verificando dependências básicas (curl, unzip, wget, jq)..."

  case "$OS" in
    macos)
      if ! is_installed brew; then
        warn "Homebrew não encontrado. Instalando..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      if ! is_installed jq; then
        info "Instalando jq..."
        brew install jq
      fi
      ;;
    linux|wsl)
      detect_pkg_manager
      local missing_pkgs=()
      for pkg in curl unzip wget jq; do
        is_installed "$pkg" || missing_pkgs+=("$pkg")
      done
      if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        info "Instalando: ${missing_pkgs[*]}"
        case "$PKG_MANAGER" in
          apt)    sudo apt-get update -qq && sudo apt-get install -y "${missing_pkgs[@]}" ;;
          dnf)    sudo dnf install -y "${missing_pkgs[@]}" ;;
          yum)    sudo yum install -y "${missing_pkgs[@]}" ;;
          pacman) sudo pacman -Sy --noconfirm "${missing_pkgs[@]}" ;;
          zypper) sudo zypper install -y "${missing_pkgs[@]}" ;;
          *)      error "Gerenciador de pacotes não suportado. Instale manualmente: ${missing_pkgs[*]}" ;;
        esac
      fi
      ;;
    windows_bash)
      # No Git Bash / WSL, assume que curl e unzip estão disponíveis
      is_installed curl   || error "curl não encontrado. Instale o Git for Windows ou use WSL2."
      is_installed unzip  || warn "unzip não encontrado. Pode ser necessário para algumas instalações."
      is_installed jq     || warn "jq não encontrado. Recomendamos instalar o jq (ex: choco install jq) para formatar outputs JSON."
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Instalar OpenTofu
# ---------------------------------------------------------------------------
install_opentofu() {
  header "OpenTofu ${OPENTOFU_VERSION}"

  if is_installed tofu; then
    local current
    current="$(tofu version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if [[ "$current" == "$OPENTOFU_VERSION" ]]; then
      success "OpenTofu ${current} já instalado. Pulando."
      return
    fi
    warn "OpenTofu ${current} instalado — atualizando para ${OPENTOFU_VERSION}..."
  fi

  case "$OS" in
    # ── macOS ──────────────────────────────────────────────────────────────
    macos)
      brew install opentofu
      ;;

    # ── Linux / WSL ────────────────────────────────────────────────────────
    linux|wsl)
      detect_pkg_manager
      case "$PKG_MANAGER" in
        apt)
          # Repositório oficial do OpenTofu
          curl -fsSL https://get.opentofu.org/opentofu.gpg \
            | sudo tee /usr/share/keyrings/opentofu.gpg >/dev/null
          curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey \
            | gpg --dearmor \
            | sudo tee /usr/share/keyrings/opentofu-repo.gpg >/dev/null
          echo "deb [signed-by=/usr/share/keyrings/opentofu.gpg,/usr/share/keyrings/opentofu-repo.gpg] \
https://packages.opentofu.org/opentofu/tofu/any/ any main
deb-src [signed-by=/usr/share/keyrings/opentofu.gpg,/usr/share/keyrings/opentofu-repo.gpg] \
https://packages.opentofu.org/opentofu/tofu/any/ any main" \
            | sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null
          sudo apt-get update -qq
          sudo apt-get install -y "tofu=${OPENTOFU_VERSION}-1"
          ;;
        dnf|yum)
          sudo "$PKG_MANAGER" install -y yum-utils
          sudo "$PKG_MANAGER" config-manager \
            --add-repo https://packages.opentofu.org/opentofu/tofu/rpm_any/rpm_any.repo
          sudo "$PKG_MANAGER" install -y "tofu-${OPENTOFU_VERSION}"
          ;;
        *)
          # Fallback: download binário direto
          _install_opentofu_binary
          ;;
      esac
      ;;

    # ── Windows (Git Bash) ─────────────────────────────────────────────────
    windows_bash)
      _install_opentofu_binary
      ;;
  esac

  success "OpenTofu $(tofu version | head -1) instalado."
}

# Instala OpenTofu via download direto de binário (fallback)
_install_opentofu_binary() {
  local os_label arch_label ext="zip"
  case "$OS" in
    macos)         os_label="darwin"  ;;
    windows_bash)  os_label="windows"; ext="zip" ;;
    *)             os_label="linux"   ;;
  esac
  case "$ARCH" in
    amd64) arch_label="amd64" ;;
    arm64) arch_label="arm64" ;;
    arm)   arch_label="arm"   ;;
    *)     error "Arquitetura $ARCH não suportada para download binário." ;;
  esac

  local url="https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_${os_label}_${arch_label}.${ext}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  info "Baixando OpenTofu de: $url"
  curl -fsSL "$url" -o "${tmp_dir}/tofu.${ext}"
  unzip -q "${tmp_dir}/tofu.${ext}" -d "$tmp_dir"

  local install_dir="${HOME}/.local/bin"
  mkdir -p "$install_dir"
  mv "${tmp_dir}/tofu" "$install_dir/tofu" 2>/dev/null || mv "${tmp_dir}/tofu.exe" "$install_dir/tofu.exe"
  chmod +x "${install_dir}/tofu" 2>/dev/null || true
  rm -rf "$tmp_dir"

  _ensure_in_path "$install_dir"
}

# ---------------------------------------------------------------------------
# Instalar Terragrunt
# ---------------------------------------------------------------------------
install_terragrunt() {
  header "Terragrunt ${TERRAGRUNT_VERSION}"

  if is_installed terragrunt; then
    local current
    current="$(terragrunt --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    if [[ "$current" == "$TERRAGRUNT_VERSION" ]]; then
      success "Terragrunt ${current} já instalado. Pulando."
      return
    fi
    warn "Terragrunt ${current} instalado — atualizando para ${TERRAGRUNT_VERSION}..."
  fi

  case "$OS" in
    macos)
      brew install terragrunt
      ;;
    linux|wsl|windows_bash)
      _install_terragrunt_binary
      ;;
  esac

  success "Terragrunt $(terragrunt --version) instalado."
}

_install_terragrunt_binary() {
  local os_label arch_label suffix=""
  case "$OS" in
    macos)         os_label="darwin"  ;;
    windows_bash)  os_label="windows"; suffix=".exe" ;;
    *)             os_label="linux"   ;;
  esac
  case "$ARCH" in
    amd64) arch_label="amd64" ;;
    arm64) arch_label="arm64" ;;
    *)     error "Arquitetura $ARCH não suportada para Terragrunt." ;;
  esac

  local url="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_${os_label}_${arch_label}${suffix}"
  local install_dir="${HOME}/.local/bin"
  mkdir -p "$install_dir"

  info "Baixando Terragrunt de: $url"
  curl -fsSL "$url" -o "${install_dir}/terragrunt${suffix}"
  chmod +x "${install_dir}/terragrunt${suffix}" 2>/dev/null || true

  _ensure_in_path "$install_dir"
}

# ---------------------------------------------------------------------------
# Instalar direnv
# ---------------------------------------------------------------------------
install_direnv() {
  header "direnv"

  if is_installed direnv; then
    success "direnv $(direnv version) já instalado. Pulando."
    return
  fi

  case "$OS" in
    macos)
      brew install direnv
      ;;
    linux|wsl)
      detect_pkg_manager
      case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y direnv ;;
        dnf|yum) sudo "$PKG_MANAGER" install -y direnv ;;
        pacman) sudo pacman -S --noconfirm direnv ;;
        zypper) sudo zypper install -y direnv ;;
        *)      _install_direnv_binary ;;
      esac
      ;;
    windows_bash)
      _install_direnv_binary
      ;;
  esac

  # Configurar hook do shell para carregar direnv automaticamente
  _configure_direnv_hook

  success "direnv $(direnv version) instalado."
}

_install_direnv_binary() {
  local os_label arch_label suffix=""
  case "$OS" in
    macos)         os_label="darwin"  ;;
    windows_bash)  os_label="windows"; suffix=".exe" ;;
    *)             os_label="linux"   ;;
  esac
  case "$ARCH" in
    amd64) arch_label="amd64" ;;
    arm64) arch_label="arm64" ;;
    *)     error "Arquitetura $ARCH não suportada para direnv." ;;
  esac

  local url="https://direnv.net/install.sh"
  info "Instalando direnv via script oficial..."
  curl -fsSL "$url" | bash
}

_configure_direnv_hook() {
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"
  local rc_file=""

  case "$shell_name" in
    bash)
      rc_file="${HOME}/.bashrc"
      [[ "$OS" == "macos" ]] && rc_file="${HOME}/.bash_profile"
      ;;
    zsh)  rc_file="${HOME}/.zshrc" ;;
    fish) rc_file="${HOME}/.config/fish/config.fish" ;;
  esac

  if [[ -n "$rc_file" ]]; then
    local hook_line='eval "$(direnv hook '"$shell_name"')"'
    if ! grep -qF "direnv hook" "$rc_file" 2>/dev/null; then
      echo "" >> "$rc_file"
      echo "# direnv — carrega .envrc automaticamente" >> "$rc_file"
      echo "$hook_line" >> "$rc_file"
      info "Hook do direnv adicionado em: ${rc_file}"
      warn "Execute: source ${rc_file}  (ou abra um novo terminal)"
    else
      info "Hook do direnv já presente em: ${rc_file}"
    fi
  else
    warn "Shell '$shell_name' não reconhecido. Adicione manualmente ao seu rc: eval \"\$(direnv hook $shell_name)\""
  fi
}

# ---------------------------------------------------------------------------
# Configurar o arquivo .envrc do projeto
# ---------------------------------------------------------------------------
setup_envrc() {
  header "Configuração do .envrc"

  # Diretório raiz relativo a este script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ENV_DIR="${SCRIPT_DIR}/../env"
  ENVRC_EXAMPLE="${ENV_DIR}/.envrc_example"
  ENVRC_FILE="${ENV_DIR}/.envrc"

  if [[ ! -f "$ENVRC_EXAMPLE" ]]; then
    warn ".envrc_example não encontrado em ${ENV_DIR}. Pulando configuração."
    return
  fi

  if [[ -f "$ENVRC_FILE" ]]; then
    success ".envrc já existe em ${ENV_DIR}. Não será sobrescrito."
  else
    cp "$ENVRC_EXAMPLE" "$ENVRC_FILE"
    success ".envrc criado a partir do .envrc_example em ${ENV_DIR}"
    warn "Preencha suas credenciais AWS em: ${ENVRC_FILE}"
  fi

  # Autorizar o .envrc com direnv (se disponível)
  if is_installed direnv; then
    info "Autorizando .envrc com 'direnv allow'..."
    (cd "$ENV_DIR" && direnv allow .)
    success "direnv configurado para carregar ${ENVRC_FILE}"
  fi
}

# ---------------------------------------------------------------------------
# Garantir que o diretório está no PATH
# ---------------------------------------------------------------------------
_ensure_in_path() {
  local dir="$1"
  if [[ ":${PATH}:" != *":${dir}:"* ]]; then
    export PATH="${dir}:${PATH}"
    warn "${dir} adicionado ao PATH da sessão atual."
    warn "Para tornar permanente, adicione ao seu shell rc: export PATH=\"${dir}:\$PATH\""
  fi
}

# ---------------------------------------------------------------------------
# Instalar AWS CLI v2
# ---------------------------------------------------------------------------
install_awscli() {
  header "AWS CLI v2"

  if is_installed aws; then
    local current
    current="$(aws --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    success "AWS CLI ${current} já instalado. Pulando."
    return
  fi

  case "$OS" in
    # ── macOS ──────────────────────────────────────────────────────────────
    macos)
      brew install awscli
      ;;

    # ── Linux / WSL ────────────────────────────────────────────────────────
    linux|wsl)
      local tmp_dir arch_label
      tmp_dir="$(mktemp -d)"
      case "$ARCH" in
        amd64) arch_label="x86_64" ;;
        arm64) arch_label="aarch64" ;;
        *)     error "Arquitetura $ARCH não suportada para AWS CLI." ;;
      esac

      info "Baixando AWS CLI v2 para Linux (${arch_label})..."
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${arch_label}.zip" \
        -o "${tmp_dir}/awscliv2.zip"
      unzip -q "${tmp_dir}/awscliv2.zip" -d "$tmp_dir"

      if [[ -w "/usr/local/bin" ]]; then
        "${tmp_dir}/aws/install"
      else
        sudo "${tmp_dir}/aws/install"
      fi
      rm -rf "$tmp_dir"
      ;;

    # ── Windows (Git Bash) ─────────────────────────────────────────────────
    windows_bash)
      local tmp_dir
      tmp_dir="$(mktemp -d)"
      info "Baixando AWS CLI v2 para Windows..."
      curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.msi" \
        -o "${tmp_dir}/AWSCLIV2.msi"
      # Instala silenciosamente via msiexec (requer privilégio de Administrador)
      msiexec.exe /i "$(cygpath -w "${tmp_dir}/AWSCLIV2.msi")" /qn 2>/dev/null \
        || warn "msiexec não disponível. Instale manualmente: https://awscli.amazonaws.com/AWSCLIV2.msi"
      rm -rf "$tmp_dir"
      ;;
  esac

  if is_installed aws; then
    success "AWS CLI $(aws --version 2>&1 | head -1) instalado."
  else
    warn "AWS CLI instalado, mas não encontrado no PATH ainda. Reabra o terminal."
  fi
}

# ---------------------------------------------------------------------------
# Verificação final das instalações
# ---------------------------------------------------------------------------
verify_installations() {
  header "Verificação das instalações"
  local all_ok=true

  for tool in tofu terragrunt direnv aws; do
    if is_installed "$tool"; then
      local version
      case "$tool" in
        tofu)       version="$(tofu version 2>/dev/null | head -1)" ;;
        terragrunt) version="$(terragrunt --version 2>/dev/null)" ;;
        direnv)     version="direnv $(direnv version 2>/dev/null)" ;;
        aws)        version="$(aws --version 2>&1 | head -1)" ;;
      esac
      success "${tool}: ${version}"
    else
      error_line="${RED}[FALHA]${RESET} ${tool}: NÃO encontrado no PATH"
      echo -e "$error_line"
      all_ok=false
    fi
  done

  echo ""
  if $all_ok; then
    success "Todas as ferramentas estão instaladas e prontas!"
  else
    warn "Algumas ferramentas não foram encontradas. Verifique seu PATH e reabra o terminal."
  fi
}

# ---------------------------------------------------------------------------
# Windows: instrução extra para usuários nativos (sem WSL/Git Bash)
# ---------------------------------------------------------------------------
print_windows_native_instructions() {
  cat << 'EOF'

════════════════════════════════════════════
  Windows Nativo (PowerShell / CMD)
════════════════════════════════════════════
Este script requer Git Bash ou WSL2 para rodar no Windows.

Opção 1 — WSL2 (recomendado):
  1. Instale o WSL2: https://learn.microsoft.com/pt-br/windows/wsl/install
  2. Abra o terminal WSL2 e execute este script normalmente.

Opção 2 — Git Bash:
  1. Instale Git for Windows: https://git-scm.com/download/win
  2. Abra o "Git Bash" e execute este script.

Opção 3 — Winget (instalação manual):
  winget install --id OpenTF.Tofu
  winget install --id gruntwork-io.Terragrunt
  winget install --id Amazon.AWSCLI

Opção 4 — Chocolatey:
  choco install opentofu terragrunt direnv awscli

EOF
}

# ---------------------------------------------------------------------------
# Carregar credenciais AWS do arquivo env/fiap/.envrc
# ---------------------------------------------------------------------------
load_fiap_credentials() {
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  FIAP_ENVRC="${SCRIPT_DIR}/../env/fiap/.envrc"

  if [[ ! -f "$FIAP_ENVRC" ]]; then
    warn "Arquivo de credenciais não encontrado: ${FIAP_ENVRC}"
    warn "Preencha as credenciais e execute novamente."
    return 1
  fi

  # Autorizar o .envrc do ambiente fiap com direnv
  local fiap_env_dir
  fiap_env_dir="$(dirname "$FIAP_ENVRC")"
  if is_installed direnv; then
    info "Autorizando .envrc do ambiente fiap: direnv allow ${fiap_env_dir}"
    (cd "$fiap_env_dir" && direnv allow . 2>/dev/null) || true
  fi

  # Carrega as variáveis AWS do .envrc
  # Suporta formatos: export VAR='valor', export VAR="valor", export VAR=valor
  info "Carregando credenciais de: ${FIAP_ENVRC}"
  while IFS= read -r line; do
    local clean_line
    clean_line="$(echo "$line" | sed 's/^[[:space:]]*export[[:space:]]*//')"
    [[ "$clean_line" =~ ^# ]] && continue
    [[ "$clean_line" != *=* ]] && continue
    [[ "$clean_line" =~ ^AWS_ ]] || continue
    local var_name var_value
    var_name="${clean_line%%=*}"
    var_value="${clean_line#*=}"
    var_value="${var_value#\'}"; var_value="${var_value%\'}"
    var_value="${var_value#\"}"; var_value="${var_value%\"}"
    [[ -n "$var_name" && -n "$var_value" ]] && export "${var_name}=${var_value}"
  done < "$FIAP_ENVRC"

  # Validações básicas
  local missing=()
  [[ -z "${AWS_ACCESS_KEY_ID:-}"     ]] && missing+=("AWS_ACCESS_KEY_ID")
  [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] && missing+=("AWS_SECRET_ACCESS_KEY")
  [[ -z "${AWS_SESSION_TOKEN:-}"     ]] && missing+=("AWS_SESSION_TOKEN")

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Variáveis faltando em ${FIAP_ENVRC}: ${missing[*]}"
    warn "Copie as credenciais do Vocareum → AWS Details → AWS CLI e preencha o arquivo."
    return 1
  fi

  [[ -z "${AWS_DEFAULT_REGION:-}" ]] && export AWS_DEFAULT_REGION="us-east-1"

  warn "AWS Academy: credenciais temporárias expiram após ~4h. Atualize o .envrc a cada nova sessão."
  success "Credenciais carregadas de: ${FIAP_ENVRC}"
}

# ---------------------------------------------------------------------------
# Criar bucket S3 para o state remoto do Terraform
# ---------------------------------------------------------------------------
create_s3_state_bucket() {
  header "Bucket S3 — Terraform Remote State"

  # Nome do bucket: usa o Account ID da AWS para garantir unicidade global
  local account_id
  account_id="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
    || { warn "Não foi possível obter o Account ID. Verifique as credenciais AWS."; return; }

  local bucket_name="togglemaster-tfstate-${account_id}-${AWS_DEFAULT_REGION}"
  info "Bucket de state: ${bucket_name} (região: ${AWS_DEFAULT_REGION})"

  # Verificar se o bucket já existe
  if aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
    success "Bucket '${bucket_name}' já existe. Pulando criação."
  else
    info "Criando bucket S3..."

    # us-east-1 não aceita LocationConstraint
    if [[ "$AWS_DEFAULT_REGION" == "us-east-1" ]]; then
      aws s3api create-bucket \
        --bucket "$bucket_name" \
        --region "$AWS_DEFAULT_REGION" 1>/dev/null
    else
      aws s3api create-bucket \
        --bucket "$bucket_name" \
        --region "$AWS_DEFAULT_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION" 1>/dev/null
    fi

    # Habilitar versionamento (recuperação de state corrompido)
    aws s3api put-bucket-versioning \
      --bucket "$bucket_name" \
      --versioning-configuration Status=Enabled 1>/dev/null \
      && info "Versionamento habilitado." \
      || warn "Não foi possível habilitar versionamento (permissão restrita no Academy)."

    # Habilitar criptografia AES-256 em repouso
    aws s3api put-bucket-encryption \
      --bucket "$bucket_name" \
      --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }]
      }' 1>/dev/null \
      && info "Criptografia AES-256 habilitada." \
      || warn "Não foi possível configurar criptografia (Academy já aplica por padrão)."

    # Bloquear acesso público ao bucket
    aws s3api put-public-access-block \
      --bucket "$bucket_name" \
      --public-access-block-configuration \
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' 1>/dev/null \
      && info "Acesso público bloqueado." \
      || warn "Não foi possível configurar bloqueio público (permissão restrita no Academy)."

    success "Bucket '${bucket_name}' criado com sucesso!"
  fi

  # Exportar o nome do bucket para uso posterior (útil se o script for feito por `source`)
  export TF_STATE_BUCKET="$bucket_name"
  info "Nome do bucket exportado: TF_STATE_BUCKET=${TF_STATE_BUCKET}"
  warn "O Terragrunt descobrirá o nome deste bucket dinamicamente usando a conta AWS."
}

# ---------------------------------------------------------------------------
# Ajuda
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF

${BOLD}Uso:${RESET}
  $(basename "$0") [OPÇÕES]

${BOLD}Opções:${RESET}
  --bucket-only   Cria/verifica apenas o bucket S3 de remote state.
                  Útil para renovar sessão do AWS Academy sem reinstalar ferramentas.
  -h, --help      Exibe esta ajuda.

${BOLD}Sem argumentos:${RESET} instala todas as ferramentas e cria o bucket S3.

EOF
}

# ---------------------------------------------------------------------------
# Verificar se as credenciais AWS estão válidas (detecta ExpiredToken)
# ---------------------------------------------------------------------------
check_aws_credentials() {
  if ! is_installed aws; then
    warn "AWS CLI não encontrado. Pulando validação de credenciais."
    return
  fi

  local err
  err="$(aws sts get-caller-identity 2>&1)" && return 0

  if echo "$err" | grep -qi "ExpiredToken\|expired"; then
    echo ""
    echo -e "${RED}${BOLD}══════════════════════════════════════════════════${RESET}"
    echo -e "${RED}${BOLD}  ⚠️  CREDENCIAIS AWS EXPIRADAS${RESET}"
    echo -e "${RED}${BOLD}══════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}  As credenciais do AWS Academy expiram a cada ~4h.${RESET}"
    echo ""
    echo -e "${BOLD}  Como renovar:${RESET}"
    echo "    1. Acesse o Vocareum: https://www.awsacademy.com"
    echo "    2. Clique em 'AWS Details' → 'AWS CLI'"
    echo "    3. Copie os 3 valores (key, secret, session token)"
    echo "    4. Cole em: terraform/env/fiap/.envrc"
    echo "    5. Execute novamente: ./1-prepare.sh --bucket-only"
    echo -e "${RED}${BOLD}══════════════════════════════════════════════════${RESET}"
    echo ""
    return 1
  elif echo "$err" | grep -qi "NoCredentials\|Unable to locate"; then
    warn "Credenciais AWS não configuradas. Preencha terraform/env/fiap/.envrc antes de continuar."
    return 1
  else
    warn "Erro ao validar credenciais AWS: ${err}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------
main() {
  # Parse de argumentos
  local bucket_only=false
  for arg in "$@"; do
    case "$arg" in
      --bucket-only) bucket_only=true ;;
      -h|--help)     usage; exit 0 ;;
    esac
  done

  if $bucket_only; then
    # ── Modo rápido: apenas provisionar o bucket S3 ──────────────────────
    header "Provisionando Bucket S3 — ToggleMaster"
    detect_os
    setup_envrc
    load_fiap_credentials || { warn "Corrija o .envrc e execute novamente."; exit 1; }
    if check_aws_credentials; then
      create_s3_state_bucket
      echo ""
      success "Bucket S3 pronto. Agora execute:"
      local stage
      stage="$(basename "$(find "${SCRIPT_DIR}/../env/fiap" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)" 2>/dev/null || echo "<stage>")"
      echo "  cd terraform/env/fiap/${stage}"
      echo "  terragrunt run --all plan"
    fi
    return
  fi

  # ── Modo completo: instalar ferramentas + bucket ──────────────────────
  header "Preparando ambiente IaC — ToggleMaster"
  detect_os

  # Aviso especial para usuários Windows sem emulador de shell Unix
  if [[ "$OS" == "windows_bash" ]]; then
    warn "Detectado ambiente Windows (Git Bash / Cygwin). Algumas funcionalidades podem ser limitadas."
    warn "Recomendamos usar WSL2 para melhor compatibilidade."
    print_windows_native_instructions
  fi

  install_base_deps
  install_opentofu
  install_terragrunt
  install_awscli
  install_direnv
  setup_envrc

  # Carregar credenciais e validar antes de tentar criar o bucket
  if load_fiap_credentials && check_aws_credentials; then
    create_s3_state_bucket
  else
    warn "Pulando criação do bucket S3. Atualize as credenciais e execute:"
    echo "  ./1-prepare.sh --bucket-only"
  fi

  verify_installations

  echo ""
  info "Próximos passos:"
  echo "  1. Preencha suas credenciais AWS em: terraform/env/fiap/.envrc"
  echo "  2. Reabra o terminal ou execute: source ~/.bashrc (ou ~/.zshrc)"
  echo "  3. (Se ainda não criou o bucket): ./1-prepare.sh --bucket-only"
  local stage
  stage="$(basename "$(find "${SCRIPT_DIR}/../env/fiap" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n 1)" 2>/dev/null || echo "<stage>")"
  echo "  4. Navegue até: cd terraform/env/fiap/${stage}"
  echo "  5. Execute: terragrunt run --all plan"
}

main "$@"
