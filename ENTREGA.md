# Relatório de Entrega - Tech Challenge (Fase 1)

## Plataforma ToggleMaster (Feature Flag as a Service)

Este documento apresenta a arquitetura de nuvem projetada na AWS, os detalhes de segurança e o guia completo para implantação da aplicação monolítica **ToggleMaster** (de forma manual e automatizada com Infraestrutura como Código).

---

### 👥 Informações do Projeto

- **Integrantes do Grupo:**
  - [Lúcio Alves Toledo] - RM [rm375870]
  - [Beatriz da Silva Castro] - RM [XXXXXX]
  - [Bruno Alexandre Manoel de Freitas] - RM [rm376273]
  - [Kayky Santos da Cunha Couto] - RM [XXXXXX]
- **Link do Vídeo de Demonstração:** `[Inserir Link do Vídeo do YouTube/Vimeo/Drive]`
- **Link do Diagrama Interativo:** `[Inserir Link do Miro/Diagrams.net]`

---

## 🏗️ Arquitetura da Solução na AWS

Projetamos uma infraestrutura de baixo custo e alta segurança, ideal para a implantação do MVP no escopo do AWS Academy ou AWS Free Tier. A topologia consiste em uma única VPC com subnets públicas para a instância EC2 e subnets privadas/isoladas para a base de dados relacional (RDS PostgreSQL).

### Diagrama de Arquitetura

![Arquitetura ToggleMaster](./FIAP/Arquitetura.drawio.png)

---

## ⚙️ Detalhamento dos Componentes de Infraestrutura

### 1. Rede (VPC e Subnets)

- **VPC:** Bloco CIDR `10.0.0.0/16`.
- **Subnet Pública (`10.0.1.0/24`):** Onde a instância EC2 é provisionada. Possui associação com uma Tabela de Rotas que direciona o tráfego de saída (`0.0.0.0/0`) para o **Internet Gateway (IGW)**.
- **Subnets Privadas/Isoladas (`10.0.2.0/24` e `10.0.3.0/24`):** Onde o banco de dados RDS PostgreSQL reside. Por requisitos do AWS RDS (DB Subnet Group), são usadas pelo menos duas subnets privadas localizadas em Zonas de Disponibilidade (AZs) distintas. Não possuem rotas para a internet.

### 2. Grupos de Segurança (Security Groups)

Adotamos o princípio do privilégio mínimo para a configuração dos Security Groups.

#### **SG-EC2 (Grupo de Segurança da Instância EC2)**

- **Regras de Entrada (Inbound):**
  | Tipo | Protocolo | Porta | Origem | Descrição |
  | :--- | :--- | :--- | :--- | :--- |
  | SSH | TCP | 22 | `0.0.0.0/0` (ou IP do Admin) | Permite acesso via terminal para gerenciamento. |
  | Personalizado | TCP | 5000 | `0.0.0.0/0` | Permite o tráfego da API ToggleMaster. |

#### **SG-RDS (Grupo de Segurança do Banco de Dados RDS)**

- **Regras de Entrada (Inbound):**
  | Tipo | Protocolo | Porta | Origem | Descrição |
  | :--- | :--- | :--- | :--- | :--- |
  | PostgreSQL | TCP | 5432 | `SG-EC2` (Security Group ID) | Permite conexões vindas exclusivamente da instância EC2. |

---

## 🤖 Método A: Automação Total (OpenTofu + Terragrunt)

Desenvolvemos uma solução robusta de **Infraestrutura como Código (IaC)** que provisiona todos os recursos da AWS e realiza o deploy automático da aplicação na EC2 através do script de _User Data_.

### Como Provisionar em 1 Passo:

Navegue até a pasta do ambiente e execute o comando:

```bash
cd terraform/live/fiap
terragrunt run-all apply
```

### O que essa automação faz por baixo dos panos:

