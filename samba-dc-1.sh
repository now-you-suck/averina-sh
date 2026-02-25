#!/bin/sh
echo "nameserver 77.88.8.8" > /etc/resolv.conf

apt-get update && apt-get install -y task-samba-dc bind bind-utils

control bind-chroot disabled

echo 'KRB5RCACHETYPE="none"' >> /etc/sysconfig/bind

echo 'include "/var/lib/samba/bind-dns/named.conf";' >> /etc/bind/named.conf

cat << EOF
Отредактируйте файл /etc/bind/options.conf:

    в раздел options добавьте строки:
        tkey-gssapi-keytab - путь к ключевой таблице для GSS-API (интеграция с Kerberos);
        minimal-responses — уменьшает объём ответов;
        listen-on — IP-адреса, на которых принимаются запросы;
        allow-query — разрешённые подсети для DNS-запросов;
        allow-recursion — подсети, которым разрешены рекурсивные запросы;
        forwarders — внешние DNS-серверы для пересылки;;
        forward first — сначала пересылать, затем кешировать;
EOF
