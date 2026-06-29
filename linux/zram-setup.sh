#!/bin/bash
#
# zram-setup.sh — set up a compressed RAM-backed swap device (zram).
#
# WHAT IT DOES: creates a 4 GB swap area that lives in RAM but is transparently
# compressed, so the kernel can swap to it far faster than to disk. Useful on
# boxes with limited RAM or no/slow swap disk. It installs a small helper script
# and a systemd service so the zram swap is recreated automatically on every boot.
#
# HOW TO RUN (needs root for the writes/modprobe; it sudo's each step):
#   ~/gbin/linux/zram-setup.sh
# RISK: low. Adds swap; doesn't touch existing disks or data.

# -e: stop on the first error.  -x: print each command before running it, so you
# can see exactly what happened (handy for a one-off setup script like this).
set -e
set -x

# Path of the helper script we're about to generate.
ZRE=/usr/local/bin/zram-enable.sh
# Write the helper script. `tee` (run under sudo so it can write into
# /usr/local/bin) copies stdin to the file. The heredoc below is its contents:
# it loads the zram kernel module, carves out a 4 GB lzo-compressed zram device,
# formats it as swap, and turns it on at a high priority so it's preferred.
sudo tee $ZRE <<EOF
#!/bin/bash
#
# swap on zram 
sudo modprobe zram
sudo zramctl /dev/zram0 --algorithm lzo --size 4GB
sudo mkswap -U clear /dev/zram0
sudo swapon --priority 10 /dev/zram0
EOF
# Make the helper executable so systemd can run it directly.
sudo chmod +x $ZRE
# (Left disabled on purpose — the service below runs it; uncomment to enable now.)
#bash ${ZRE}


# Write a systemd service so the zram swap is set up automatically at every boot.
# Type=oneshot + RemainAfterExit=yes means "run the command once, then count the
# service as 'active' forever" — correct for a one-time setup step like enabling
# swap. WantedBy=multi-user.target hooks it into normal (non-graphical) boot.
sudo tee /etc/systemd/system/zram.service <<EOF
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zram-enable.sh

[Install]
WantedBy=multi-user.target
EOF
# enable = start automatically on future boots; then start it once right now so
# the zram swap is live without needing a reboot.
sudo systemctl enable zram.service
sudo systemctl start zram

