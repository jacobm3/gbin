# sudo-commands.sh — shell aliases that auto-prepend sudo to Proxmox CLI tools.
#
# WHAT THIS DOES:
#   Defines aliases so that common Proxmox admin commands run via sudo without
#   you typing "sudo" each time. This lets a non-root user drive Proxmox from
#   the shell while the actual privileged work still happens as root.
#
# HOW TO USE:
#   This file is meant to be SOURCED, not executed, so the aliases land in your
#   current shell. Add a line like  ". ~/gbin/proxmox/sudo-commands.sh"  to your
#   ~/.bashrc (or source it manually). There is intentionally no shebang.
#
# PREREQUISITES:
#   - You're on a Proxmox VE node where these commands exist.
#   - Your user has sudo rights for them (passwordless sudo makes it seamless).
#
# An alias just rewrites the typed word: typing `qm ...` actually runs
# `sudo qm ...`. Aliases only apply to interactive shells that have sourced this.

# Proxmox VM / CT management
# qm  = manage QEMU/KVM virtual machines;  pct = manage LXC containers.
alias qm='sudo qm'
alias pct='sudo pct'

# Proxmox storage / API / node management
# pvesm = storage manager;  pvesh = walk/call the Proxmox REST API from the CLI;
# pvenode = node-level operations.
alias pvesm='sudo pvesm'
alias pvesh='sudo pvesh'
alias pvenode='sudo pvenode'

# Backups / restores
# vzdump = create VM/CT backups;  qmrestore = restore a VM from a vzdump archive.
alias vzdump='sudo vzdump'
alias qmrestore='sudo qmrestore'

# User / permission management
# pveum = manage Proxmox users, groups, roles, and ACLs.
alias pveum='sudo pveum'

# Cluster management, useful even on a single-node box for status/info
# pvecm = cluster manager (also shows node/quorum status on a single node).
alias pvecm='sudo pvecm'

# Firewall
# pve-firewall = control/inspect the Proxmox firewall.
alias pve-firewall='sudo pve-firewall'

# HA, only useful if you use HA/clustering
# ha-manager = manage High-Availability resources (only relevant in a cluster).
alias ha-manager='sudo ha-manager'