1. **Rede:** Cria a VPC, Internet Gateway, Subnets públicas e privadas em AZs separadas, além das tabelas de rotas correspondentes.
2. **Segurança:** Cria os Security Groups (`sg-ec2` e `sg-rds`) estabelecendo a relação de dependência e regras de portas.
3. **RDS:** Provisiona a instância PostgreSQL gerenciada no DB Subnet Group privado.
4. **Deploy Automático na EC2 (User Data):**
   - Atualiza o SO, instala `git`, `python3-venv` e `postgresql-client`.
   - Clona o código do repositório configurado.
   - Cria o ambiente virtual (`venv`) e instala os pacotes (`requirements.txt`).
   - Salva a senha e os endpoints em `/etc/toggle-master.env` com permissão restrita `chmod 600`.
   - Executa uma verificação (`pg_isready`) em loop até o banco RDS aceitar conexões.
   - Inicializa a tabela (`flask init-db`) no RDS.
   - Configura e inicializa a unidade do `systemd` para subir a aplicação via Gunicorn na porta `5000`.

---

## 🛠️ Método B: Provisionamento e Deploy Manual

Caso queira configurar a infraestrutura de forma manual através do console da AWS, siga os passos a seguir:

### Passo 1: Criação dos Recursos na AWS Console

1.  **VPC:** Crie a VPC `vpc-togglemaster` com bloco `10.0.0.0/16`. Adicione um Internet Gateway e vincule-o à VPC. Crie uma subnet pública para a EC2 e duas subnets privadas para o RDS. Associe a tabela de rotas pública com destino `0.0.0.0/0` à subnet da EC2.
2.  **RDS PostgreSQL:** Crie uma base RDS classe `db.t3.micro` no Subnet Group cobrindo as subnets privadas, desmarcando o acesso público.
3.  **EC2:** Inicialize uma máquina com Ubuntu Server 24.04 LTS na subnet pública, associando o Security Group que libera as portas 22 e 5000.

### Passo 2: Instalação Manual da Aplicação na EC2

Acesse a EC2 via SSH e rode:

```bash
# Atualizar ferramentas
sudo apt update && sudo apt upgrade -y
sudo apt install -y git python3-pip python3-venv

# Clonar e preparar virtualenv
git clone <URL_DO_SEU_REPOSITORIO>
cd toggle-master-monolith
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configurar credenciais seguras no SO
sudo touch /etc/toggle-master.env
sudo chmod 600 /etc/toggle-master.env
sudo nano /etc/toggle-master.env
```

Conteúdo do `/etc/toggle-master.env`:

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
WorkingDirectory=/home/ubuntu/toggle-master-monolith
EnvironmentFile=/etc/toggle-master.env
ExecStart=/home/ubuntu/toggle-master-monolith/venv/bin/gunicorn --workers 3 --bind 0.0.0.0:5000 app:app

[Install]
WantedBy=multi-user.target
```

Ative a aplicação:

```bash
# Inicializar base de dados
export $(sudo cat /etc/toggle-master.env | xargs)
/home/ubuntu/toggle-master-monolith/venv/bin/flask init-db

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
      http://<ip-publico-ec2>:5000/flags
    ```

---

## 🧠 Justificativas e Decisões de Projeto

1.  **VPC com Subnets Públicas e Privadas:** Garante isolamento estrito para os dados confidenciais do banco de dados (RDS), permitindo tráfego público apenas para a API hospedada na EC2.
2.  **Restrição no Security Group do RDS:** Ao aceitar conexões vindas exclusivamente do grupo `sg-ec2`, mitigamos riscos de ataques de força bruta ou varredura de portas sobre a base PostgreSQL.
3.  **Utilização de `systemd` para Gunicorn:** Garante robustez, monitoramento e reinício automático da aplicação caso haja crash do processo Flask, elevando a confiabilidade do MVP à nível de produção.
4.  **Uso de `EnvironmentFile` com Permissões Restritas (`chmod 600`):** Isola as credenciais sensíveis de acesso ao banco fora do controle de versão do git e do histórico de processos, alinhando a entrega com as melhores práticas de gerenciamento de segredos (DevSecOps).
