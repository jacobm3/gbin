#!/bin/bash
#
# live-setup.sh — first-boot setup for a freshly-installed / live Ubuntu box.
# Installs your SSH key, updates the system, installs a baseline toolset, clones
# gbin, and wires up the shell + htop config.
#
# HOW TO RUN (the commented block below is the bootstrap you paste on a brand-new
# machine BEFORE this script exists locally — it installs curl/git/sudo, grants
# user `j` passwordless sudo, then pipes this script straight from GitHub into bash):
#   export DEBIAN_FRONTEND=noninteractive; apt-get update && apt install -y curl git sudo
#   usermod -G sudo -a j; echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
#   curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/system-setup/live-setup.sh | bash
#
# RISK: upgrades all packages and overwrites ~/.ssh/authorized_keys with the one
# key below. Run only on a machine you intend to fully (re)provision.

# Make sure ~/.ssh exists (mkdir -p is a no-op if it already does).
mkdir -p ~/.ssh
# Write the authorized_keys file so we can SSH in with the key below.
# NOTE: `>` overwrites — this REPLACES any existing authorized_keys.
cat > ~/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID10aN8gGb0s+3LTE43VNFmvQxz5WYL+JlMCVzmZl+f7 jacob.martinson.ed25519.2022.09
EOF

# Don't let apt/dpkg ask interactive config questions during the unattended run.
export DEBIAN_FRONTEND=noninteractive
# Refresh package lists, then upgrade everything already installed.
sudo apt-get update
sudo apt-get upgrade -y
# Install the baseline toolset for a live/recovery box. Notables:
#   cloud-guest-utils (growpart), hwinfo/lm-sensors (hardware), netdiscover/nmap
#   (network discovery), nvme-cli/smartmontools (disk health), nwipe (secure
#   wipe), unison (file sync), vim-nox (vim w/ scripting), zstd (compression).
sudo apt install -y 7zip bash-completion btop cloud-guest-utils curl git htop hwinfo lm-sensors net-tools netdiscover nmap nvme-cli nwipe python3-pip rsync smartmontools sudo sysstat unison unzip vim-nox zip zlib1g-dev zstd 

# (Optional extras left disabled — uncomment if this box needs ZFS tools.)
# unset DEBIAN_FRONTEND
# sudo apt install -y zfsutils-linux

# https://github.com/louwrentius/fio-plot
#pip3 install fio-plot

# Clone your dotfiles/scripts repo and wire up the shell:
#   - clone gbin into ~/gbin
#   - source ~/gbin/jacobrc from both interactive (.bashrc) and login
#     (.bash_profile) shells so your aliases/functions are always loaded
#   - symlink ~/.jacobrc -> the repo copy so references to ~/.jacobrc work too
# The && chain stops if the clone fails (no point editing rc files then).
git clone https://github.com/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc

# Install the htop config from the repo so htop looks right immediately.
mkdir -p ~/.config/htop
cp ~/gbin/.config/htop/htoprc ~/.config/htop/htoprc


