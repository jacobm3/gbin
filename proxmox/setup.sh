#!/bin/bash -x
#
# setup.sh — install the Meliox "PVE-mods" UI/sensor tweaks on a Proxmox node.
#
# WHAT THIS DOES:
#   Installs the 'nala' apt front-end, upgrades the system, then clones and runs
#   the third-party PVE-mods project, which patches the Proxmox web UI to show
#   extra info (CPU temperatures, etc.). After it runs you must log out of the
#   web UI and clear the browser cache to see the changes.
#
# HOW TO RUN (as root, on the node):  ./setup.sh
#
# NOTES:
#   - Shebang "-x" prints each command as it runs (debug/trace); behavior is
#     unchanged.
#   - This pulls and executes code from an external GitHub repo; review it if
#     you care about supply-chain trust.

# Abort immediately if any command fails, so we don't run later steps on top of
# a broken earlier step.
set -e

# Create and move into a scratch directory for source checkouts.
mkdir ~/src
cd ~/src
# Refresh the apt package index.
apt-get update
# Install nala, a friendlier front-end to apt with nicer output.
apt install nala 

# Upgrade all installed packages using nala.
nala upgrade

# Install git so we can clone the mods repo.
nala install git
# Clone the third-party PVE-mods project.
git clone https://github.com/Meliox/PVE-mods.git
cd PVE-mods
# Run the installer that applies all available mods to the Proxmox UI.
./pve-mod-all.sh

# Remind the operator that a browser logout + cache clear is needed for the UI
# changes to appear.
echo Log out of proxmox and clear your cache.
