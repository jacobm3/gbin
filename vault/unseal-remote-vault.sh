#!/bin/bash
#
# unseal-remote-vault.sh
#
# Auto-unseal a remote Vault: if Vault is sealed (or unreachable), submit a
# stored unseal key to its HTTP unseal endpoint. A sealed Vault can't serve
# secrets, so this keeps it usable after a restart without manual intervention.
#
# Reference for the unseal API call:
# https://www.vaultproject.io/api-docs/system/unseal#submit-unseal-key
#
# Run from cron on a trusted remote machine (checks every minute):
# * * * * * /home/ubuntu/bin/unseal-remote-vault.sh
#
# Prerequisites:
#   - vault CLI and curl installed.
#   - A file bin/.unseal.json (relative to cron's working dir, normally $HOME)
#     containing one unseal key as JSON, e.g. {"key":"<unseal-key>"}.
#     SECURITY NOTE: storing an unseal key on the box weakens Vault's seal
#     protection — only do this on a trusted host you control.

# Which Vault server to talk to (used to build the API URL below).
VAULT_ADDR=https://vault.cosmic-security.net:8200

# `vault status` exits 0 when Vault is up and already unsealed. The `|| \`
# means: ONLY if that check fails (non-zero — sealed or unreachable) do we run
# the curl that submits an unseal key. So a healthy Vault is left untouched.
#   -s            silent (no progress meter).
#   --request POST POST to the unseal endpoint.
#   --data @file  send the file's JSON as the request body (@ = read from file).
#   >/dev/null    discard output; we only care about the side effect.
vault status >/dev/null 2>&1 || \
curl -s --request POST --data @bin/.unseal.json \
  ${VAULT_ADDR}/v1/sys/unseal >/dev/null
