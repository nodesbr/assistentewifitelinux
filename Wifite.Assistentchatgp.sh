#!/usr/bin/env bash
# ------------------------------------------------------------------------ #
# Script Name:   Wifite.Assistentchatgp.sh 
# Description:   Asssitente do Wifite.
# Written by :   Nilson NodesBr
# Maintenance:   Nilson NodesBr
# CoCredits  :   ChatGPT4o mini
# ------------------------------------------------------------------------ #
# Usage:         
#       $ sudo ./chatgpt004-melhorias.sh
# ------------------------------------------------------------------------ #
# Bash Version:  
#              Bash 4.4.19
# ------------------------------------------------------------------------ #

# Verifica se o script está sendo executado com privilégios de superusuário
if [[ $EUID -ne 0 ]]; then
        echo " "
   echo -e " Este script precisa ser executado como \033[31mROOT\033[0m."
        echo " "
   sudo ./Wifite.Assistentchatgp.sh
fi

check_commands() {
    # Verifica múltiplos comandos de uma vez
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "$cmd não está instalado. Por favor, instale-o e tente novamente."; exit 1; }
    done
}

get_active_interface() {
    # Obtém a primeira interface ativa do iwconfig sem usar -P do grep
    iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}'
}

function start_network_manager() {
    sudo service NetworkManager start && echo "NetworkManager iniciado com sucesso." || echo "Falha ao iniciar NetworkManager. Verifique se o serviço está instalado corretamente."
}

function stop_network_manager() {
    sudo service NetworkManager stop && echo "NetworkManager parado com sucesso." || echo "Falha ao parar NetworkManager. Verifique se o serviço está instalado corretamente."
}

function restart_network_manager() {
    sudo service NetworkManager restart && echo "NetworkManager reiniciado com sucesso." || echo "Falha ao reiniciar NetworkManager. Verifique se o serviço está instalado corretamente."
}

function start_monitor_mode() {
    echo "Aqui estão as interfaces de rede atuais:"
    iwconfig
    INTERFACE_ATIVA=$(get_active_interface)
    if [ -z "$INTERFACE_ATIVA" ]; then
        echo "Nenhuma interface de rede ativa encontrada."
        return
    fi
    echo "Iniciando modo monitor na interface $INTERFACE_ATIVA..."
    sudo airmon-ng start "$INTERFACE_ATIVA" && echo "Modo monitor iniciado na interface $INTERFACE_ATIVA." || echo "Falha ao iniciar o modo monitor na interface $INTERFACE_ATIVA. Verifique se os drivers necessários estão instalados."
}

function stop_monitor_mode() {
    echo "Aqui estão as interfaces de rede atuais:"
    iwconfig
    INTERFACE_ATIVA=$(get_active_interface)
    if [ -z "$INTERFACE_ATIVA" ]; then
        echo "Nenhuma interface de rede ativa encontrada."
        return
    fi
    echo "Parando modo monitor na interface $INTERFACE_ATIVA..."
    sudo airmon-ng stop "$INTERFACE_ATIVA" && echo "Modo monitor parado na interface $INTERFACE_ATIVA." || echo "Falha ao parar o modo monitor na interface $INTERFACE_ATIVA."
}

function show_current_network_interface() {
    interface=$(iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}')
    echo "A interface de rede atual é: $interface"
    read -n 1 -s -r -p "<Enter> para menu principal"
}

#function show_system_ip() {
#    IP_SISTEMA=$(hostname -I)
#    echo "O IP do seu sistema é: $IP_SISTEMA"
#    read -n 1 -s -r -p "<Enter> para menu principal"
#}

select_wifi() {
    interface=$(iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}')
         sudo airmon-ng start $interface
    echo "Digite o MACadress da rede Wi-Fi:"
    read client_mac
    echo "Entre com o canal da rede Wi-Fi:"
    read channel
    echo "Iniciando o monitoramento na rede selecionada..."
    interface=$(iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}')
    sudo airodump-ng --bssid $client_mac --channel $channel $interface
         sudo airmon-ng stop $interface
 read -n 1 -s -r -p "<Enter> para menu principal" 
}

function start_wifite() {
clear
    sudo wifite && echo "Wifite iniciado." || echo "Falha ao iniciar Wifite. Verifique se ele está instalado corretamente."
 interface=$(iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}')
    echo "A interface em modo monitor é: $interface"
    sudo airmon-ng stop $interface
   echo ""
    echo "A interface voltou a ser: $interface"
    read -n 1 -s -r -p "<Enter> para menu principal"
}

scan_wifi() {
    echo "Procurando redes Wi-Fi..."
 interface=$(iwconfig 2>/dev/null | awk '/^[a-z]/ {print $1; exit}')
    echo "A interface em modo monitor é: $interface"
    sudo airodump-ng --band abg $interface
 read -n 1 -s -r -p "<Enter> para menu principal"
}

function menuprincipal() {
    check_commands iwconfig airmon-ng wifite

    while true; do
        clear
        echo " "
        echo "COMMANDS STARTED WIFITE NDS $0"
        echo " "
        echo " Escolha uma opção abaixo para começar!"
        echo " "
# Opções coloridas em vermelho
        echo -e " \033[31m1 - Iniciar\033[0m Wifite\033[0m"
        echo " 2 - Start Modo Monitor"
        echo -e " \033[31m3 - Stop\033[0m Modo Monitor"
        echo " 4 - Iniciar NetworkManager"
        echo -e " \033[31m5 - Parar\033[0m NetworkManager"
        echo " 6 - Reiniciar NetworkManager"
        echo " 7 - Veja a interface de Rede Atual"
# echo " 8 - Verificar IP do sistema"
        echo " 8 - Selecione uma rede Wi-Fi para monitorar"
        echo " 9 - Procure redes Wi-Fi"
        echo -e " \033[31m0 - Sair\033[0m do menu"
        echo " "
        echo -n " Opção escolhida: "
        read -r opcao

        case $opcao in
            1) start_wifite ;;
            2) start_monitor_mode ;;
            3) stop_monitor_mode ;;
            4) start_network_manager ;;
            5) stop_network_manager ;;
            6) restart_network_manager ;;
            7) show_current_network_interface ;;
# 8) show_system_ip ;;
            8) select_wifi ;;
            9) scan_wifi ;;
            0) break ;;
            *) echo "Opção inválida, tente novamente!" ;;
        esac
    done
}

menuprincipal
