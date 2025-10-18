#!/bin/bash

set -x

# repo signing keys
sudo cp -vf  ../keyrings/docker.asc /etc/apt/keyrings/docker.asc
sudo cp -vf  ../keyrings/signal-desktop-keyring.gpg /usr/share/keyrings/signal-desktop-keyring.gpg


# themes & desktop settings
tar zxf _xubuntu-desktop-backup-20251018.tar.gz -C ~

sudo cp -f sources.list.d/* /etc/apt/sources.list.d
sudo apt update
sudo apt install -y nala

sudo nala install -y \
7zip \
apt-transport-https \
btop \
bzip2 \
curl \
fio \
git \
htop \
jq \
lm-sensors \
lshw \
lsof \
ncdu \
nmap \
pciutils \
pwgen \
rclone \
restic \
signal-desktop \
smartmontools \
unzip \
vim \
wget \
zip \
zstd \


# install chrome
sudo rm -f /etc/apt/sources.list.d/google-chrome.list /etc/apt/keyrings/google-chrome.gpg
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo nala install -y google-chrome-stable

