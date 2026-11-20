#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                                                                           ║
# ║   Bind9 DNS Filter & Security v2.1.0                                      ║
# ║                                                                           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣
# ║   Autor:   Percio Castelo                                                 ║
# ║   Contato: contato@perciocastelo.com.br                                   ║
# ║   Website: https://perciocastelo.com.br                                   ║
# ║                                                                           ║
# ║   Função:  Sinkhole de domínios maliciosos no BIND9/Named com gestão     ║
# ║            de listas ACL, backup automático e suporte universal para     ║
# ║            cPanel/WHM, HestiaPanel, DirectAdmin, Debian e RHEL           ║
# ║                                                                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

set -o pipefail

# ==============================================================================
# VERSÃO E URLS
# ==============================================================================
VERSION="2.1.0"
REPO_BASE="https://raw.githubusercontent.com/sr00t3d/bindfilter/refs/heads/main"
BLOCKED_ZONE_URL="${REPO_BASE}/blockeddomains.db"
ACL_CONFIG_URL="${REPO_BASE}/blocked_domain_acl.conf"

# ==============================================================================
# DEFAULTS (serão sobrescritos após detect_environment)
# ==============================================================================
BIND_CONFIG=""      # Arquivo principal de configuração do BIND
BIND_INJECT=""      # Arquivo onde o include será injetado (pode diferir de BIND_CONFIG)
SERVICE_NAME=""     # nome do serviço systemd/init
ZONE_DIR=""         # diretório de zonas
BLOCKED_ZONE_FILE=""
ACL_CONFIG_FILE=""

# Flags de ambiente (preenchidas por detect_environment)
USES_VIEWS=false     # cPanel/WHM usa view blocks
PANEL_TYPE=""        # cpanel | hestia | directadmin | plain

DRY_RUN=false
VERBOSE=false
USE_COLOR=true
NO_RESTART=false

# Disable colors if stdout is not a terminal
[[ ! -t 1 ]] && USE_COLOR=false

# ==============================================================================
# CORES
# ==============================================================================
setup_colors() {
    if [[ "$USE_COLOR" = true ]]; then
        C_RESET='\033[0m'
        C_GREEN='\033[0;32m'
        C_RED='\033[0;31m'
        C_YELLOW='\033[0;33m'
        C_BLUE='\033[0;34m'
        C_CYAN='\033[0;36m'
        C_BOLD='\033[1m'
    else
        C_RESET='' C_GREEN='' C_RED='' C_YELLOW='' C_BLUE='' C_CYAN='' C_BOLD=''
    fi
}

# ==============================================================================
# LOG HELPERS
# ==============================================================================
log_info()  { echo -e "${C_GREEN}[+]${C_RESET} $*"; }
log_warn()  { echo -e "${C_YELLOW}[!]${C_RESET} $*"; }
log_err()   { echo -e "${C_RED}[✗]${C_RESET} $*" >&2; }
log_step()  { echo -e "${C_BLUE}[→]${C_RESET} $*"; }
log_dry()   { echo -e "${C_CYAN}[DRY]${C_RESET} $*"; }
log_debug() { [[ "$VERBOSE" = true ]] && echo -e "${C_RESET}[·] $*" >&2 || true; }

# ==============================================================================
# USAGE
# ==============================================================================
usage() {
    cat <<EOF
${C_BOLD}Bind9 DNS Filter & Security v${VERSION}${C_RESET}
DNS Sinkhole universal: cPanel/WHM, HestiaPanel, DirectAdmin, Debian, RHEL

Uso: $(basename "$0") [COMANDO] [OPÇÕES]

${C_BOLD}Comandos:${C_RESET}
  -r, --run               Instalação completa: baixa listas, configura BIND9 e recarrega
  -u, --update [ALVO]     Atualiza arquivos de bloqueio. Alvos: all | zone | acl
      --add DOMÍNIO       Adiciona um domínio à ACL local de bloqueio e recarrega
      --remove DOMÍNIO    Remove um domínio da ACL local e recarrega
  -c, --check             Verifica status do ambiente (arquivos, serviço, contagem de zonas)
      --stats             Exibe estatísticas da lista de bloqueio atual
      --uninstall         Remove as configurações de bloqueio e restaura named.conf

${C_BOLD}Opções:${C_RESET}
  -n, --dry-run           Simula as operações sem efetuar alterações reais
  -v, --verbose           Exibir mensagens de debug detalhadas
      --no-color          Desativar cores na saída
      --no-restart        Pula o reload/restart do BIND9 (útil em scripts de automação)
  -h, --help              Exibir este menu de ajuda

${C_BOLD}Painéis suportados:${C_RESET}
  cPanel/WHM        (RHEL/AlmaLinux — /etc/named.conf com views)
  HestiaPanel       (Debian/Ubuntu  — /etc/bind/named.conf.local)
  DirectAdmin       (RHEL ou Debian — detecção automática)
  Sem painel        (RHEL ou Debian — detecção automática)

${C_BOLD}Exemplos:${C_RESET}
  $(basename "$0") -r                        # Instalação completa
  $(basename "$0") -r --dry-run              # Simulação sem alterações
  $(basename "$0") --add malware.example.com # Bloqueia um domínio
  $(basename "$0") --remove malware.example.com
  $(basename "$0") -u zone                   # Atualiza só o db de zonas
  $(basename "$0") -c                        # Status do ambiente
  $(basename "$0") --stats                   # Estatísticas da ACL
  $(basename "$0") --uninstall               # Remove tudo e restaura
EOF
    exit 0
}

