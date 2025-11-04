#!/bin/bash
#

# stop on errors
set -e

ts=`date +%Y.%m.%d-%H.%M.%S`


# backup existing resolv.conf content, just in case
sudo cp /etc/resolv.conf /etc/resolv.conf.${ts}

# remove resolv.conf symlink to systemd
sudo rm /etc/resolv.conf
echo "nameserver 9.9.9.9" | sudo tee /etc/resolv.conf > /dev/null


# back up the systemd resolved.conf
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.${ts}

# set localhost resolver and disable the listening stub, so it doesn't conflict with pihole
sudo tee /etc/systemd/resolved.conf > /dev/null <<'EOF'
[Resolve]
DNS=127.0.0.1
FallbackDNS=9.9.9.9
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

# Check if sqlite3 is installed
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 not found. Installing..."
    # Refresh package index if needed
    sudo apt-get update -y
    # Install the package
    sudo apt-get install -y sqlite3
    echo "sqlite3 installed successfully."
else
    echo "sqlite3 is already installed (version: $(sqlite3 --version))."
fi

./setup-lists.sh


