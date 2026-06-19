#!/bin/bash
#

sudo apt install auditd audispd-plugins -y
sudo systemctl enable --now auditd
sudo systemctl status auditd
ls -la /var/log/audit/audit.log

# grab Florian Roth's ATT&CK-mapped rules (popular starting point)
sudo curl -o /etc/audit/rules.d/audit.rules \
  https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules

sudo augenrules --load   # compile and load all rules.d files
sudo auditctl -l         # confirm rules loaded