# ==============================================================================
# VERIFICAÇÃO DE ROOT
# ==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_err "Este script deve ser executado como root."
        exit 1
    fi
}

# ==============================================================================
# VERIFICAÇÃO DE DEPENDÊNCIAS
# ==============================================================================
check_dependencies() {
    local missing=()
    for bin in named named-checkconf curl; do
        if ! command -v "$bin" &>/dev/null; then
            missing+=("$bin")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "Dependências não encontradas: ${missing[*]}"
        log_err "Instale o pacote bind (RHEL: bind bind-utils | Debian: bind9 bind9utils) e curl."
        exit 1
    fi
    log_debug "Dependências OK: named, named-checkconf, curl"
}

# ==============================================================================
# DETECÇÃO DE AMBIENTE — UNIVERSAL
#
# Hierarquia de detecção:
#   1. Painel identificado por paths ou marcadores específicos
#   2. Base OS (RHEL vs Debian)
#   3. Presença de views no named.conf (cPanel style)
#
# Variáveis preenchidas:
#   BIND_CONFIG   — config principal (para leitura/backup/checkconf)
#   BIND_INJECT   — onde o include é inserido (pode ser named.conf.local)
#   SERVICE_NAME  — nome do serviço systemd
#   ZONE_DIR      — diretório de zonas de bloqueio
#   USES_VIEWS    — true se named.conf usa view blocks
#   PANEL_TYPE    — cpanel | hestia | directadmin | plain
# ==============================================================================
detect_environment() {
    log_step "Detectando ambiente BIND9..."

    # --- Detecção de painel ---
    if [[ -d "/usr/local/cpanel" ]] || [[ -f "/etc/cpanel/cpanel.config" ]]; then
        PANEL_TYPE="cpanel"
    elif [[ -d "/usr/local/hestia" ]] || [[ -d "/usr/local/vesta" ]]; then
        PANEL_TYPE="hestia"
    elif [[ -d "/usr/local/directadmin" ]]; then
        PANEL_TYPE="directadmin"
    else
        PANEL_TYPE="plain"
    fi

    log_debug "Painel detectado: ${PANEL_TYPE}"

    # --- cPanel/WHM (sempre RHEL-based, sempre com views) ---
    if [[ "$PANEL_TYPE" = "cpanel" ]]; then
        BIND_CONFIG="/etc/named.conf"
        BIND_INJECT="/etc/named.conf"   # inject inside views via Python
        SERVICE_NAME="named"
        ZONE_DIR="/var/named/zones/blocked"
        ACL_CONFIG_FILE="/etc/named.blocked_acl.conf"
        BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
        USES_VIEWS=true
        log_info "Ambiente detectado: cPanel/WHM (RHEL/AlmaLinux — named com views)"

    # --- HestiaPanel (Debian/Ubuntu — usa named.conf.local) ---
    elif [[ "$PANEL_TYPE" = "hestia" ]]; then
        BIND_CONFIG="/etc/bind/named.conf"
        BIND_INJECT="/etc/bind/named.conf.local"   # arquivo próprio, sem views
        SERVICE_NAME="bind9"
        ZONE_DIR="/var/cache/bind/zones/blocked"
        ACL_CONFIG_FILE="/etc/bind/blocked_domain_acl.conf"
        BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
        USES_VIEWS=false
        log_info "Ambiente detectado: HestiaPanel (Debian/Ubuntu — bind9 com named.conf.local)"

    # --- DirectAdmin (pode ser RHEL ou Debian) ---
    elif [[ "$PANEL_TYPE" = "directadmin" ]]; then
        if [[ -f "/etc/named.conf" ]]; then
            BIND_CONFIG="/etc/named.conf"
            BIND_INJECT="/etc/named.conf"
            SERVICE_NAME="named"
            ZONE_DIR="/var/named/zones/blocked"
            ACL_CONFIG_FILE="/etc/named.blocked_acl.conf"
            BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
            log_info "Ambiente detectado: DirectAdmin (RHEL/AlmaLinux — named)"
        elif [[ -f "/etc/bind/named.conf" ]]; then
            BIND_CONFIG="/etc/bind/named.conf"
            BIND_INJECT="/etc/bind/named.conf.local"
            SERVICE_NAME="bind9"
            ZONE_DIR="/var/cache/bind/zones/blocked"
            ACL_CONFIG_FILE="/etc/bind/blocked_domain_acl.conf"
            BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
            log_info "Ambiente detectado: DirectAdmin (Debian/Ubuntu — bind9)"
        else
            log_err "DirectAdmin detectado mas configuração do BIND não encontrada."
            exit 1
        fi
        # DirectAdmin geralmente não usa views
        USES_VIEWS=false

    # --- Sem painel — detecção por OS ---
    elif [[ -f "/etc/bind/named.conf" ]]; then
        BIND_CONFIG="/etc/bind/named.conf"
        # HestiaPanel ou plain Debian — usa named.conf.local se existir
        if [[ -f "/etc/bind/named.conf.local" ]]; then
            BIND_INJECT="/etc/bind/named.conf.local"
        else
            BIND_INJECT="/etc/bind/named.conf"
        fi
        SERVICE_NAME="bind9"
        ZONE_DIR="/var/cache/bind/zones/blocked"
        ACL_CONFIG_FILE="/etc/bind/blocked_domain_acl.conf"
        BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
        USES_VIEWS=false
        log_info "Ambiente detectado: Debian/Ubuntu (bind9)"

    elif [[ -f "/etc/named.conf" ]]; then
        BIND_CONFIG="/etc/named.conf"
        BIND_INJECT="/etc/named.conf"
        SERVICE_NAME="named"
        ZONE_DIR="/var/named/zones/blocked"
        ACL_CONFIG_FILE="/etc/named.blocked_acl.conf"
        BLOCKED_ZONE_FILE="${ZONE_DIR}/blockeddomains.db"
        USES_VIEWS=false
        log_info "Ambiente detectado: RHEL/AlmaLinux/CentOS (named)"

    else
        log_err "Configuração do BIND9/Named não encontrada."
        log_err "Esperado: /etc/bind/named.conf (Debian) ou /etc/named.conf (RHEL)"
        exit 1
    fi

    # Se não é cPanel, ainda pode ter views — detectar dinamicamente
    if [[ "$PANEL_TYPE" != "cpanel" ]] && grep -qE '^\s*view\s+"' "$BIND_CONFIG" 2>/dev/null; then
        USES_VIEWS=true
        BIND_INJECT="$BIND_CONFIG"  # precisa injetar dentro das views
        log_warn "named.conf usa views — inject será feito dentro de cada view block"
    fi

    # Garantir que BIND_INJECT existe (cria se for named.conf.local)
    if [[ ! -f "$BIND_INJECT" ]] && [[ "$BIND_INJECT" != "$BIND_CONFIG" ]]; then
        if [[ "$DRY_RUN" = false ]]; then
            touch "$BIND_INJECT"
            # Garantir que named.conf.local é incluído pelo named.conf
            if ! grep -qF "named.conf.local" "$BIND_CONFIG" 2>/dev/null; then
                echo 'include "/etc/bind/named.conf.local";' >> "$BIND_CONFIG"
                log_info "Include de named.conf.local adicionado ao named.conf"
            fi
        fi
    fi

    log_info "Config:    $BIND_CONFIG"
    log_info "Inject:    $BIND_INJECT"
    log_info "Serviço:   $SERVICE_NAME"
    log_info "Zonas:     $ZONE_DIR"
    log_info "ACL:       $ACL_CONFIG_FILE"
    log_info "Painel:    $PANEL_TYPE"
    log_info "Views:     $USES_VIEWS"
}

