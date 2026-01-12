mkdir /etc/net/ifaces/br0

intNames=("ens19" "ens20" "ens21" "ens22")

for int in "${intNames[@]}"
do
    mkdir /etc/net/ifaces/$int
    cat > /etc/net/ifaces/$int/options << EOF
TYPE=eth
ONBOOT=yes
DISABLED=no
BOOTPROTO=static
EOF

done



cat > /etc/net/ifaces/br0/options << EOF
TYPE=bri
HOST='ens19 ens20 ens21 ens22'

EOF

systemctl restart network
