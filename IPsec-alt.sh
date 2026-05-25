#!/bin/bash
apt-get update && apt-get install NetworkManager-strongswan strongswan strongswan-charon-nm strongswan-testing
cp /home/user/Загрузки/root-ca.crt /etc/pki/ca-trust/source/anchors/ && update-ca-trust
CERT_PATH="/etc/pki/ca-trust/source/anchors/root-ca.crt"

nmcli connection add \
  type vpn \
  vpn-type strongswan \
  con-name "vpn" \
  ifname "ens18" \
  vpn.data "address = 10.0.0.1, encap = no, esp = aes256-sha256-modp2048, ike = aes256-sha256-modp2048, ipcomp = no, method = eap, password-flags = 2, proposal = yes, user = Adminstrator, virtual = yes"
            
nmcli connection up "vpn" --ask