# ==============================================================================
# BACKUP DO ARQUIVO DE CONFIGURAÇÃO
# ==============================================================================
backup_named_conf() {
    local target="${1:-$BIND_INJECT}"
    local backup="${target}.bkp.$(date +'%Y%m%d_%H%M%S')"
    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Backup seria criado: $backup"
        return 0
    fi
    cp "$target" "$backup"
    log_info "Backup criado: $backup"
}

# ==============================================================================
# CRIA DIRETÓRIO DE ZONAS
# ==============================================================================
create_zone_dir() {
    if [[ ! -d "$ZONE_DIR" ]]; then
        if [[ "$DRY_RUN" = true ]]; then
            log_dry "Criaria diretório: $ZONE_DIR"
            return 0
        fi
        mkdir -p "$ZONE_DIR"
        # Ajustar owner para o usuário do named/bind
        local named_user
        named_user="$(ps -eo user,comm 2>/dev/null | awk '/named|bind9/{print $1; exit}')"
        named_user="${named_user:-named}"
        chown "${named_user}:${named_user}" "$ZONE_DIR" 2>/dev/null || true
        log_info "Diretório criado: $ZONE_DIR"
    fi
}

# ==============================================================================
# GERA ZONA SINKHOLE LOCAL (fallback se download falhar)
# ==============================================================================
generate_sinkhole_db() {
    local hn
    hn="$(hostname -f 2>/dev/null || hostname)"
    cat <<ZONE
\$TTL 86400
@ IN SOA ${hn}. hostmaster.${hn}. (
        $(date +'%Y%m%d')01 ; Serial
        3600            ; Refresh
        900             ; Retry
        604800          ; Expire
        86400 )         ; Minimum TTL
        IN NS ${hn}.
        IN A 127.0.0.1
*       IN A 127.0.0.1
ZONE
}

