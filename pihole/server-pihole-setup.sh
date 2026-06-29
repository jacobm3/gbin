#!/bin/bash
#
# server-pihole-setup.sh — first-time setup of a Pi-hole DNS server (server variant).
#
# WHAT THIS DOES:
#   Same idea as initial-setup.sh, but tuned for a fixed server rather than a
#   roaming laptop: it points the host's OWN resolver at a public DNS (Quad9,
#   9.9.9.9) instead of at 127.0.0.1, frees port 53 from systemd-resolved,
#   starts the Pi-hole container, ensures sqlite3 is installed (needed to edit
#   Pi-hole's gravity database), then loads the block/allow lists.
#
# HOW TO RUN:
#   Run from inside this pihole/ directory:  ./server-pihole-setup.sh
#   You will be prompted for sudo where root is required.
#
# PREREQUISITES:
#   - Docker + the docker compose plugin, and a docker-compose.yml here that
#     defines the "pihole" service.
#   - setup-lists.sh present in this directory.
#   - apt-based distro (used to install sqlite3 if missing).
#
# WHY 9.9.9.9 here vs 127.0.0.1 in initial-setup.sh: on a dedicated server we
# want the host to keep resolving names even if the Pi-hole container is down,
# so its system resolver uses an external DNS directly. Pi-hole's own clients
# still go through Pi-hole.

# Abort on the first failing command so we never continue from a broken state.
# stop on errors
set -e

# Timestamp like 2026.06.29-13.45.07 for unique backup filenames.
ts=`date +%Y.%m.%d-%H.%M.%S`


# Keep a copy of the current resolver config so we can restore it if needed.
# backup existing resolv.conf content, just in case
sudo cp /etc/resolv.conf /etc/resolv.conf.${ts}

# /etc/resolv.conf is normally a systemd-managed symlink. Remove it so we can
# write our own plain file.
# remove resolv.conf symlink to systemd
sudo rm /etc/resolv.conf
# Point the host's system resolver at Quad9 (9.9.9.9). 'tee' under sudo writes
# the root-owned file; its stdout goes to /dev/null to stay quiet.
echo "nameserver 9.9.9.9" | sudo tee /etc/resolv.conf > /dev/null


# Back up systemd-resolved's config before rewriting it.
# back up the systemd resolved.conf
sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.${ts}

# Rewrite resolved.conf. DNSStubListener=no is the important part: it stops
# systemd-resolved from holding port 53, which Pi-hole needs. FallbackDNS=9.9.9.9
# gives resolved a backstop upstream. The quoted <<'EOF' here-doc passes the
# block verbatim (no variable expansion) into tee's stdin.
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


# Start the Pi-hole container detached (-d). Reads docker-compose.yml in this
# directory. Older systems use the hyphenated 'docker-compose' command instead.
# or docker-compose up -d
# depending no your system
docker compose up -d

# setup-lists.sh edits Pi-hole's gravity.db directly with the sqlite3 CLI, so
# make sure that tool is present. 'command -v sqlite3' succeeds only if it's on
# PATH; '>/dev/null 2>&1' hides its output, and the leading '!' inverts the test
# so the 'then' branch runs only when sqlite3 is MISSING.
# Check if sqlite3 is installed
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 not found. Installing..."
    # Refresh apt's package index so the install can find the package.
    # Refresh package index if needed
    sudo apt-get update -y
    # Install sqlite3 non-interactively (-y auto-answers yes to prompts).
    # Install the package
    sudo apt-get install -y sqlite3
    echo "sqlite3 installed successfully."
else
    # Already present — just report the version.
    echo "sqlite3 is already installed (version: $(sqlite3 --version))."
fi

# Populate Pi-hole with the block/allow lists (waits for the container to be
# healthy first, see setup-lists.sh).
./setup-lists.sh


