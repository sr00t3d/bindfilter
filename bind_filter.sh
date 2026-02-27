#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Bind9 DNS Filter & Security v1.3.0                                      ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: percio@evolya.com.br | contato@perciocastelo.com.br            ║
# ║   Web:     https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Prevent DNS spoofing/hijacking by blocking                     ║
# ║            specific zones in Bind9.                                       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# --- CONFIGURATION ---
SCRIPT_URL="https://raw.githubusercontent.com/sr00t3d/bindfilter/refs/heads/main/bind_filter.sh"
BLOCKED_ZONE_FILE="/etc/bind/zones/blockeddomains.db"
BLOCKED_ZONE_URL="https://raw.githubusercontent.com/sr00t3d/bindfilter/refs/heads/main/blockeddomains.db"
ACL_CONFIG_FILE="/etc/bind/blocked_domain_acl.conf"
ACL_CONFIG_URL="https://raw.githubusercontent.com/sr00t3d/bindfilter/refs/heads/main/blocked_domain_acl.conf"

# Default directories (will be detected later)
BIND_DIR_DEBIAN="/etc/bind"
BIND_DIR_RHEL="/etc"
# ---------------------

# Detect System Language
SYSTEM_LANG="${LANG:0:2}"

if [[ "$SYSTEM_LANG" == "pt" ]]; then
    # Portuguese Strings
    MSG_USAGE="Uso: $0 [OPÇÕES]"
    MSG_ERR_ROOT="ERRO: Este script deve ser executado como root."
    MSG_ERR_ARG="ERRO: Opção inválida ou argumento faltando."
    MSG_ERR_CURL="ERRO: 'curl' não encontrado. Instale-o primeiro."
    MSG_BIND_CHECK="[!] Verificando instalação do Bind9..."
    MSG_BIND_OK="[+] Bind9 detectado."
    MSG_BIND_FAIL="ERRO: Bind9 não encontrado."
    MSG_CONF_FOUND="[+] Arquivo de configuração encontrado:"
    MSG_CONF_FAIL="ERRO: Configuração do Named não encontrada."
    MSG_DIR_CREATE="[+] Criando diretório:"
    MSG_DOWN_ZONE="[+] Baixando lista de zonas bloqueadas..."
    MSG_DOWN_ACL="[+] Baixando configuração de ACL..."
    MSG_DOWN_FAIL="ERRO: Falha ao baixar"
    MSG_ACL_ADD="[+] Adicionando include da ACL na configuração..."
    MSG_ACL_EXIST="[!] Include da ACL já existe na configuração."
    MSG_RESTARTING="[!] Reiniciando serviço DNS ("
    MSG_RESTART_OK="[+] Serviço reiniciado com sucesso."
    MSG_RESTART_FAIL="ERRO: Falha ao reiniciar o serviço."
    MSG_UPDATE_ALL="[!] Atualizando TODOS os arquivos..."
    MSG_UPDATE_ZONE="[!] Atualizando apenas ZONAS..."
    MSG_UPDATE_ACL="[!] Atualizando apenas ACL..."
    MSG_CHECK_MODE="--- MODO DE VERIFICAÇÃO ---"
    MSG_CHECK_FILES="Verificando arquivos:"
    MSG_MISSING="AUSENTE"
    MSG_OK="OK"
else
    # English Strings (Default)
    MSG_USAGE="Usage: $0 [OPTIONS]"
    MSG_ERR_ROOT="ERROR: This script must be run as root."
    MSG_ERR_ARG="ERROR: Invalid option or missing argument."
    MSG_ERR_CURL="ERROR: 'curl' not found. Please install it first."
    MSG_BIND_CHECK="[!] Checking Bind9 installation..."
    MSG_BIND_OK="[+] Bind9 detected."
    MSG_BIND_FAIL="ERROR: Bind9 not found."
    MSG_CONF_FOUND="[+] Configuration file found:"
    MSG_CONF_FAIL="ERROR: Named configuration not found."
    MSG_DIR_CREATE="[+] Creating directory:"
    MSG_DOWN_ZONE="[+] Downloading blocked zones list..."
    MSG_DOWN_ACL="[+] Downloading ACL configuration..."
    MSG_DOWN_FAIL="ERROR: Failed to download"
    MSG_ACL_ADD="[+] Adding ACL include line to config..."
    MSG_ACL_EXIST="[!] ACL include already exists in config."
    MSG_RESTARTING="[!] Restarting DNS service ("
    MSG_RESTART_OK="[+] Service restarted successfully."
    MSG_RESTART_FAIL="ERROR: Failed to restart service."
    MSG_UPDATE_ALL="[!] Updating ALL files..."
    MSG_UPDATE_ZONE="[!] Updating ZONES only..."
    MSG_UPDATE_ACL="[!] Updating ACL only..."
    MSG_CHECK_MODE="--- CHECK MODE ---"
    MSG_CHECK_FILES="Checking files:"
    MSG_MISSING="MISSING"
    MSG_OK="OK"
fi

# Help Function
function display_help() {
    cat <<-EOF

$MSG_USAGE

Options:
  -r, --run             Run the script (Download, Config, Restart)
  -u, --update [TARGET] Update specific files. Targets:
                          all   - Update zones and ACL
                          zone  - Update blocked zones only
                          acl   - Update ACL config only
  -c, --check           Verify configuration and files
  -h, --help            Show this help message

EOF
}