# ==============================================================================
# DOWNLOAD DA ZONA DE BLOQUEIO
# ==============================================================================
download_zone() {
    log_step "Baixando lista de zonas bloqueadas..."
    create_zone_dir
    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Baixaria: $BLOCKED_ZONE_URL → $BLOCKED_ZONE_FILE"
        return 0
    fi

    if ! curl -sS --max-time 15 --retry 2 -o "${BLOCKED_ZONE_FILE}.tmp" "$BLOCKED_ZONE_URL" 2>/dev/null; then
        log_warn "Download da zona falhou — usando sinkhole gerado localmente."
        generate_sinkhole_db > "$BLOCKED_ZONE_FILE"
    else
        if grep -qiE '(\$TTL|SOA|IN\s+NS|HOSTNAME)' "${BLOCKED_ZONE_FILE}.tmp"; then
            local hn
            hn="$(hostname -f 2>/dev/null || hostname)"
            sed "s/HOSTNAME/${hn}/g" "${BLOCKED_ZONE_FILE}.tmp" > "$BLOCKED_ZONE_FILE"
            log_info "Zona de bloqueio instalada: $BLOCKED_ZONE_FILE"
        else
            log_warn "Formato inesperado no download — usando sinkhole gerado localmente."
            generate_sinkhole_db > "$BLOCKED_ZONE_FILE"
        fi
        rm -f "${BLOCKED_ZONE_FILE}.tmp"
    fi

    local named_user
    named_user="$(ps -eo user,comm 2>/dev/null | awk '/named|bind9/{print $1; exit}')"
    named_user="${named_user:-named}"
    chown "${named_user}:${named_user}" "$BLOCKED_ZONE_FILE" 2>/dev/null || true
    chmod 640 "$BLOCKED_ZONE_FILE"
}

# ==============================================================================
# DOWNLOAD DA ACL (lista de zonas bloqueadas)
# ==============================================================================
download_acl() {
    log_step "Baixando configuração de ACL..."
    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Baixaria: $ACL_CONFIG_URL → $ACL_CONFIG_FILE"
        return 0
    fi

    if ! curl -sS --max-time 15 --retry 2 -o "${ACL_CONFIG_FILE}.tmp" "$ACL_CONFIG_URL" 2>/dev/null; then
        log_warn "Download da ACL falhou."
        [[ -f "$ACL_CONFIG_FILE" ]] || { log_err "ACL não encontrada e download falhou."; exit 1; }
        return 0
    fi

    # Corrige o path do .db para o ambiente atual e garante newline final
    sed "s|/etc/bind/zones/blockeddomains.db|${BLOCKED_ZONE_FILE}|g;
         s|/var/named/zones/blocked/blockeddomains.db|${BLOCKED_ZONE_FILE}|g" \
        "${ACL_CONFIG_FILE}.tmp" > "$ACL_CONFIG_FILE"
    rm -f "${ACL_CONFIG_FILE}.tmp"
    [[ -s "$ACL_CONFIG_FILE" && -n "$(tail -c 1 "$ACL_CONFIG_FILE")" ]] && echo "" >> "$ACL_CONFIG_FILE"

    local named_user
    named_user="$(ps -eo user,comm 2>/dev/null | awk '/named|bind9/{print $1; exit}')"
    named_user="${named_user:-named}"
    chown "${named_user}:${named_user}" "$ACL_CONFIG_FILE" 2>/dev/null || true
    chmod 640 "$ACL_CONFIG_FILE"
    log_info "ACL instalada: $ACL_CONFIG_FILE"
}

