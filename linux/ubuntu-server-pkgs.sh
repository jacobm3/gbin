#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get full-upgrade -y
apt-get install -y \
7zip \
apt-transport-https \
btop \
bzip2 \
curl \
fio \
gh \
htop \
jq \
lm-sensors \
lshw \
lsof \
nala \
ncdu \
nmap \
pciutils \
pwgen \
rclone \
restic \
ripgrep \
scrub \
smartmontools \
ugrep \
unzip \
vim \
wget \
zip \
zstd

