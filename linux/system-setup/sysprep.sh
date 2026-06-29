#!/bin/bash
#
# sysprep.sh — prepare a VM to become a reusable template / "golden image".
#
# WHY: every Linux install has a unique machine-id. If you clone a VM without
# clearing it, every clone shares the same id, which breaks things that key off
# it (DHCP leases handing out the same IP, systemd journald, etc.). This blanks
# the machine-id so the NEXT boot generates a fresh, unique one, then powers off
# so you can snapshot/clone the VM cleanly.
#
# HOW TO RUN (needs root):  sudo ~/gbin/linux/system-setup/sysprep.sh
#
# RISK: HIGH-IMPACT — this SHUTS THE MACHINE DOWN at the end. Run it ONLY on the
# template VM you're about to clone, never on a box you need to stay up.

# Empty the machine-id file. `echo -n` writes nothing (no newline); `>` truncates
# the file to zero bytes. systemd regenerates it on the next boot.
echo -n > /etc/machine-id
# D-Bus keeps its own copy; remove it...
rm /var/lib/dbus/machine-id
# ...and point it at the systemd one via a symlink, so both stay in sync and the
# single regenerated id is used everywhere.
ln -s /etc/machine-id /var/lib/dbus/machine-id
# Power off now so the VM can be cloned in this clean state.
shutdown -h now