# --- CORE FUNCTIONS ---

function log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "$MSG_ERR_ROOT"
        exit 1
    fi
}

function detect_service_and_config() {
    # Detect Config File
    if [[ -f "/etc/bind/named.conf" ]]; then
        BIND_CONFIG="/etc/bind/named.conf"
        SERVICE_NAME="bind9"
        ZONE_DIR="/etc/bind/zones"
    elif [[ -f "/etc/named.conf" ]]; then
        BIND_CONFIG="/etc/named.conf"
        SERVICE_NAME="named"
        ZONE_DIR="/var/named/zones" # RHEL standard often varies, adjusting to safe default
        # Override global variables for RHEL paths if needed
        BLOCKED_ZONE_FILE="$ZONE_DIR/blockeddomains.db"
        ACL_CONFIG_FILE="/etc/named.blocked_acl.conf"
    else
        echo "$MSG_CONF_FAIL"
        exit 1
    fi
}

function check_requirements() {
    if ! command -v curl &> /dev/null; then
        echo "$MSG_ERR_CURL"
        exit 1
    fi

    echo "$MSG_BIND_CHECK"
    # Check binary existence
    if ! command -v named &> /dev/null && ! command -v /usr/sbin/named &> /dev/null; then
        echo "$MSG_BIND_FAIL"
        exit 1
    fi
    echo "$MSG_BIND_OK"
    echo "$MSG_CONF_FOUND $BIND_CONFIG"
}

function prepare_directories() {
    local dir=$(dirname "$BLOCKED_ZONE_FILE")
    if [[ ! -d "$dir" ]]; then
        echo "$MSG_DIR_CREATE $dir"
        mkdir -p "$dir"
    fi
}

function download_zone() {
    echo "$MSG_DOWN_ZONE"
    prepare_directories
    if ! curl -s -o "$BLOCKED_ZONE_FILE" "$BLOCKED_ZONE_URL"; then
        echo "$MSG_DOWN_FAIL $BLOCKED_ZONE_FILE"
        exit 1
    fi
}

function download_acl() {
    echo "$MSG_DOWN_ACL"
    if ! curl -s -o "$ACL_CONFIG_FILE" "$ACL_CONFIG_URL"; then
        echo "$MSG_DOWN_FAIL $ACL_CONFIG_FILE"
        exit 1
    fi
}

function configure_bind() {
    # Check if include exists
    if grep -q "$(basename "$ACL_CONFIG_FILE")" "$BIND_CONFIG"; then
        echo "$MSG_ACL_EXIST"
    else
        echo "$MSG_ACL_ADD"
        # Add include at the end of the block or file
        echo "include \"$ACL_CONFIG_FILE\";" >> "$BIND_CONFIG"
    fi
}

function restart_service() {
    echo "$MSG_RESTARTING$SERVICE_NAME)..."
    
    # Validation before restart
    if command -v named-checkconf &> /dev/null; then
        if ! named-checkconf "$BIND_CONFIG"; then
            echo "Config Check Failed! Aborting restart to prevent downtime."
            exit 1
        fi
    fi

    if systemctl restart "$SERVICE_NAME"; then
        echo "$MSG_RESTART_OK"
    else
        echo "$MSG_RESTART_FAIL"
        exit 1
    fi
}

function run_check() {
    echo "$MSG_CHECK_MODE"
    echo "$MSG_CHECK_FILES"
    
    for file in "$BIND_CONFIG" "$BLOCKED_ZONE_FILE" "$ACL_CONFIG_FILE"; do
        if [[ -f "$file" ]]; then
            echo " [OK] $file"
        else
            echo " [MISSING] $file"
        fi
    done
    
    echo -n "Service Status ($SERVICE_NAME): "
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "ACTIVE"
    else
        echo "INACTIVE/FAILED"
    fi
}

# --- MAIN EXECUTION ---

check_root

# ASCII ART
echo "
 ______ __           __ _______ __ __ __              
|   __ \__|.-----.--|  |    ___|__|  |  |_.-----.----.
|   __ <  ||     |  _  |    ___|  |  |   _|  -__|   _|
|______/__||__|__|_____|___|   |__|__|____|_____|__|  
"

detect_service_and_config

# Parse Arguments
if [[ $# -eq 0 ]]; then
    display_help
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--run)
            check_requirements
            download_zone
            download_acl
            configure_bind
            restart_service
            exit 0
            ;;
        -u|--update)
            TARGET="$2"
            shift # Skip target argument
            
            check_requirements
            case "$TARGET" in
                all)
                    echo "$MSG_UPDATE_ALL"
                    download_zone
                    download_acl
                    ;;
                zone)
                    echo "$MSG_UPDATE_ZONE"
                    download_zone
                    ;;
                acl)
                    echo "$MSG_UPDATE_ACL"
                    download_acl
                    ;;
                *)
                    echo "$MSG_ERR_ARG (all|zone|acl)"
                    exit 1
                    ;;
            esac
            restart_service
            exit 0
            ;;
        -c|--check)
            run_check
            exit 0
            ;;
        -h|--help)
            display_help
            exit 0
            ;;
        *)
            echo "$MSG_ERR_ARG $1"
            display_help
            exit 1
            ;;
    esac
    shift
done