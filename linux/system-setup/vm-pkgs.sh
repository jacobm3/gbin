#!/bin/bash
#
# vm-pkgs.sh — install the baseline package set on a general-purpose VM.
# Like live-setup.sh but tuned for a working VM (adds cloud CLIs and networking
# tools), and it does NOT touch SSH keys, dotfiles, or htop config.
#
# HOW TO RUN (it sudo's the steps that need root):
#   ~/gbin/linux/system-setup/vm-pkgs.sh
# The commented block below is the one-time bootstrap you paste on a brand-new
# box to get curl/git/sudo and passwordless sudo for user `j` before any of the
# gbin scripts exist locally.
# RISK: upgrades all packages and installs the list below; fine on a fresh VM.

#
# export DEBIAN_FRONTEND=noninteractive; apt-get update && apt install -y curl git sudo
# usermod -G sudo -a j; echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
# curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/system-setup/live-setup.sh | bash
#

# Keep apt non-interactive, refresh package lists, then upgrade what's installed.
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get upgrade -y
# Install the baseline toolset. -y auto-confirms; the trailing backslashes join
# these lines into one command. Notables beyond the usual CLI tools:
#   awscli / azure-cli - cloud provider command-line tools
#   dnsutils (dig) / whois / sipcalc - DNS, registration, and subnet math
#   netdiscover / nmap / net-tools   - network discovery & legacy net commands
#   nvme-cli / smartmontools         - disk health;  nwipe - secure wipe
#   hwinfo / lm-sensors              - hardware + temperature info
#   unison - bidirectional file sync;  vim-nox - vim with scripting;  zstd - compression
sudo apt install -y 7zip awscli azure-cli bash-completion btop cloud-guest-utils curl dnsutils git htop \
	hwinfo jq lm-sensors net-tools netdiscover nmap nvme-cli nwipe python3-pip \
	rsync sipcalc smartmontools sudo sysstat unison unzip vim-nox \
	whois zip zlib1g-dev zstd 