# ==============================================================================
# CONFIGURE BIND — Injeta o include no local correto
#
# Estratégia por caso:
#
#  [A] Sem views — append em BIND_INJECT (pode ser named.conf ou named.conf.local)
#      • HestiaPanel, DirectAdmin/Debian, plain Debian → named.conf.local
#      • DirectAdmin/RHEL, plain RHEL sem views       → named.conf global
#
#  [B] Com views (cPanel/WHM ou RHEL com views customizadas)
#      → Injeta o include DENTRO de cada view { ... } usando Python3
#      → Python3 está disponível em AlmaLinux 8+ e todos os Debians modernos
#      → Fallback awk para sistemas sem Python3
#
# ==============================================================================
configure_bind() {
    local include_line="include \"${ACL_CONFIG_FILE}\";"

    # Verificar se já foi configurado
    if grep -qF "$ACL_CONFIG_FILE" "$BIND_INJECT" 2>/dev/null || \
       grep -qF "$ACL_CONFIG_FILE" "$BIND_CONFIG" 2>/dev/null; then
        log_warn "Include da ACL já existe em ${BIND_INJECT}. Nada a fazer."
        return 0
    fi

    if [[ "$DRY_RUN" = true ]]; then
        if [[ "$USES_VIEWS" = true ]]; then
            log_dry "named.conf usa views — include seria injetado dentro de cada view block em ${BIND_INJECT}"
        else
            log_dry "Adicionaria ao ${BIND_INJECT}: ${include_line}"
        fi
        return 0
    fi

    backup_named_conf "$BIND_INJECT"

    # --- CASO B: com views ---
    if [[ "$USES_VIEWS" = true ]]; then
        _inject_into_views
        log_info "Include da ACL injetado em cada view de ${BIND_INJECT}"
        return 0
    fi

    # --- CASO A: sem views — append simples ---
    {
        echo ""
        echo "// === bindfilter v${VERSION} — DNS sinkhole ==="
        echo "${include_line}"
    } >> "$BIND_INJECT"
    log_info "Include da ACL injetado em ${BIND_INJECT}"
}

# ------------------------------------------------------------------------------
# Injeta include dentro de cada view { ... } preservando estrutura do arquivo.
# Usa Python3 (preferido) com fallback para awk.
# ------------------------------------------------------------------------------
_inject_into_views() {
    if command -v python3 &>/dev/null; then
        _inject_views_python3
    else
        log_warn "Python3 não disponível — usando awk para injeção em views."
        _inject_views_awk
    fi
}

_inject_views_python3() {
    python3 - <<PYEOF "$BIND_INJECT" "$ACL_CONFIG_FILE" "$VERSION"
import sys, re

conf_file = sys.argv[1]
acl_file  = sys.argv[2]
version   = sys.argv[3]
include_line = '    include "{}"; // bindfilter v{}\n'.format(acl_file, version)

with open(conf_file, 'r') as f:
    lines = f.readlines()

result = []
depth = 0
in_view = False
inserted_views = set()
view_name = None

for line in lines:
    m = re.match(r'\s*view\s+"([^"]+)"', line)
    if m:
        in_view = True
        view_name = m.group(1)
        depth = 0

    if in_view:
        opens  = line.count('{')
        closes = line.count('}')
        depth += opens - closes
        if depth <= 0 and '}' in line and in_view:
            if view_name not in inserted_views:
                result.append(include_line)
                inserted_views.add(view_name)
            in_view = False
            view_name = None

    result.append(line)

with open(conf_file, 'w') as f:
    f.writelines(result)

print("Inserted include into {} view(s): {}".format(len(inserted_views), ', '.join(inserted_views)))
PYEOF
}

_inject_views_awk() {
    # Fallback awk: injeta include antes do último '};' de cada view
    local tmpfile
    tmpfile="$(mktemp)"
    local acl="$ACL_CONFIG_FILE"
    local ver="$VERSION"
    awk -v acl="$acl" -v ver="$ver" '
        /^view[[:space:]]/ { in_view=1; depth=0 }
        in_view {
            for(i=1;i<=length($0);i++){
                c=substr($0,i,1)
                if(c=="{") depth++
                if(c=="}") depth--
            }
            if(depth<=0 && /}/) {
                print "    include \"" acl "\"; // bindfilter v" ver
                in_view=0
            }
        }
        { print }
    ' "$BIND_INJECT" > "$tmpfile" && mv "$tmpfile" "$BIND_INJECT"
}

