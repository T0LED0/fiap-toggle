#!/bin/bash

API_ENV_FILE="$(dirname "$0")/.api_env"

if [[ -f "$API_ENV_FILE" ]]; then
    source "$API_ENV_FILE"
    PUBLIC_IP="$TOGGLE_API_IP"
    echo "✅ IP Público carregado via env: $PUBLIC_IP"
else
    echo "⏳ Arquivo .api_env não encontrado. Tentando obter IP via terragrunt..."
    TG_DIR="$(dirname "$0")/../env/fiap/mvp/ec2"
    CURRENT_DIR=$(pwd)
    cd "$TG_DIR" || { echo "❌ Erro: Diretório $TG_DIR não encontrado."; exit 1; }
    PUBLIC_IP=$(terragrunt output -raw public_ip 2>/dev/null)
    cd "$CURRENT_DIR" || exit 1
fi

if [ -z "$PUBLIC_IP" ] || [[ "$PUBLIC_IP" == *"No outputs found"* ]] || [[ "$PUBLIC_IP" == *"Error"* ]]; then
    echo "❌ Erro: Não foi possível obter o IP público."
    echo "Certifique-se de que o ambiente foi provisionado com o script '2-terragrunt.sh apply' (que exporta o IP)."
    exit 1
fi

BASE_URL="http://${PUBLIC_IP}:3000"

while true; do
    echo ""
    echo "========================================="
    echo "      Testador da API de Feature Flags   "
    echo "========================================="
    echo "URL Base: $BASE_URL"
    echo "1. Criar uma nova flag (POST /flags)"
    echo "2. Listar todas as flags (GET /flags)"
    echo "3. Consultar uma flag específica (GET /flags/<nome>)"
    echo "4. Atualizar uma flag (PUT /flags/<nome>)"
    echo "5. Sair"
    echo "========================================="
    read -p "Escolha uma opção: " OPCAO

    case $OPCAO in
        1)
            read -p "Digite o nome da flag (ex: new-feature): " FLAG_NAME
            read -p "A flag está habilitada? (true/false): " FLAG_STATUS
            CMD="curl --connect-timeout 5 --max-time 10 -s -X POST -H \"Content-Type: application/json\" -d '{\"name\": \"$FLAG_NAME\", \"is_enabled\": $FLAG_STATUS}' $BASE_URL/flags"
            echo -e "\nExecutando:\n$CMD\n"
            eval "$CMD"
            echo -e "\n"
            ;;
        2)
            CMD="curl --connect-timeout 5 --max-time 10 -s -X GET $BASE_URL/flags"
            echo -e "\nExecutando:\n$CMD | jq\n"
            eval "$CMD | jq"
            echo -e "\n"
            ;;
        3)
            read -p "Digite o nome da flag: " FLAG_NAME
            CMD="curl --connect-timeout 5 --max-time 10 -s -X GET $BASE_URL/flags/$FLAG_NAME"
            echo -e "\nExecutando:\n$CMD | jq\n"
            eval "$CMD | jq"
            echo -e "\n"
            ;;
        4)
            read -p "Digite o nome da flag a ser atualizada: " FLAG_NAME
            read -p "A flag está habilitada? (true/false): " FLAG_STATUS
            CMD="curl --connect-timeout 5 --max-time 10 -s -X PUT -H \"Content-Type: application/json\" -d '{\"is_enabled\": $FLAG_STATUS}' $BASE_URL/flags/$FLAG_NAME"
            echo -e "\nExecutando:\n$CMD\n"
            eval "$CMD"
            echo -e "\n"
            ;;
        5)
            echo "Saindo..."
            exit 0
            ;;
        *)
            echo "Opção inválida!"
            ;;
    esac

    echo ""
    read -p "Pressione [Enter] para continuar..."
done
