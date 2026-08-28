# Infraestrutura OpenTofu / Terraform + Terragrunt - ToggleMaster

Este diretório contém o código de infraestrutura como código (IaC) compatível com **OpenTofu** e **Terragrunt** para provisionar todos os recursos necessários na AWS (Rede, Segurança, Banco de Dados e Servidor de Aplicação).

## 📁 Estrutura de Diretórios

```
terraform/
├── README.md                 # Este guia de uso
│
├── tools/                    # Scripts de automação
│   ├── 1-prepare.sh          # Instala todas as ferramentas necessárias (tofu, terragrunt, direnv, aws)
│   └── 2-terragrunt.sh       # Executa plan / apply / destroy via Terragrunt (menu interativo ou CLI)
│
├── env/                      # Credenciais e configurações por ambiente
│   ├── .envrc                # Variáveis de ambiente globais (carregadas pelo direnv)
│   └── fiap/                 # Ambiente FIAP
│       ├── .envrc            # Credenciais AWS do ambiente fiap
│       ├── dev/              # Stage de desenvolvimento
│       ├── hml/              # Stage de homologação
│       └── prd/              # Stage de produção
│
├── modules/                  # Módulos Terraform puros e reutilizáveis
│   └── aws/                  # Provedor AWS
│       ├── vpc/              # Módulo VPC (Rede)
│       ├── security-groups/  # Módulo de Grupos de Segurança (Firewall)
│       ├── rds/              # Módulo RDS PostgreSQL (Banco de Dados)
│       └── ec2/              # Módulo EC2 (Servidor de Aplicação + UserData de Deploy Auto)
│
└── live/                     # Estrutura Terragrunt para Ambientes (DRY)
    ├── terragrunt.hcl        # Configuração Raiz do Terragrunt (provedores/estado)
    └── fiap/                 # Ambiente de Implantação FIAP
        ├── vpc/
        │   └── terragrunt.hcl # Configuração e inputs do VPC
        ├── security-groups/
        │   └── terragrunt.hcl # Configuração e inputs dos Security Groups (Depende de VPC)
        ├── rds/
        │   └── terragrunt.hcl # Configuração e inputs do RDS (Depende de VPC e SG)
        └── ec2/
            └── terragrunt.hcl # Configuração e inputs da EC2 (Depende de VPC, SG e RDS)
```

---

## 🚀 Como Executar com Terragrunt

O Terragrunt funciona como um wrapper sobre o OpenTofu (ou Terraform). Ele resolve a ordem das dependências automaticamente e injeta os outputs de um módulo como inputs de outro.

### Pré-requisitos
1. Ter o **OpenTofu** (ou Terraform) e o **Terragrunt** instalados.
   > Execute `terraform/tools/1-prepare.sh` para instalar tudo automaticamente.
2. Configurar as credenciais da AWS no arquivo `terraform/env/fiap/.envrc`.
3. (Opcional) Definir a senha do banco de dados e chave SSH via variáveis de ambiente:
   ```bash
   export DB_PASSWORD="UmaSenhaSuperSegura123!"
   export AWS_KEY_NAME="sua-chave-ssh-aws"
   ```

