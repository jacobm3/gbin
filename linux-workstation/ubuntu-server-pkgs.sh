#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
7zip \
apt-transport-https \
btop \
bzip2 \
curl \
fio \
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
smartmontools \
unzip \
vim \
wget \
zip \
zstd

