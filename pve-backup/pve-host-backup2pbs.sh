#!/bin/bash
#
# pve-host-backup2pbs.sh — back up the Proxmox HOST's own filesystem to a
#                           Proxmox Backup Server (PBS).
#
# WHAT THIS DOES:
#   Uses proxmox-backup-client to send a file-level backup of the host's root
#   filesystem and its /etc/pve config to a remote PBS datastore, into a
#   namespace named for this node. This protects the hypervisor host itself
#   (not the guest VMs — those are handled separately).
#
# HOW TO RUN:
#   Intended to run unattended (e.g. from cron) on the Proxmox node.
#   Output is appended to the log file set below. Run as root so it can read
#   everything under / and /etc/pve.
#
# PREREQUISITES:
#   - proxmox-backup-client installed.
#   - A reachable PBS server and a valid API token.
#   - FILL IN the placeholders below: PBS_PASSWORD (the token secret),
#     PBS_REPOSITORY (user@realm!token@HOST:datastore), and the matching
#     PBS_FINGERPRINT for the server's TLS cert.

# What to back up. Format is "archive-name.pxar:/path". Two archives:
#   root.pxar = the whole host root filesystem (/)
#   pve.pxar  = the Proxmox cluster/node config (/etc/pve)
VOLUMES="root.pxar:/ pve.pxar:/etc/pve"
# Namespace inside the PBS datastore to store this node's snapshots under, so
# multiple hosts can share one datastore without colliding.
NS="pve3"
# Where to append run output/errors.
LOG=/usr/local/sbin/backup.log

# Credentials/target are passed to proxmox-backup-client via environment vars
# instead of command-line flags (keeps the token out of the process list).
#   PBS_PASSWORD    = the API token secret (REPLACE "your-token").
#   PBS_REPOSITORY  = which PBS to talk to: user@realm!tokenname@HOST:datastore.
#   PBS_FINGERPRINT = expected SHA-256 fingerprint of the PBS TLS certificate,
#                     so the client can verify the server without a trusted CA.
export PBS_PASSWORD=your-token
export PBS_REPOSITORY='backup@pbs!client@PBS_IP:datastore-pool-a'
export PBS_FINGERPRINT=9c:ef:29:b8:64:3b:3f:0f:8f:d0:3f:c5:a7:c5:0b:a3:6c:46:59:fa:8a:25:7b:23:1c:0a:c9:d4:b9:ea:88:5b


# Run the backup. $VOLUMES expands to the two archive specs; --ns sets the
# namespace. ">>$LOG 2>&1" appends both normal output and errors to the log.
/usr/bin/proxmox-backup-client backup $VOLUMES --ns $NS >>$LOG 2>&1
# Exit with the backup command's own exit code so cron/monitoring can tell
# whether the backup succeeded ($? is the last command's status).
exit $?
