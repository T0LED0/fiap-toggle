# Relatório de entrega - Tech challenge (Fase 1)

## Plataforma ToggleMaster (Feature Flag as a Service)

Esté é um projeto acadêmico realizado no ciclo de estudos para a disciplina de DevOps e Cloud Computing pela [FIAP](https://postech.fiap.com.br/curso/devops-e-arquitetura-cloud).

---

### 👥 Informações do projeto

- **Integrantes do grupo 23:**
  - [Lúcio Alves Toledo](https://www.linkedin.com/in/lucioalvestoledo/)
  - [Beatriz da Silva Castro]
  - [Bruno Alexandre Manoel de Freitas]
  - [Kayky Santos da Cunha Couto]
- **Link do vídeo de demonstração:** `[Inserir Link do Vídeo do YouTube/Vimeo/Drive]`
- **Link do diagrama interativo:** [Viewer Diagrams](https://viewer.diagrams.net/?tags=%7B%7D&lightbox=1&highlight=0000ff&edit=_blank&layers=1&link-icons=1&tooltip-icons=1&nav=1&title=Arquitetura.drawio&dark=auto#Uhttps%3A%2F%2Fdrive.google.com%2Fuc%3Fid%3D14G3c3Efr9dKG1RzBxJWqmLDQFkPXByRo%26export%3Ddownload#%7B%22pageId%22%3A%22SBcSKzsiNTP2tSRxVtA5%22%7D)

---

## Arquitetura do projeto

Projetamos uma infraestrutura de baixo custo, ideal para a implantação de um MVP seguindo os requisitos solicitados pelo desafio proposto.

Usamos o ambiente fornecido pela [FIAP](https://postech.fiap.com.br/) [AWS Academy](https://aws.amazon.com/pt/training/awsacademy/), mas o projeto pode ser executado em uma conta com [AWS Free Tier](https://aws.amazon.com/pt/free/).

A topologia consiste em uma única [VPC](https://aws.amazon.com/pt/vpc/) com subnets públicas e privadas para a [EC2](https://aws.amazon.com/pt/ec2/) e para a base de dados relacional [RDS](https://aws.amazon.com/pt/rds/).

Mantemos limitados ao requisitos e escopo do projeto nessa primeira fase, como:

- Sem balanceamento de carga
- Sem auto-scaling
- Sem containerização
- Sem alta disponibilidade
- Sem disaster recovery
- Outras recomendações do [AWS Well-Architected Framework](https://aws.amazon.com/pt/architecture/well-architected/).

Embora esteja fora do escopo do projeto, deixamos pronto a infraestrutura como codigo usando OpenTofu + Terragrunt, com objetivo de ser de fácil reprodução o MVP por todos do grupo, evitando erros e esquecimento de recursos na infraestrutura da AWS que podem ocasionar cobranças extras.

> [!IMPORTANT]
> Mesmo estando à disposição a automação via scripts, **todos os membros realizaram o processo de configuração e instalação manualmente na console da AWS** conforme instruções do desafio para que todos pudessem entender o funcionamento de cada recurso.

---

## Detalhamento dos componentes de infraestrutura

### 1. Rede (VPC e Subnets)

- **VPC:** Bloco CIDR `10.10.0.0/16`.
- **Subnet Pública (`10.10.254.0/24`):** Onde a instância EC2 é provisionada. Possui associação com uma Tabela de Rotas que direciona o tráfego de saída (`0.0.0.0/0`) para o **Internet Gateway (IGW)**.

> [!WARNING]
> Em um cenário de produção, o ideal é disponibilizar o acesso a aplicação por trás de um [Application Load Balancer](https://aws.amazon.com/pt/application-load-balancer/), por se tratar de um MVP optamos por deixar a EC2 exposta diretamente na internet apenas por simplicidade e para evitar cobranças adicionais.

- **Subnets Privadas/Isoladas (`10.10.2.0/24` e `10.10.3.0/24`):** Onde o banco de dados RDS PostgreSQL reside. Por requisitos do AWS RDS (DB Subnet Group), são usadas pelo menos duas subnets privadas localizadas em Zonas de Disponibilidade (AZs) distintas. Não possuem rotas para a internet.

### 2. Grupos de Segurança (Security Groups)

Adotamos o princípio do privilégio mínimo para a configuração dos Security Groups.

#### **SG-EC2 (Grupo de Segurança da Instância EC2)**

- **Regras de Entrada (Inbound):**
  | Tipo | Protocolo | Porta | Origem | Descrição |
  | :--- | :--- | :--- | :--- | :--- |
  | SSH | TCP | 22 | IP do Admin (/32) | Permite acesso restrito via terminal para a sua máquina. |
  | Personalizado | TCP | 3000 | `0.0.0.0/0` | Permite o tráfego da API ToggleMaster. |

#### **SG-RDS (Grupo de Segurança do Banco de Dados RDS)**

- **Regras de Entrada (Inbound):**
  | Tipo | Protocolo | Porta | Origem | Descrição |
  | :--- | :--- | :--- | :--- | :--- |
  | PostgreSQL | TCP | 5432 | `SG-EC2` (Security Group ID) | Permite conexões vindas exclusivamente da instância EC2. |

---

## Implementação com OpenTofu + Terragrunt

Desenvolvemos uma solução que conta com scripts utilitários na pasta `terraform/tools` para facilitar a configuração do ambiente local (Linux e macOS) e a execução do provisionamento na AWS, não exigindo conhecimento prévio em IaC (tema que será estudado em disciplinas futuras).

### Como configurar e provisionar usando os scripts:

1. **Preparação do ambiente:** Instale as ferramentas necessárias (OpenTofu, Terragrunt, AWS CLI e Direnv) executando o script de preparação:

   ```bash
   ./terraform/tools/1-prepare.sh
   ```

2. **Configuração de credenciais (AWS e Banco de Dados):** Antes de provisionar, configure as suas credenciais copiando os arquivos de exemplo para `.envrc` e preenchendo com os seus dados. O projeto utiliza dois níveis de configuração, o global e o específico do ambiente:

   ```bash
   # 2.1 - Configuração global (Cache)
   cp terraform/env/.envrc_example terraform/env/.envrc

   # 2.2 - Configuração do ambiente FIAP (Credenciais)
   cp terraform/env/fiap/.envrc_example terraform/env/fiap/.envrc

   # Edite o arquivo terraform/env/fiap/.envrc inserindo:
   # - Suas credenciais AWS (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
   # - A senha do banco de dados RDS (DB_PASSWORD)
   ```

   _O direnv carregará essas variáveis automaticamente quando você entrar na pasta._

3. **Provisionamento interativo:** Use o script interativo para realizar o deploy automático na AWS:
   ```bash
   ./terraform/tools/2-terragrunt.sh
   ```
   _(Basta seguir o menu interativo: selecione o ambiente `fiap`, o projeto `mvp` e depois o comando `apply`)_

### O que essa automação faz por baixo dos panos:

1. **Rede:** Cria a VPC, Internet Gateway, Subnets públicas e privadas em AZs separadas, além das tabelas de rotas correspondentes.
2. **Segurança:** Cria os Security Groups (`sg-ec2` e `sg-rds`) estabelecendo a relação de dependência e regras de portas.
3. **RDS:** Provisiona a instância PostgreSQL gerenciada no DB Subnet Group privado.
4. **Deploy Automático na EC2 (User Data):**
   - Atualiza o SO, instala `git`, `python3-venv` e `postgresql-client`.
   - Clona o código do repositório configurado no diretório `/opt/fiap`.
   - Cria o ambiente virtual (`venv`) e instala os pacotes (`app/requirements.txt`).
   - Salva a senha e os endpoints em `/opt/fiap/toggle-master-monolith/.env` com permissão restrita `chmod 600`.
   - Executa uma verificação (`pg_isready`) em loop até o banco RDS aceitar conexões.
   - Inicializa a tabela (`flask init-db`) no RDS.
   - Configura e inicializa a unidade do `systemd` para subir a aplicação via Gunicorn na porta `3000`.

---

## Provisionamento manual

Caso queira configurar a infraestrutura de forma manual através do console da AWS, siga os passos a seguir:

### Passo 1: Criação dos recursos na AWS Console

1.  **VPC:** Crie a VPC `vpc-togglemaster` com bloco `10.10.0.0/16`. Adicione um Internet Gateway e vincule-o à VPC. Crie uma subnet pública para a EC2 e duas subnets privadas para o RDS. Associe a tabela de rotas pública com destino `0.0.0.0/0` à subnet da EC2.
2.  **RDS PostgreSQL:** Crie uma base RDS classe `db.t3.micro` no Subnet Group cobrindo as subnets privadas, desmarcando o acesso público.
3.  **EC2:** Inicialize uma máquina com Ubuntu Server 24.04 LTS na subnet pública, associando o Security Group que libera as portas 22 e 3000.

### Passo 2: Instalação manual da aplicação na EC2

Acesse a EC2 via SSH e rode:

```bash
# Atualizar ferramentas
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3-pip python3-venv postgresql-client

# Preparar o diretório
sudo mkdir -p /opt/fiap
sudo chown -R ubuntu:ubuntu /opt/fiap
cd /opt/fiap

# Clonar e preparar virtualenv
git clone https://github.com/T0LED0/fiap-toggle.git toggle-master-monolith
cd toggle-master-monolith
python3 -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt

# Configurar credenciais seguras no SO
touch .env
chmod 600 .env
nano .env
```

Conteúdo do `.env`:

```ini
DB_HOST=endpoint-do-rds.amazonaws.com
DB_NAME=togglemaster
DB_USER=postgres
DB_PASSWORD=sua-senha-segura
```

Crie o arquivo do serviço `systemd`:

```bash
sudo nano /etc/systemd/system/toggle-master.service
```

Configuração do serviço:

```ini
[Unit]
Description=ToggleMaster Flask Application running under Gunicorn
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/fiap/toggle-master-monolith/app
EnvironmentFile=/opt/fiap/toggle-master-monolith/.env
ExecStart=/opt/fiap/toggle-master-monolith/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:3000 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Ative a aplicação:

```bash
# Inicializar base de dados
export $(cat /opt/fiap/toggle-master-monolith/.env | xargs)
cd /opt/fiap/toggle-master-monolith/app
/opt/fiap/toggle-master-monolith/venv/bin/flask init-db

# Rodar serviço
sudo systemctl daemon-reload
sudo systemctl start toggle-master
sudo systemctl enable toggle-master
```

---

## ⚡ Testando a API na AWS

Uma vez ativa, teste os endpoints a partir de sua máquina local:

1.  **Health Check:**

    ```bash
    curl http://<ip-publico-ec2>:3000/health
    ```

    _Saída esperada:_ `{"status": "ok"}`

2.  **Criar Nova Feature Flag:**
    ```bash
    curl -X POST \
      -H "Content-Type: application/json" \
      -d '{"name": "promo-desconto", "is_enabled": true}' \
      http://<ip-publico-ec2>:3000/flags
    ```

---

## 🧠 Justificativas e Decisões de Projeto

1.  **VPC com Subnets Públicas e Privadas:** Garante isolamento estrito para os dados confidenciais do banco de dados (RDS), permitindo tráfego público apenas para a API hospedada na EC2.
2.  **Restrição no Security Group do RDS:** Ao aceitar conexões vindas exclusivamente do grupo `sg-ec2`, mitigamos riscos de ataques de força bruta ou varredura de portas sobre a base PostgreSQL.
3.  **Utilização de `systemd` para Gunicorn:** Garante robustez, monitoramento e reinício automático da aplicação caso haja crash do processo Flask, elevando a confiabilidade do MVP à nível de produção.
4.  **Uso de `EnvironmentFile` com Permissões Restritas (`chmod 600`):** Isola as credenciais sensíveis de acesso ao banco fora do controle de versão do git e do histórico de processos, alinhando a entrega com as melhores práticas de gerenciamento de segredos (DevSecOps).