> **Versão do Terragrunt:** Este projeto foi validado com **Terragrunt v1.x**, que usa a nova sintaxe de CLI (`run --all` em vez de `run-all`).
> Consulte o [guia de migração](https://docs.terragrunt.com/migrate/cli-redesign/) se necessário.

---

## 🛠️ Scripts de Automação

Todos os scripts ficam em `terraform/tools/` e devem ser executados a partir desse diretório.

### `1-prepare.sh` — Instalação do ambiente

Instala e verifica automaticamente todas as ferramentas necessárias: **OpenTofu**, **Terragrunt**, **direnv** e **AWS CLI v2**. Também cria o bucket S3 de remote state e configura o `.envrc`.

```bash
cd terraform/tools
./1-prepare.sh
```

Após a instalação, preencha suas credenciais AWS em `terraform/env/fiap/.envrc`.

---

### `2-terragrunt.sh` — Executor de plan / apply / destroy

Wrapper interativo para `terragrunt run --all`. Carrega automaticamente as credenciais AWS do `.envrc` do ambiente selecionado.

#### Modo interativo (recomendado)

Rode sem argumentos para navegar pelos menus de ambiente, stage e comando:

```bash
cd terraform/tools
./2-terragrunt.sh
```

O script listará os ambientes e stages disponíveis em `terraform/env/` e pedirá confirmação antes de executar comandos destrutivos.

#### Modo CLI (ideal para scripts e CI/CD)

```bash
# Plan
./2-terragrunt.sh -e fiap -s dev -c plan

# Apply
./2-terragrunt.sh -e fiap -s dev -c apply

# Apply sem confirmação interativa
./2-terragrunt.sh -e fiap -s dev -c apply --auto-approve

# Destroy (exige digitar 'destroy' para confirmar)
./2-terragrunt.sh -e fiap -s dev -c destroy

# Destroy sem confirmação interativa
./2-terragrunt.sh -e fiap -s prd -c destroy --auto-approve
```

#### Flags disponíveis

| Flag | Alias | Descrição |
|------|-------|-----------|
| `-e <env>` | `--environment` | Ambiente (ex: `fiap`) |
| `-s <stage>` | `--stage` | Stage (`dev`, `hml`, `prd`) |
| `-c <cmd>` | `--command` | Comando: `plan`, `apply` ou `destroy` |
| `--auto-approve` | `-y`, `--yes` | Passa `-auto-approve` ao OpenTofu (sem prompt interativo) |
| `-h` | `--help` | Exibe a ajuda |

> ⚠️ **AWS Academy:** as credenciais temporárias expiram em ~4 horas. Atualize o `terraform/env/fiap/.envrc` a cada nova sessão antes de executar qualquer comando.

### Provisionando Toda a Infraestrutura de Uma Vez

Navegue até a pasta do ambiente `fiap`:
```bash
cd terraform/live/fiap
```

1.  **Planejar a Criação de Todos os Recursos (VPC, SG, RDS, EC2):**
    ```bash
    terragrunt run --all plan
    ```
    *O Terragrunt analisa as dependências (`dependency`) nos arquivos de configuração, gerando um plano ordenado automaticamente.*

2.  **Aplicar e Provisionar Todos os Recursos:**
    ```bash
    terragrunt run --all apply
    ```
    *Confirme digitando `yes`. Os recursos serão criados na ordem correta: VPC ➡️ Security Groups ➡️ RDS ➡️ EC2.*

3.  **Destruir Todos os Recursos (Limpeza):**
    ```bash
    terragrunt run --all destroy
    ```

---

## 💡 O que o Deploy Automatizado (User Data) do EC2 realiza?

Ao inicializar, a instância EC2 executa automaticamente os seguintes passos configurados em [modules/aws/ec2/main.tf](file:///Users/lucio.toledo/Desktop/working/FIAP/toggle-master-monolith/terraform/modules/aws/ec2/main.tf):
1. Atualiza os pacotes e instala o `git`, `python3-venv` e `postgresql-client`.
2. Clona o repositório da aplicação.
3. Cria o ambiente virtual (`venv`) e instala os pacotes do `requirements.txt`.
4. Armazena de forma segura as credenciais de acesso ao banco (recebidas via outputs do RDS) em `/etc/toggle-master.env` com permissão restrita `chmod 600`.
5. Aguarda até que o RDS PostgreSQL esteja operacional e aceitando conexões.
6. Executa a CLI do Flask para inicializar a tabela `flags` no banco externo (`flask init-db`).
7. Cria a unidade de serviço `toggle-master.service` no `systemd` e inicia a API escutando na porta `5000` gerenciada pelo `gunicorn`.
