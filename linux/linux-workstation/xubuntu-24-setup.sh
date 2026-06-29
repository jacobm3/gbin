#!/bin/bash
#
# xubuntu-24-setup.sh
#
# WHAT THIS DOES:
#   Bootstraps a fresh Xubuntu 24.04 desktop to the owner's preferred state:
#     - Installs apt repository signing keys for Docker and Signal.
#     - Restores saved themes/desktop settings from a backup tarball.
#     - Adds extra apt source lists, installs "nala" (a friendlier apt front-end),
#       then installs a batch of CLI/utility packages.
#     - Adds Google's apt repo and installs Google Chrome.
#
# HOW TO RUN:
#   ./xubuntu-24-setup.sh
#   Must be run from THIS directory (it uses relative paths like ../keyrings and
#   sources.list.d/*). Prompts for sudo password.
#
# PREREQUISITES:
#   - Xubuntu/Ubuntu 24.04 with internet access.
#   - The sibling ../keyrings/ folder, a local sources.list.d/ folder, and the
#     _xubuntu-desktop-backup-*.tar.gz backup must exist next to this script.

# "set -x" turns on command tracing: bash prints each command (after expansion)
# before running it, so you can watch exactly what the script does. Useful for a
# setup script you may need to debug.
set -x

# repo signing keys
# APT verifies downloaded packages against these GPG keys. We copy them into the
# system keyring locations so the Docker and Signal repos are trusted.
# "-v" prints each file copied (verbose), "-f" overwrites without prompting.
sudo cp -vf  ../keyrings/docker.asc /etc/apt/keyrings/docker.asc
sudo cp -vf  ../keyrings/signal-desktop-keyring.gpg /usr/share/keyrings/signal-desktop-keyring.gpg


# themes & desktop settings
# Unpack a previously-saved backup of desktop themes/config into the home dir.
# "tar zxf": z = gzip-compressed, x = extract, f = from this file; "-C ~"
# extracts relative to the home directory.
tar zxf _xubuntu-desktop-backup-20251018.tar.gz -C ~

# Drop in the extra apt source list files (the repos we want enabled), then
# refresh apt's package index so it sees them.
sudo cp -f sources.list.d/* /etc/apt/sources.list.d
sudo apt update
# Install nala, a nicer/faster front-end for apt used for the installs below.
sudo apt install -y nala

# Install a batch of command-line and utility packages in one shot.
# "-y" auto-answers yes to prompts. The trailing backslashes join all the
# package names below into one long command, one package per line for clarity.
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
scrub \
signal-desktop \
smartmontools \
unzip \
vim \
wget \
zip \
zstd \


# install chrome
# Remove any pre-existing Chrome repo file and key first, so re-running this
# script doesn't create duplicates or stale entries. "-f" = don't error if missing.
sudo rm -f /etc/apt/sources.list.d/google-chrome.list /etc/apt/keyrings/google-chrome.gpg
# Download Google's signing key and convert it from text (ASCII-armored) to the
# binary keyring format apt expects. "wget -qO-" downloads quietly to stdout,
# the pipe feeds it to "gpg --dearmor", and "-o" writes the binary key out.
wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
# Write the Chrome apt source line into its own list file.
#   arch=$(dpkg --print-architecture)  -> matches this machine's CPU arch (e.g. amd64)
#   signed-by=...                       -> only trust packages signed by the key above
# "tee" writes the line to the root-owned file via sudo (echo alone can't).
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
# Refresh apt now that the Chrome repo is configured, then install Chrome.
sudo apt update
sudo nala install -y google-chrome-stable

