#!/bin/bash
#

# stop on errors
set -e

ts=`date +%Y.%m.%d-%H.%M.%S`


# backup existing resolv.conf content, just in case
sudo cp /etc/resolv.conf /etc/resolv.conf.${ts}

# remove resolv.conf symlink to systemd
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null


# back up the systemd resolved.conf
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.${ts}

# set localhost resolver and disable the listening stub, so it doesn't conflict with pihole
sudo tee /etc/systemd/resolved.conf > /dev/null <<'EOF'
[Resolve]
DNS=127.0.0.1
#FallbackDNS=
#Domains=
#LLMNR=yes
#MulticastDNS=yes
#DNSSEC=no
#DNSOverTLS=no
#Cache=yes
DNSStubListener=no
#ReadEtcHosts=yes
EOF


# or docker-compose up -d
# depending no your system
docker compose up -d

sudo cp etc_NetworkManager_dispatcher.d_99-update-pihole-dns /etc/NetworkManager/dispatcher.d/99-update-pihole-dns
sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-update-pihole-dns

sudo chmod 755 update-pihole-dns.py
sudo cp update-pihole-dns.py /usr/local/bin

sudo chmod 755 setup-lists.sh
./setup-lists.sh



