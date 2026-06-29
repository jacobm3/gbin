#!/bin/bash -x
#
# pve-init.sh — first-boot bootstrap for a fresh Proxmox VE (PVE) node.
#
# WHAT THIS DOES:
#   Brings a brand-new Proxmox install up to a personal baseline: installs the
#   owner's SSH key, enables ZFS compression, switches apt to the free
#   "no-subscription" repo and fully upgrades, installs handy CLI tools and
#   SNMP monitoring, clones this gbin dotfiles repo, adds an internal-only
#   bridge (vmbr1), and suppresses the "No valid subscription" nag popup.
#
# HOW TO RUN (as root, on the new node):
#   curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/proxmox/pve-init.sh | bash
#   (The line below is that same command, kept for copy/paste.)
# curl -sSL https://raw.githubusercontent.com/jacobm3/gbin/main/proxmox/pve-init.sh | bash
#
# NOTES:
#   - The shebang's "-x" flag makes bash print each command before running it,
#     so you can watch progress / debug. It does NOT change behavior.
#   - Run as root (it writes to /etc, restarts services, edits ZFS). It assumes
#     a default Proxmox install on Debian "bookworm" using a ZFS root pool
#     named "rpool".

# Ensure the SSH config dir exists (-p = don't error if it already does).
mkdir -p ~/.ssh
# Write (overwrite) authorized_keys with the owner's public key so key-based SSH
# logins work. The <<EOF here-doc supplies the file contents up to the EOF line.
# NOTE: '>' replaces the file; any keys already there are discarded.
cat > ~/.ssh/authorized_keys <<EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID10aN8gGb0s+3LTE43VNFmvQxz5WYL+JlMCVzmZl+f7 jacob.martinson.ed25519.2022.09
EOF

# Turn on fast Zstandard compression for the ZFS root pool. zstd-fast trades a
# little compression ratio for speed; it saves disk with negligible CPU cost
# and applies to newly written data.
zfs set compression=zstd-fast rpool

# Proxmox ships an "enterprise" apt repo that needs a paid subscription and
# fails to update without one. Remove all the default repo files...
rm /etc/apt/sources.list.d/*
# ...and add the free "pve-no-subscription" repo so apt can fetch PVE updates.
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list

# Tell apt/dpkg not to ask interactive questions (e.g. config-file prompts);
# they'd hang a non-interactive run. This env var lasts for the rest of the script.
export DEBIAN_FRONTEND=noninteractive
# Refresh the package index from the repos configured above.
apt-get update
# Upgrade installed packages. 'upgrade' updates packages in place; 'dist-upgrade'
# additionally handles changed dependencies and can add/remove packages as
# needed. -y auto-confirms. Both are run to fully bring the system up to date.
apt-get upgrade -y
apt-get dist-upgrade -y
# Install the owner's preferred CLI toolkit (archives, monitors, network tools,
# editors, NVMe/sensor utilities, sudo, etc.) in one shot.
apt install -y 7zip btop git htop hwinfo lm-sensors net-tools netdiscover nmap nvme-cli sudo sysstat vim zip unzip 

# Install SNMP daemon + tools so the node can be polled by network monitoring.
# setup snmpd
apt install -y snmpd snmp
# Keep a pristine copy of the stock config before we edit it.
cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.dist
# The three sed commands edit snmpd.conf in place (-i). 's/^X .*/Y/' means
# "on lines starting with X, replace the whole line with Y":
#   1) set the device's reported location to "<hostname> Houston Office"
sed -i "s/^sysLocation .*/sysLocation $HOSTNAME Houston Office/" /etc/snmp/snmpd.conf
#   2) listen on all interfaces (0.0.0.0) instead of just localhost
sed -i 's/^agentaddress .*/agentaddress 0.0.0.0/' /etc/snmp/snmpd.conf
#   3) allow read-only SNMP access with community string "public" from anywhere
sed -i 's/^rocommunity .*/rocommunity  public default/' /etc/snmp/snmpd.conf
# Restart snmpd so the new config takes effect.
/etc/init.d/snmpd restart
# Quick test you can run by hand to confirm SNMP works:
# snmpwalk -v 2c -c public localhost

# Clone the personal dotfiles/scripts repo and wire it into the shell:
#   - clone gbin into the home dir
#   - source ~/gbin/jacobrc from both .bashrc (interactive shells) and
#     .bash_profile (login shells) so the aliases/functions load every session
#   - add a ~/.jacobrc symlink pointing at the repo copy
# The && chain stops if the clone fails so we don't append config for a missing repo.
git clone https://github.com/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc
# Install the preferred htop layout/colors from the repo.
mkdir -p ~/.config/htop
cp ~/gbin/.config/htop/htoprc ~/.config/htop/htoprc

# Append a second network bridge (vmbr1) to the interfaces config. '>>' adds to
# the file without disturbing the existing vmbr0. This bridge has no physical
# port (bridge-ports none), so it's an internal-only virtual switch: VMs/CTs
# attached to it can talk to each other and to the host at 10.0.1.254, but not
# directly to the LAN. STP off and forward-delay 0 make the bridge come up
# instantly (fine for a simple host-internal bridge).
cat >> /etc/network/interfaces <<EOF

auto vmbr1
iface vmbr1 inet static
        address 10.0.1.254/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

EOF

# Patch out the "No valid subscription" warning popup in the Proxmox web UI.
# This sed edits the JS that draws the dialog so it never shows. Flags:
#   -E  extended regex,  -z  treat the file as one big NUL-delimited string so
#   the multi-line pattern can match,  -i.bak  edit in place but save a .bak
#   backup first. The replacement turns the Ext.Msg.show({...}) call into a
#   no-op void({ //... }). Purely cosmetic; it does not bypass licensing.
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 
# Restart the web UI service so the patched JS is served.
systemctl restart pveproxy.service

# Reminder (not executed): to set up outbound email on this node, copy the
# Postfix config from an already-working node and fix the hostname references:
# from working pve node:
# cd /etc/postfix && scp main.cf sasl_passwd* smtp_header_checks* NEWIP:/etc/postfix
# update hostname in /etc/postfix/main.cf and smtp_header_checks

# Enable tab-completion for ZFS commands (zfs/zpool) in future interactive
# shells by sourcing the completion script from .bashrc.
echo '. /usr/share/bash-completion/completions/zfs' >> ~/.bashrc
