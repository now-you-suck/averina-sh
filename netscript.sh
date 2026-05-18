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

ospf_setup() {
    echo_info "Выбрана настройка OSPF (FRR)"

    # Проверка FRR
    if ! rpm -q frr >/dev/null 2>&1; then
        echo_warn "FRR не установлен"
        read -p "Установить FRR?[Y/n]: " install_frr

        if [[ ! "$install_frr" =~ ^[NnтТ]$ ]]; then
            apt-get update
            apt-get install -y frr frr-pythontools
        else
            echo_error "FRR необходим для OSPF"
            return 1
        fi
    fi

    # Получение интерфейсов
    local if_list=($(get_interfaces_list))

    declare -A iface_costs

    echo_info "Настройка OSPF cost"

    while true; do
        echo
        echo "Доступные интерфейсы:"

        for i in "${!if_list[@]}"; do
            iface="${if_list[$i]}"

            if [[ "$iface" == "lo" ]]; then
                continue
            fi

            current_cost="${iface_costs[$iface]}"
            [[ -z "$current_cost" ]] && current_cost="не задан"

            echo "$i) $iface (cost: $current_cost)"
        done

        echo "999) Завершить настройку cost"

        read -p "Выберите интерфейс: " iface_choice

        if [[ "$iface_choice" == "999" ]]; then
            break
        fi

        selected_iface="${if_list[$iface_choice]}"

        if [[ -z "$selected_iface" ]]; then
            echo_error "Неверный интерфейс"
            continue
        fi

        read -p "Введите cost для $selected_iface: " cost_value

        if ! [[ "$cost_value" =~ ^[0-9]+$ ]]; then
            echo_error "Cost должен быть числом"
            continue
        fi

        iface_costs["$selected_iface"]="$cost_value"

        echo_info "Для $selected_iface установлен cost=$cost_value"
    done

    # Установка default cost
    for iface in "${if_list[@]}"; do
        [[ "$iface" == "lo" ]] && continue

        if [[ -z "${iface_costs[$iface]}" ]]; then
            iface_costs["$iface"]=100
        fi
    done

    echo
    echo_info "Итоговая конфигурация OSPF cost"
    echo "-------------------------------------"

    for iface in "${if_list[@]}"; do
        [[ "$iface" == "lo" ]] && continue
        printf "%-15s cost=%s\n" "$iface" "${iface_costs[$iface]}"
    done

    echo "-------------------------------------"

    read -p "Подтвердить настройки?[y/N]: " confirm

    if [[ ! "$confirm" =~ ^[YyнН]$ ]]; then
        echo_warn "Настройка OSPF отменена"
        return
    fi

    echo_info "Включение ospfd"

    sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

    mkdir -p /etc/frr

    cat > /etc/frr/frr.conf << EOF
frr defaults traditional
hostname ospf-router
service integrated-vtysh-config

router ospf
EOF

    # Автоматически добавляем сети интерфейсов в area 0
    for iface in "${if_list[@]}"; do
        [[ "$iface" == "lo" ]] && continue

        network=$(ip -4 addr show "$iface" | grep inet | awk '{print $2}')

        if [[ -n "$network" ]]; then
            echo " network $network area 0.0.0.0" >> /etc/frr/frr.conf
        fi
    done

    echo >> /etc/frr/frr.conf

    # interface cost
    for iface in "${if_list[@]}"; do
        [[ "$iface" == "lo" ]] && continue

        cat >> /etc/frr/frr.conf << EOF
interface $iface
 ip ospf cost ${iface_costs[$iface]}

EOF
    done

    chown frr:frr /etc/frr/frr.conf
    chmod 640 /etc/frr/frr.conf

    systemctl enable frr
    systemctl restart frr

    echo_info "OSPF успешно настроен"
}


