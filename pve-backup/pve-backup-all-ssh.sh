#!/bin/bash
#
# pve-backup-all-ssh.sh — pull a backup of EVERY VM on a remote Proxmox host
#                          down to the local machine, over SSH.
#
# WHAT THIS DOES:
#   SSHes into the given Proxmox host, lists all its QEMU VMs, then for each VM
#   runs vzdump on the remote side and streams the resulting backup image back
#   over SSH into a local .vma.zst file. Nothing is stored on the remote host —
#   the backups land in the current local directory.
#
# HOW TO RUN:
#   ./pve-backup-all-ssh.sh <proxmox-host>
#   e.g.  ./pve-backup-all-ssh.sh pve1.home.arpa
#   Backups are written to the directory you run it from, so cd there first.
#
# PREREQUISITES:
#   - Passwordless (key-based) SSH to root@<proxmox-host>, since it opens one
#     SSH session per VM and can't type passwords.
#   - Enough free space locally for all the VM images.

# Run vzdump over ssh to backup all VM guests on a remote proxmox server

# Require the target host as the first argument. -z is true when $1 is empty,
# i.e. no argument was given; in that case print usage and exit with an error.
# Check if PROXMOX_HOST is provided as a command line argument
if [ -z "$1" ]; then
  echo "Error: PROXMOX_HOST not provided."
  echo "Usage: $0 PROXMOX_HOST"
  exit 1
fi

# The hostname/IP of the Proxmox server to back up, and the SSH login user.
# Server details
PROXMOX_HOST=$1
USERNAME="root"

# Temp file to hold the VM list. $$ is this script's process ID, which (with the
# host name) keeps the filename unique so two concurrent runs don't collide.
tmpfile=/tmp/proxmox-backup-all-ssh.sh.${1}.$$.tmp

# Get the list of VMs from the remote host. `qm list` prints a table; awk keeps
# just columns 1 and 2 (VMID and NAME), and `grep -v VMID` drops the header row.
# The \$1/\$2 are escaped so awk (not the local shell) expands them on the
# remote side. The result (one "ID NAME" per line) is saved to the temp file.
# SSH and run 'qm list' to get the list of VMs
ssh ${USERNAME}@${PROXMOX_HOST} "qm list | awk '{print \$1,\$2}' | grep -v VMID" > $tmpfile

# Loop over each VM line we collected.
cat $tmpfile | while read -r LINE; do

  # Split the line into its ID and NAME fields.
  VM_ID=$(echo $LINE | awk '{print $1}')
  VM_NAME=$(echo $LINE | awk '{print $2}')
  echo VM_ID=$VM_ID VM_NAME=$VM_NAME
  # Back up this one VM. On the remote host vzdump runs with:
  #   --mode snapshot   take a live snapshot so the VM keeps running (no downtime)
  #   --compress zstd   compress the stream with Zstandard
  #   --stdout          write the backup to stdout instead of a file on the host
  # We redirect the remote stdout through SSH into a local file. </dev/null
  # detaches the remote command's stdin so it can't accidentally read from / hang
  # on the loop's input. The filename embeds the VMID, name, and a timestamp so
  # each run's files are distinct.
  ssh ${USERNAME}@${PROXMOX_HOST} vzdump $VM_ID --mode snapshot --compress zstd --stdout </dev/null > vzdump-qemu-${VM_ID}-${VM_NAME}_backup.$(date +%Y.%m.%d-%H.%M.%S).vma.zst

done

# Clean up the temp VM-list file.
rm $tmpfile