# ==============================================================================
# RELOAD / RESTART DO SERVIÇO
# ==============================================================================
reload_service() {
    [[ "$NO_RESTART" = true ]] && { log_warn "Reload ignorado (--no-restart)."; return 0; }

    log_step "Validando configuração com named-checkconf..."
    if [[ "$DRY_RUN" = true ]]; then
        log_dry "named-checkconf $BIND_CONFIG && reload ${SERVICE_NAME}"
        return 0
    fi

    if ! named-checkconf "$BIND_CONFIG" 2>&1; then
        log_err "named-checkconf falhou! Abortando reload para evitar downtime."
        log_err "Reverta o backup do arquivo de configuração manualmente se necessário."
        exit 1
    fi
    log_info "Configuração válida."

    log_step "Recarregando serviço ${SERVICE_NAME}..."

    # Tenta rndc reload primeiro (gracioso), fallback para systemctl
    if command -v rndc &>/dev/null && rndc reload 2>/dev/null; then
        log_info "Serviço recarregado via rndc reload."
    elif systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl reload "$SERVICE_NAME" 2>/dev/null || systemctl restart "$SERVICE_NAME"
        log_info "Serviço recarregado via systemctl."
    elif service "$SERVICE_NAME" reload 2>/dev/null; then
        log_info "Serviço recarregado via service."
    else
        log_warn "Não foi possível recarregar o serviço automaticamente."
        log_warn "Execute manualmente: systemctl restart ${SERVICE_NAME}"
    fi
}

# ==============================================================================
# ADICIONAR DOMÍNIO À ACL
# ==============================================================================
add_domain() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        log_err "Informe o domínio: --add <dominio>"
        exit 1
    fi

    # Guard DRY_RUN antes de checar existência do arquivo
    if [[ ! -f "$ACL_CONFIG_FILE" ]]; then
        if [[ "$DRY_RUN" = true ]]; then
            log_dry "--add: ACL não existe ainda (seria criada pelo -r primeiro)"
            return 0
        fi
        log_err "ACL não encontrada: $ACL_CONFIG_FILE. Execute -r primeiro."
        exit 1
    fi

    if grep -qF "\"${domain}\"" "$ACL_CONFIG_FILE"; then
        log_warn "Domínio '${domain}' já está na lista."
        return 0
    fi

    local zone_entry="zone \"${domain}\" {type master; file \"${BLOCKED_ZONE_FILE}\";};"

    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Adicionaria ao ACL: $zone_entry"
        return 0
    fi

    [[ -s "$ACL_CONFIG_FILE" && -n "$(tail -c 1 "$ACL_CONFIG_FILE")" ]] && echo "" >> "$ACL_CONFIG_FILE"
    echo "$zone_entry" >> "$ACL_CONFIG_FILE"
    log_info "Domínio adicionado: $domain"
    reload_service
}

# ==============================================================================
# REMOVER DOMÍNIO DA ACL
# ==============================================================================
remove_domain() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        log_err "Informe o domínio: --remove <dominio>"
        exit 1
    fi

    # Guard DRY_RUN antes de checar existência do arquivo
    if [[ ! -f "$ACL_CONFIG_FILE" ]]; then
        if [[ "$DRY_RUN" = true ]]; then
            log_dry "--remove: ACL não existe ainda (nada a remover)"
            return 0
        fi
        log_err "ACL não encontrada: $ACL_CONFIG_FILE"
        exit 1
    fi

    if ! grep -qF "\"${domain}\"" "$ACL_CONFIG_FILE"; then
        log_warn "Domínio '${domain}' não encontrado na lista."
        return 0
    fi

    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Removeria do ACL: $domain"
        return 0
    fi

    local tmpfile
    tmpfile="$(mktemp)"
    grep -vF "\"${domain}\"" "$ACL_CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$ACL_CONFIG_FILE"
    log_info "Domínio removido: $domain"
    reload_service
}

