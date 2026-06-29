#!/bin/bash
#
# auditd.sh
#
# WHAT THIS DOES:
#   Installs and enables the Linux audit daemon (auditd), then loads a
#   well-known, ATT&CK-mapped ruleset (Florian Roth's) so the system logs
#   security-relevant events (file access, command execution, etc.) to
#   /var/log/audit/audit.log.
#
# HOW TO RUN:
#   ./auditd.sh
#   Needs sudo and internet access (downloads the rules from GitHub).
#
# PREREQUISITES:
#   - Debian/Ubuntu-based system (uses apt and systemd).
#   - WARNING: this OVERWRITES /etc/audit/rules.d/audit.rules with the
#     downloaded ruleset. Back up any custom rules first.

# Install the audit daemon plus the dispatcher plugins (audispd-plugins lets
# auditd forward events to other tools/log shippers). "-y" auto-confirms.
sudo apt install auditd audispd-plugins -y
# "enable" makes auditd start automatically on every boot; "--now" also starts
# it immediately in this session.
sudo systemctl enable --now auditd
# Show auditd's current status so you can confirm it's active/running.
sudo systemctl status auditd
# Confirm the audit log file exists and check its permissions/size.
ls -la /var/log/audit/audit.log

# grab Florian Roth's ATT&CK-mapped rules (popular starting point)
# Download the ruleset and save it as the active rules file. auditd reads every
# *.rules file under /etc/audit/rules.d/. NOTE: "-o" overwrites the existing file.
sudo curl -o /etc/audit/rules.d/audit.rules \
  https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules

# augenrules merges all the *.rules files in rules.d into one and loads them
# into the running kernel audit subsystem.
sudo augenrules --load   # compile and load all rules.d files
# List the rules now active in the kernel to confirm they loaded successfully.
sudo auditctl -l         # confirm rules loaded
