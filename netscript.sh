#!/bin/bash
#Скрипт для настройки сети на alt 10.4 (в итоге должны быть настроены интнрфейсы, интернет на машине, dns) 
#На олимпеаде можно будет подтянуть cd-disk со скриптами и от туда запускать.

#Взять имена интерфесов из ip a
#Спрашиваем на каком порте интернет
#Спрашиваем ip-address/mask
#Спрашиваем ip-address шлюза

set -e

#Форматированный вывод
GREEN='\033[0;32m'
YELLOW='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No color(end colorful)

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
#echo_error "ERROR!!!"

#мб сделать проверку на роот

#Функция получения текущих сетевых параметров
get_network_info(){
    echo_info "Получение информаций о сети"
    #получаем список интерфесов
    ip -o link show | grep -v 'lo:' | while read line; 
    do
	if_num=$(echo "$line" | awk -F': ' '{print $1}')
	if_name=$(echo "$line" | awk -F': ' '{print $2}')
	mac_addr=$(ip link show "$if_name" | grep -o 'link/ether [^ ]*' | awk '{print $2}')
	
	printf "%s: %s - %s\n" "$(( $if_num - 1 ))" "$if_name" "$mac_addr"
    done
}
#Функция получения списка интерфейсов
get_interfaces_list() {
    local if_list=()
    
    while read line; do
	if_name=$(echo "$line" | awk -F': ' '{print $2}')
	if_list+=("$if_name")
    done < <(ip -o link show)
    
    echo "${if_list[@]}"
}
#Функция применения настроек
apply_network_config() {
    echo_info "Применение сетевых настроек..."
    systemctl restart network
}


#Функция настройки DHCP у интерфейсов
DHCP_setting(){
    echo_info "Выбрана настройка через DHCP"
    echo "Выберите интерфейс"
    local if_list=($(get_interfaces_list)) 
    get_network_info
    read -p "Введите номер интерфейса: " num_interface
    interface=${if_list[$num_interface]}
    echo "$interface"
    if [ -d "/etc/net/ifaces/$interface" ]; then
	echo "idi naxui" >> /dev/null
    else
	mkdir /etc/net/ifaces/$interface
    fi
    cat > /etc/net/ifaces/$interface/options << EOF
TYPE=eth
ONBOOT=yes
DISABLED=no
BOOTPROTO=DHCP
EOF
    #chmod 644 /etc/net/ifaces/$interface/options
    echo_info "Конфигурация DHCP у $interface создана"
    apply_network_config
}


# Функция настройки WAN интнрфейса
setup_interface(){
    echo_info "Выберите способ насройки:"
    read -p "Настройть через DHCP[y/N]: " way
    if [[ "$way" =~ ^[YyнН]$ ]]; then
	DHCP_setting
    else
	echo "Выбрана настройка через static"
    fi
}


main() {
    echo "Скрипт настройки сети etcnet"
    
    #get_network_info
    
    #echo "Выберите действие:" 
    echo "Выберите действие:"
    echo "1) Настройка интерфейсов"
    echo "2) Добавление dns"
    echo "3) Настройка nat"
    echo "4) Выход"
    read -p "Ваш выбор [1-4]: " choice
    case $choice in
	1)
	    setup_interface
	    ;;
	4) 
	    echo_info "Выход"
	    exit 0
	    ;;
	*)
	    echo_error "Неверный выбор. Завершение работы скрипта."
	    exit 1
	    ;;
    esac
}
main 