# ==============================================================================
# CHECK — STATUS DO AMBIENTE
# ==============================================================================
run_check() {
    echo
    echo -e "${C_BOLD}=== Status do Ambiente bindfilter ===${C_RESET}"
    echo

    # Arquivos de configuração
    echo -e "${C_BOLD}Configuração:${C_RESET}"
    local check_files=("$BIND_CONFIG")
    [[ "$BIND_INJECT" != "$BIND_CONFIG" ]] && check_files+=("$BIND_INJECT")
    check_files+=("$ACL_CONFIG_FILE" "$BLOCKED_ZONE_FILE")
    for f in "${check_files[@]}"; do
        if [[ "$f" = "$BIND_CONFIG" || "$f" = "$BIND_INJECT" ]]; then
            [[ -f "$f" ]] && echo -e "  ${C_GREEN}✓${C_RESET} $f" || echo -e "  ${C_RED}✗${C_RESET} $f (não encontrado)"
        else
            [[ -f "$f" ]] && echo -e "  ${C_GREEN}✓${C_RESET} $f" || echo -e "  ${C_YELLOW}—${C_RESET} $f (não instalado)"
        fi
    done

    # Include no arquivo de inject
    echo
    echo -e "${C_BOLD}Include no arquivo de config (${BIND_INJECT}):${C_RESET}"
    if grep -qF "$ACL_CONFIG_FILE" "$BIND_INJECT" 2>/dev/null || \
       grep -qF "$ACL_CONFIG_FILE" "$BIND_CONFIG" 2>/dev/null; then
        echo -e "  ${C_GREEN}✓${C_RESET} Include da ACL detectado"
    else
        echo -e "  ${C_YELLOW}—${C_RESET} Include não encontrado (execute -r)"
    fi

    # Validação named-checkconf
    echo
    echo -e "${C_BOLD}Validação named-checkconf:${C_RESET}"
    if named-checkconf "$BIND_CONFIG" 2>&1; then
        echo -e "  ${C_GREEN}✓${C_RESET} Configuração válida"
    else
        echo -e "  ${C_RED}✗${C_RESET} Erros na configuração"
    fi

    # Status do serviço
    echo
    echo -e "${C_BOLD}Serviço ${SERVICE_NAME}:${C_RESET}"
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "  ${C_GREEN}✓${C_RESET} Ativo (running)"
    else
        echo -e "  ${C_RED}✗${C_RESET} Parado ou inativo"
    fi

    echo
}

# ==============================================================================
# STATS
# ==============================================================================
run_stats() {
    echo
    echo -e "${C_BOLD}=== Estatísticas bindfilter ===${C_RESET}"
    echo

    if [[ -f "$ACL_CONFIG_FILE" ]]; then
        local total_zones
        total_zones="$(grep -c 'zone "' "$ACL_CONFIG_FILE" 2>/dev/null || echo 0)"
        local last_modified
        last_modified="$(date -r "$ACL_CONFIG_FILE" +'%Y-%m-%d %H:%M:%S' 2>/dev/null \
            || stat -c '%y' "$ACL_CONFIG_FILE" 2>/dev/null | cut -d. -f1 || echo 'N/A')"
        local acl_size
        acl_size="$(du -sh "$ACL_CONFIG_FILE" 2>/dev/null | awk '{print $1}')"
        echo -e "  Domínios bloqueados na ACL : ${C_BOLD}${total_zones}${C_RESET}"
        echo -e "  Tamanho da ACL             : ${acl_size}"
        echo -e "  Última modificação         : ${last_modified}"
    else
        echo -e "  ${C_YELLOW}ACL não instalada ainda.${C_RESET}"
    fi

    if [[ -f "$BLOCKED_ZONE_FILE" ]]; then
        local zone_size
        zone_size="$(du -sh "$BLOCKED_ZONE_FILE" 2>/dev/null | awk '{print $1}')"
        echo -e "  Tamanho do sinkhole .db    : ${zone_size}"
    fi

    echo -e "  Versão do script           : v${VERSION}"
    echo -e "  Painel detectado           : ${PANEL_TYPE}"
    echo -e "  Ambiente                   : ${SERVICE_NAME} (${BIND_CONFIG})"
    echo -e "  Inject em                  : ${BIND_INJECT}"
    echo -e "  Usa views                  : ${USES_VIEWS}"
    echo
}

