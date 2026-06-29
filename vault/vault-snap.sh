#!/bin/bash
#
# vault-snap.sh
#
# Take a point-in-time snapshot of Vault's integrated (Raft) storage backend and
# save it to a timestamped file in the current directory. Use these snapshots to
# restore Vault after data loss.
#
# Usage:   ./vault-snap.sh
# Prerequisites:
#   - vault CLI and jq installed.
#   - VAULT_ADDR set to the Vault server, and you are authenticated with a token
#     that has rights to read raft snapshots (snapshots are an admin operation).
#   - Vault must be using the "raft" storage backend.

# Extract just the hostname from VAULT_ADDR (e.g. https://vault.example:8200 ->
# vault.example) to use in the snapshot filename.
#   cut -f3 -d/  splits on "/" and takes field 3 -> "vault.example:8200".
#   cut -f1 -d:  splits that on ":" and takes field 1 -> "vault.example".
vhost=$(echo $VAULT_ADDR | cut -f3 -d/ | cut -f1 -d:)
# Ask Vault its version as JSON and pull out the .version field with jq (-r =
# raw, no surrounding quotes). Goes into the filename so you know which Vault
# build produced the snapshot.
version=$(vault status -format=json | jq -r .version)
# Build a sortable timestamp: date + time + trailing Unix epoch seconds (%s),
# guaranteeing each snapshot filename is unique.
ts=$(date +%Y.%m.%d_%H:%M:%S_%s)
# Save the Raft snapshot to a file named with the host, version, and timestamp.
vault operator raft snapshot save raft_${vhost}_v${version}_${ts}.snap
