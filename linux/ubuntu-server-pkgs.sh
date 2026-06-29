#!/usr/bin/env bash
#
# ubuntu-server-pkgs.sh — bring a fresh Ubuntu/Debian server up to date and
# install the baseline set of command-line tools used on these machines.
#
# HOW TO RUN (needs root, so run as root or via sudo):
#   sudo ~/gbin/linux/ubuntu-server-pkgs.sh
#
# RISK: upgrades EVERY installed package (full-upgrade) and installs the list
# below. On a server this can pull in new kernels / restart services — fine for
# a maintenance window, but don't run it blindly mid-production.

# Exit on the first command that fails, so we don't keep going after a broken
# apt step and pretend everything worked.
set -e

# Tell apt/dpkg not to ask interactive questions (e.g. "keep or replace this
# config file?"). Needed so the script can run unattended without hanging.
export DEBIAN_FRONTEND=noninteractive

# Refresh the list of available packages and their versions from the repos.
apt-get update
# Upgrade everything already installed. "full-upgrade" (unlike plain upgrade)
# will also add/remove packages when needed to satisfy dependencies.
apt-get full-upgrade -y

# Install the baseline toolset. -y auto-confirms. The trailing backslashes join
# all these lines into ONE command, so no comments can sit between them; here's
# what each package is for:
#   7zip               - 7z archive create/extract
#   apt-transport-https- let apt fetch over HTTPS (older releases needed this)
#   btop               - pretty real-time resource monitor (nicer htop)
#   bzip2              - .bz2 compression
#   curl               - HTTP client for scripts/downloads
#   fio                - flexible disk I/O benchmarking
#   gh                 - GitHub CLI
#   htop               - interactive process viewer
#   jq                 - command-line JSON parser
#   lm-sensors         - read temperature/fan/voltage sensors
#   lshw               - list detailed hardware info
#   lsof               - list open files / which process holds a file or port
#   nala               - friendlier apt front-end (parallel downloads, history)
#   ncdu               - disk usage explorer (find what's eating space)
#   nmap               - network/port scanner
#   pciutils           - lspci and friends (inspect PCI devices)
#   pwgen              - generate random passwords
#   rclone             - sync to/from cloud storage providers
#   restic             - fast encrypted, deduplicated backups
#   ripgrep            - very fast recursive code/text search (rg)
#   scrub              - securely overwrite disks/files
#   smartmontools      - read SMART drive health (smartctl)
#   ugrep              - fast grep with extra features
#   unzip              - extract .zip archives
#   vim                - text editor
#   wget               - alternative downloader
#   zip                - create .zip archives
#   zstd               - fast modern compression (.zst)
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

