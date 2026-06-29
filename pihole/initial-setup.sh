#!/bin/bash
#
# initial-setup.sh — first-time setup of a Pi-hole DNS server running in Docker.
#
# WHAT THIS DOES:
#   Reconfigures the host's DNS so the machine uses the Pi-hole running on it,
#   stops systemd-resolved from grabbing port 53 (which Pi-hole needs), starts
#   the Pi-hole container, installs a NetworkManager hook that keeps Pi-hole's
#   upstream DNS servers in sync, and finally loads the block/allow lists.
#
# HOW TO RUN:
#   Run from inside this pihole/ directory (it references ./setup-lists.sh and
#   the docker-compose file here):  ./initial-setup.sh
#   You will be prompted for sudo where root is required.
#
# PREREQUISITES:
#   - Docker + the docker compose plugin installed.
#   - A docker-compose.yml in this directory that defines the "pihole" service.
#   - NetworkManager managing the network (the dispatcher hook depends on it).
#   - The helper files update-pihole-dns.py, setup-lists.sh, and
#     etc_NetworkManager_dispatcher.d_99-update-pihole-dns present here.
#
# NOTE: this variant points the host's /etc/resolv.conf at 127.0.0.1 (the local
# Pi-hole). The sibling server-pihole-setup.sh points it at 9.9.9.9 instead.

# 'set -e' makes the script abort immediately if any command fails (non-zero
# exit). Without it, a failed step would be ignored and later steps could run
# against a half-configured system.
set -e

# Timestamp string like 2026.06.29-13.45.07, used to make unique backup
# filenames below. The backticks run `date` and capture its output.
ts=`date +%Y.%m.%d-%H.%M.%S`


# Save a copy of the current resolver config before we overwrite it, so we can
# roll back if something goes wrong. The timestamp keeps each backup distinct.
# backup existing resolv.conf content, just in case
sudo cp /etc/resolv.conf /etc/resolv.conf.${ts}

# On most modern distros /etc/resolv.conf is a symlink managed by
# systemd-resolved. Delete the symlink so we can replace it with a plain file
# that we control.
# remove resolv.conf symlink to systemd
sudo rm /etc/resolv.conf
# Point the system at the local Pi-hole (127.0.0.1) for all DNS lookups.
# 'tee' writes stdin to the file; we run it under sudo because the file is
# root-owned, and redirect tee's own stdout to /dev/null to keep the terminal quiet.
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf > /dev/null


# Back up systemd-resolved's own config before editing it.
# back up the systemd resolved.conf
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.${ts}

# Overwrite resolved.conf. The key line is DNSStubListener=no: by default
# systemd-resolved listens on 127.0.0.53:53, which would collide with Pi-hole
# trying to bind port 53. Turning the stub listener off frees the port.
# The <<'EOF' here-doc feeds everything up to the EOF marker into tee's stdin;
# the quotes around 'EOF' mean no variable expansion happens inside the block.
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


# Start the Pi-hole container in the background (-d = detached). This reads the
# docker-compose.yml in the current directory. Older Docker installs use the
# standalone 'docker-compose' command instead of the 'docker compose' plugin.
# or docker-compose up -d
# depending no your system
docker compose up -d

# Install a NetworkManager dispatcher hook. Dispatcher scripts in
# /etc/NetworkManager/dispatcher.d/ run automatically whenever a network
# interface comes up or down. This hook re-runs update-pihole-dns.py so
# Pi-hole's upstream DNS follows whatever DNS the network hands us (e.g. on a
# laptop moving between networks). chmod 755 makes it executable.
sudo cp etc_NetworkManager_dispatcher.d_99-update-pihole-dns /etc/NetworkManager/dispatcher.d/99-update-pihole-dns
sudo chmod 755 /etc/NetworkManager/dispatcher.d/99-update-pihole-dns

# Install the helper script that rewrites Pi-hole's upstream DNS list into
# /usr/local/bin so the dispatcher hook (and you) can call it by name.
sudo chmod 755 update-pihole-dns.py
sudo cp update-pihole-dns.py /usr/local/bin

# Make the block/allow-list loader executable and run it now to populate the
# freshly-started Pi-hole with adlists and rules.
sudo chmod 755 setup-lists.sh
./setup-lists.sh