#Функция настройки dns
dns_setup(){
    default_dns="8.8.8.8"
#    dns_nameserver="0"
    echo_info "Выбрана насройка dns"
    read -p "Введить dns nameserver [По умолчанию 8.8.8.8]: " dns_nameserver
    if [[ -z "$dns_nameserver" ]]; then
	dns_nameserver="$default_dns"
    fi
    read -p "Перезаписать существующие nameservers?[y/N]" way
    if [[ "$way" =~ ^[YyнН]$ ]]; then
	echo "nameserver $dns_nameserver" > /etc/resolv.conf
    else
	echo "nameserver $dns_nameserver" >> /etc/resolv.conf
    fi
    echo_info "Настройка завершена. DNS $dns_nameserver успешно добавлен."
}
#Функция получения текущих сетевых параметров
get_network_info(){
    echo_info "Получение информаций о сети"
    sum_int="0"
    #получаем список интерфесов
    ip -o link show | grep -v 'lo:' | while read line; 
    do
	sum_int=$((sum_int += 1))
	#if_num=$(echo "$line" | awk -F': ' '{print $1}')
	#num_int=$(sum_int=$((sum_int + 1)); echo "$sum_int")
	if_name=$(echo "$line" | awk -F': ' '{print $2}')
	mac_addr=$(ip link show "$if_name" | grep -o 'link/ether [^ ]*' | awk '{print $2}')
	ip_addr=$(ip address show $if_name | grep -o 'inet [^ ]*' | awk '{print $2}')
	#echo "$num_int"
	printf "%s: %s (%s) - %s\n" "$sum_int" "$if_name" "$mac_addr" "$ip_addr"
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
#Функция получения MAC из имени
get_mac_for_interface(){
    local iface="$1"
    ip link show "$iface" 2>/dev/null | grep -o 'link/ether [^ ]*' | awk '{print $2}'
}

#Функция применения настроек
apply_network_config() {
    echo_info "Применение сетевых настроек..."
    systemctl restart network
}
#Функция настройка nat
nat_setup(){
    echo_info "Выбрана настройка nat"
    get_network_info
    read -p "Введите номер output интерфейса(WAN интерфейс): " wan_interface
    local if_list=($(get_interfaces_list))
    interface=${if_list[$wan_interface]}
    echo $interface
    iptables -t nat -A POSTROUTING -o $interface -j MASQUERADE
    iptables-save > /etc/rules.v4
    
    if grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
		echo "da" >> /dev/null
    else
		echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi
    sysctl -p
    echo "@reboot /sbin/iptables-resore < /etc/rules.v4" | crontab -
}
#Функция настройки DHCP у интерфейсов
DHCP_setting(){
    echo_info "Выбрана настройка через DHCP"
    echo "Выберите интерфейс"
    local if_list=($(get_interfaces_list)) 
    get_network_info
    read -p "Введите номер интерфейса: " num_interface
    interface=${if_list[$num_interface]}
    #echo "$interface"
    if [ -d "/etc/net/ifaces/$interface" ]; then
	echo "Папка есть" >> /dev/null
    else
	mkdir /etc/net/ifaces/$interface
    fi
    cat > /etc/net/ifaces/$interface/options << EOF
TYPE=eth
ONBOOT=yes
DISABLED=no
BOOTPROTO=dhcp
EOF
    #chmod 644 /etc/net/ifaces/$interface/options
    echo_info "Конфигурация DHCP у $interface создана"
    apply_network_config
}
#Функция настройки STATIC у интерфейсов
STATIC_setting(){
    gate="0"
    echo_info "Выбрана настройка через static"
    echo "Выберите интерфейс"
    local if_list=($(get_interfaces_list))
    get_network_info
    read -p "Введите номер интерфейса: " num_interface
    interface=${if_list[$num_interface]}
    echo_info "Начало настройки $interface"
    read -p "Введите ip/префикс (к примеру 192.168.0.10/24): " ip_address
    read -p "Необходим ли шлюз по умолчанию?[y/N]: " need_gate
    if [[ "$need_gate" =~ ^[YyнН]$ ]]; then
	read -p "Введите шлюз по умолчанию(к примеру 192.168.0.1): " gate
    fi
    echo_info "Будут применены следующие настройки:"
    echo "-----------------------------------------"
    echo "Интерфейс:	$interface ($(get_mac_for_interface "$interface"))"
    echo "IP-адрес/маска:	$ip_address"
    if [ "$gate" != "0" ]; then
	echo "Шлюз:		$gate"
    fi
    echo "-----------------------------------------"
    read -p "Применить настройки?[y/N]: " confirm
    echo_info "Настройка $interface"
    if [[ "$confirm" =~ ^[YyнН]$ ]]; then
	if [ -d "/etc/net/ifaces/$interface" ]; then
	    echo "Папка есть" >> /dev/null
	else
	    mkdir /etc/net/ifaces/$interface
	fi
	cat > /etc/net/ifaces/$interface/options << EOF
TYPE=eth
ONBOOT=yes
DISABLED=no
BOOTPROTO=static
EOF
	cat > /etc/net/ifaces/$interface/ipv4address << EOF 
$ip_address 
EOF
	if [ "$gate" != "0" ]; then
	    cat > /etc/net/ifaces/$interface/ipv4route << EOF 
default via $gate 
EOF
	fi
	echo_info "Конфигурация STATIC у $interface создана"
	apply_network_config
    else
	echo_info "Настройка $interface отменена"
    fi
    
}


# Функция настройки WAN интнрфейса
setup_interface(){
    echo_info "Выберите способ насройки:"
    read -p "Настройть через DHCP[y/N]: " way
    if [[ "$way" =~ ^[YyнН]$ ]]; then
	DHCP_setting
    else
#	echo "Выбрана настройка через static"
	STATIC_setting
    fi
}
bond_setup(){
    echo_info "Выбрана настройка агрегирования каналов (bonding)"

    local if_list=($(get_interfaces_list))
    get_network_info

    read -p "Введите номера интерфейсов для агрегации (через пробел): " bond_indexes

    bond_ifaces=()
    for idx in $bond_indexes; do
        bond_ifaces+=("${if_list[$idx]}")
    done

    if [ ${#bond_ifaces[@]} -lt 2 ]; then
        echo_error "Нужно минимум 2 интерфейса"
        return 1
    fi

    read -p "Введите режим bonding (0=balance-rr, 1=active-backup, 4=802.3ad) [по умолчанию 1]: " bond_mode
    bond_mode=${bond_mode:-1}

    bond_name="bond0"

    mkdir -p /etc/net/ifaces/$bond_name

    echo_info "Создание bond интерфейса $bond_name"

    cat > /etc/net/ifaces/$bond_name/options << EOF
TYPE=bond
BOOTPROTO=static
HOST="${bond_ifaces[*]}"
BONDMODE=$bond_mode
BONDOPTIONS="miimon=100"
EOF

    for iface in "${bond_ifaces[@]}"; do
        mkdir -p /etc/net/ifaces/$iface

        cat > /etc/net/ifaces/$iface/options << EOF
TYPE=eth
BOOTPROTO=static
EOF
    done

    echo_info "Bond интерфейс $bond_name создан (${bond_ifaces[*]})"
    apply_network_config
}
switch_setup(){
    echo_info "Выбрана настройка коммутатора"

    read -p "Настроить устройство как коммутатор?[y/N]: " way
    if [[ ! "$way" =~ ^[YyнН]$ ]]; then
        echo_info "Настройка коммутатора прервана"
        return
    fi

    local if_list=($(get_interfaces_list))
    bridge_ifaces=()

    for int in "${if_list[@]:1}"; do
        # пропускаем bond интерфейсы
        if [[ "$int" =~ bond ]]; then
            continue
        fi
        mkdir -p /etc/net/ifaces/$int

        cat > /etc/net/ifaces/$int/options << EOF
TYPE=eth
ONBOOT=yes
BOOTPROTO=none
EOF
    done

    mkdir -p /etc/net/ifaces/br0

    cat > /etc/net/ifaces/br0/options << EOF
TYPE=bri
ONBOOT=yes
BOOTPROTO=static
HOST='${bridge_ifaces[*]}'
EOF

    if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    fi

    sysctl -p
    apply_network_config

    echo_info "Коммутатор настроен (br0: ${bridge_ifaces[*]})"
}
main() {
    echo "Скрипт настройки сети etcnet"
    #get_network_info
    
    #echo "Выберите действие:"
    while true; do 
	echo "Выберите действие:"
	echo "1) Настройка интерфейсов"
	echo "2) Добавление dns"
	echo "3) Настройка nat"
	echo "4) Настройка коммутатора"
	echo "5) Настройка агрегирования"
	echo "6) Настройка OSPF"
    echo "7) Выход"
	read -p "Ваш выбор [1-6]: " choice
	case $choice in
	    1)
		setup_interface
		;;
	    2)
		dns_setup
		;;
	    3)
		nat_setup
		;;
		4) 
		switch_setup
		;;
		5)
		bond_setup
		;;
		6)
   		ospf_setup
    	;;
		7)
    	echo_info "Выход"
    	exit 0
    	;;
	    *)
		echo_error "Неверный выбор. Завершение работы скрипта."
		exit 1
	        ;;
	esac
    done
}
main "$@"
