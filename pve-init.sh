#!/bin/bash -x

# curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/pve-init.sh | bash 

cat > /root/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID10aN8gGb0s+3LTE43VNFmvQxz5WYL+JlMCVzmZl+f7 jacob.martinson.ed25519.2022.09
EOF


rm /etc/apt/sources.list.d/*
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list

apt-get update
apt install -y 7zip btop git htop lm-sensors netdiscover nmap vim zip unzip 

git clone https://github.com/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc

apt-get upgrade -y

cat >> /etc/network/interfaces <<EOF

auto vmbr1
iface vmbr1 inet static
        address 10.0.1.254/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

EOF

sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 
systemctl restart pveproxy.service