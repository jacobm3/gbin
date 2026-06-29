#!/bin/bash
#
# install-vault-debian.sh
#
# Install HashiCorp Vault on Debian/Ubuntu by adding HashiCorp's official APT
# repository (with its signing key) and then apt-installing the `vault` package.
# This mirrors HashiCorp's documented install steps.
#
# Usage:   ./install-vault-debian.sh
# Prerequisites: Debian/Ubuntu with apt, and a user that has sudo. Run as a
# normal user — the script calls sudo itself where root is needed.

# Refresh the package index, then install the two tools the steps below need:
# gpg (to handle the repo signing key) and wget (to download it).
sudo apt update && sudo apt install gpg wget
# Download HashiCorp's GPG public key and convert it from ASCII-armored text to
# binary "keyring" form (gpg --dearmor), saving it where apt looks for repo keys.
#   wget -O-  writes the downloaded key to stdout so it can be piped.
#   -o <file> tells gpg where to write the dearmored key.
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# Print the key's fingerprint so you can eyeball that it matches HashiCorp's
# published fingerprint before trusting it.
#   --no-default-keyring + --keyring  inspect only the keyring we just created.
gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint
# Write the APT source line for HashiCorp's repo into its own .list file.
#   arch=$(dpkg --print-architecture)  pins to this machine's arch (amd64/arm64).
#   signed-by=...keyring.gpg           requires packages be signed by the key above.
#   $(lsb_release -cs)                 inserts this distro's codename (e.g. bookworm).
#   sudo tee <file>                    writes the line to a root-owned file.
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# Re-read the package index (now including HashiCorp's repo) and install vault.
sudo apt update && sudo apt install vault
