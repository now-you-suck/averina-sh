#!/bin/bash
apt-get update && apt-get install -y postgresql17-server zabbix-server-pgsql fping apache2 apache2-mod_php8.2 php8.2 php8.2-mbstring php8.2-sockets php8.2-gd php8.2-xmlreader php8.2-pgsql php8.2-ldap php8.2-openssl zabbix-phpfrontend-apache2 zabbix-phpfrontend-php8.2

systemctl enable --now httpd2

/etc/init.d/postgresql initdb

systemctl enable --now postgresql

su - postgres -s /bin/sh -c 'createuser --no-superuser --no-createdb --no-createrole --encrypted --pwprompt zabbix'

su - postgres -s /bin/sh -c 'createdb -O zabbix zabbix'

ver=$(rpm -ql zabbix-common-database-pgsql | grep schema.sql | awk -F '-' '{print $5}' | awk -F '/' '{print $1}' | awk -F '\n' '{print $1}' | tail -n 1)

su - postgres -s /bin/sh -c "psql -U zabbix -f /usr/share/doc/zabbix-common-database-pgsql-$ver/schema.sql zabbix"
su - postgres -s /bin/sh -c "psql -U zabbix -f /usr/share/doc/zabbix-common-database-pgsql-$ver/images.sql zabbix"
su - postgres -s /bin/sh -c "psql -U zabbix -f /usr/share/doc/zabbix-common-database-pgsql-$ver/data.sql zabbix"

cp /etc/php/8.2/apache2-mod_php/php.ini /etc/php/8.2/apache2-mod_php/php.ini.orig

cat << EOF > /etc/php/8.2/apache2-mod_php/php.ini
[PHP]
memory_limit = 256M
post_max_size = 32M
max_execution_time = 600
max_input_time = 600
date.timezone = Europe/Moscow
always_populate_raw_post_data = -1
EOF

systemctl enable --now httpd2

cat << EOF > /etc/zabbix/zabbix_server.conf
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=P@ssw0rd
LogFile=/var/log/zabbix.log
EOF

chmod 557 /var/log

systemctl enable --now zabbix_pgsql

ln -s /etc/httpd2/conf/addon.d/A.zabbix.conf /etc/httpd2/conf/extra-enabled/

systemctl restart httpd2

chown apache2:apache2 /var/www/webapps/zabbix/ui/conf