# ==============================================================================
# UNINSTALL
# ==============================================================================
run_uninstall() {
    log_warn "Desinstalando bindfilter..."

    if [[ "$DRY_RUN" = true ]]; then
        log_dry "Removeria include do ${BIND_INJECT}"
        log_dry "Removeria: ${ACL_CONFIG_FILE}"
        log_dry "Removeria: ${BLOCKED_ZONE_FILE}"
        log_dry "Recarregaria: ${SERVICE_NAME}"
        return 0
    fi

    backup_named_conf "$BIND_INJECT"

    # Remove bloco injetado (funciona tanto em views quanto em append global)
    if grep -qF "bindfilter" "$BIND_INJECT" 2>/dev/null; then
        sed -i '/=== bindfilter/d; /include.*blocked_acl/d; /include.*blocked_domain_acl/d' "$BIND_INJECT"
        log_info "Include removido de ${BIND_INJECT}"
    fi
    # Também limpa do BIND_CONFIG se differ
    if [[ "$BIND_CONFIG" != "$BIND_INJECT" ]] && grep -qF "bindfilter" "$BIND_CONFIG" 2>/dev/null; then
        sed -i '/=== bindfilter/d; /include.*blocked_acl/d; /include.*blocked_domain_acl/d' "$BIND_CONFIG"
    fi

    [[ -f "$ACL_CONFIG_FILE" ]] && { rm -f "$ACL_CONFIG_FILE"; log_info "Removido: ${ACL_CONFIG_FILE}"; }
    [[ -f "$BLOCKED_ZONE_FILE" ]] && { rm -f "$BLOCKED_ZONE_FILE"; log_info "Removido: ${BLOCKED_ZONE_FILE}"; }

    reload_service
    log_info "Desinstalação concluída."
}

# ==============================================================================
# BANNER
# ==============================================================================
print_banner() {
    echo -e "${C_BOLD}"
    echo " ______ __           __ _______ __ __ __              "
    echo "|   __ \__|.-----.--|  |    ___|__|  |  |_.-----.----."
    echo "|   __ <  ||     |  _  |    ___|  |  |   _|  -__|   _|"
    echo "|______/__||__|__|_____|___|   |__|__|____|_____|__|  "
    echo -e "${C_RESET}"
    echo -e "  ${C_CYAN}DNS Sinkhole para BIND9/Named — v${VERSION}${C_RESET}"
    echo -e "  ${C_RESET}cPanel · HestiaPanel · DirectAdmin · Debian · RHEL${C_RESET}"
    echo
}

# ==============================================================================
# PARSE ARGUMENTOS
# ==============================================================================
ACTION=""
ACTION_TARGET=""
ACTION_DOMAIN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--run)       ACTION="run"; shift ;;
        -u|--update)
            ACTION="update"
            if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
                ACTION_TARGET="$2"; shift
            else
                ACTION_TARGET="all"
            fi
            shift ;;
        --add)
            ACTION="add"
            ACTION_DOMAIN="${2:-}"; shift 2 ;;
        --remove)
            ACTION="remove"
            ACTION_DOMAIN="${2:-}"; shift 2 ;;
        -c|--check)     ACTION="check"; shift ;;
        --stats)        ACTION="stats"; shift ;;
        --uninstall)    ACTION="uninstall"; shift ;;
        -n|--dry-run)   DRY_RUN=true; shift ;;
        -v|--verbose)   VERBOSE=true; shift ;;
        --no-color)     USE_COLOR=false; shift ;;
        --no-restart)   NO_RESTART=true; shift ;;
        -h|--help)      setup_colors; usage ;;
        *)
            log_err "Opção desconhecida: $1"
            echo "Use -h para ver as opções disponíveis."
            exit 1 ;;
    esac
done

# ==============================================================================
# ENTRYPOINT
# ==============================================================================
setup_colors
print_banner

[[ "$DRY_RUN" = true ]] && log_warn "Modo DRY-RUN ativo — nenhuma alteração será feita.\n"

check_root
detect_environment

case "$ACTION" in
    run)
        check_dependencies
        download_zone
        download_acl
        configure_bind
        reload_service
        log_info "Instalação completa!"
        ;;
    update)
        check_dependencies
        case "$ACTION_TARGET" in
            all)
                log_warn "Atualizando TODOS os arquivos..."
                download_zone
                download_acl
                ;;
            zone)
                log_warn "Atualizando apenas ZONAS..."
                download_zone
                ;;
            acl)
                log_warn "Atualizando apenas ACL..."
                download_acl
                ;;
            *)
                log_err "Alvo inválido: '$ACTION_TARGET'. Use: all | zone | acl"
                exit 1 ;;
        esac
        reload_service
        log_info "Atualização concluída!"
        ;;
    add)      add_domain "$ACTION_DOMAIN" ;;
    remove)   remove_domain "$ACTION_DOMAIN" ;;
    check)    run_check ;;
    stats)    run_stats ;;
    uninstall) run_uninstall ;;
    "")
        usage
        ;;
    *)
        log_err "Ação desconhecida: $ACTION"
        exit 1 ;;
esac
