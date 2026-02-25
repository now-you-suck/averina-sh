#!/bin/sh
rm -f /etc/samba/smb.conf
rm -f /etc/samba/smb.conf
rm -rf /var/cache/samba
mkdir -p /var/lib/samba/sysvol
samba-tool domain provision