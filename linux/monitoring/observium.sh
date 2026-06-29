# observium.sh
#
# WHAT THIS DOES:
#   Two parts:
#     1. Downloads and runs Observium's official installer (Observium is a
#        network monitoring platform that polls devices over SNMP).
#     2. Installs and configures the local SNMP daemon (snmpd) so THIS machine
#        can be monitored: sets its location, makes it listen on all interfaces,
#        and sets a read-only community string.
#
# HOW TO RUN:
#   bash observium.sh   (no shebang on purpose; run it explicitly with bash)
#   Needs sudo and internet access.
#
# PREREQUISITES:
#   - Debian/Ubuntu-based system with apt.
#   - NOTE: "rocommunity public" and "agentaddress 0.0.0.0" expose SNMP read
#     access on every interface with the default community — only safe on a
#     trusted/private network. Lock these down for anything internet-facing.

# Make a working folder for the Observium installer and move into it.
# (Heads up: quoted "~" is NOT expanded by the shell, so this literally creates
#  a folder named "~/observium" in the current directory.)
dir="~/observium"
mkdir $dir && cd $dir

# Download Observium's installer script.
wget http://www.observium.org/observium_installscript.sh
# Make it executable...
chmod +x observium_installscript.sh
# ...and run it as root to install Observium and its dependencies.
sudo ./observium_installscript.sh


# setup snmpd
# Install the SNMP daemon (snmpd, the agent that exposes this host's metrics)
# and the SNMP client tools (snmp).
sudo apt install -y snmpd snmp
# Back up the stock config before editing it, in case we need to revert.
sudo cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.dist
# The "sed -i 's/^old.*/new/'" edits below replace whole config lines in place
# (-i = edit the file directly; ^ anchors to the start of a line).
# Set the device location reported over SNMP.
sudo sed -i 's/^sysLocation .*/sysLocation Houston Office/' /etc/snmp/snmpd.conf
# Listen on all network interfaces (0.0.0.0) instead of just localhost, so the
# Observium server can reach this agent.
sudo sed -i 's/^agentaddress .*/agentaddress 0.0.0.0/' /etc/snmp/snmpd.conf
# Set a read-only community string of "public" allowed from any source
# ("default"). This is the SNMP equivalent of a read-only password.
sudo sed -i 's/^rocommunity .*/rocommunity  public default/' /etc/snmp/snmpd.conf

# Restart snmpd so the configuration changes above take effect.
sudo /etc/init.d/snmpd restart
