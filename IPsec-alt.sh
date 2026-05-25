#!/bin/bash
apt-get update && apt-get install NetworkManager-strongswan strongswan strongswan-charon-nm strongswan-testing
cp /home/user/Загрузки/root-ca.crt /etc/pki/ca-trust/source/anchors/ && update-ca-trust
