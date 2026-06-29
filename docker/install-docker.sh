#!/bin/bash

# ---------------------------------------------------------------------------
# install-docker.sh
#
# What it does:
#   Installs Docker Engine using Docker's official convenience script, after
#   first removing older/distro packages that could conflict. Then it adds the
#   real human user to the "docker" group so they can run docker without sudo.
#
# How to run:
#   ./install-docker.sh
#   (No arguments. Run it from a normal interactive login, not as root,
#    because it uses `logname` to detect who you are.)
#
# Prerequisites:
#   - A Debian/Ubuntu-based system (uses apt).
#   - Passwordless or interactive sudo (the script calls sudo several times).
#   - Internet access to download get.docker.com.
#
# Note: log out and back in afterward so the new docker group membership
# takes effect.
# ---------------------------------------------------------------------------

# Remove older or conflicting packages first. Docker's docs recommend this
# because distro packages (docker.io, podman-docker, the old containerd/runc,
# etc.) can clash with the official Docker Engine we are about to install.
sudo apt remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
# Download Docker's official install script to a local file.
#   -f : fail silently on HTTP errors (don't save an error page as the script)
#   -s : silent (no progress bar)
#   -S : but still show errors if something goes wrong
#   -L : follow redirects
#   -o get-docker.sh : save the download to this filename.
curl -fsSL https://get.docker.com -o get-docker.sh
# Run the downloaded script with root privileges to actually install Docker.
sudo sh ./get-docker.sh 
# Clean up: we no longer need the installer script after it has run.
rm get-docker.sh

# Get the currently logged-in user (interactive session user)
# `logname` returns the name you originally logged in as, even when called via
# sudo (whereas $USER might say "root"). We want the real human, not root.
USER_TO_ADD=$(logname)

# Check if the group "docker" exists
# `getent group docker` looks up the docker group in the system's group
# database and prints it if found. > /dev/null hides that output; the leading
# ! makes the `if` true only when the group does NOT exist.
if ! getent group docker > /dev/null; then
    echo "The group 'docker' does not exist. Creating it..."
    # Create the group so we have something to add the user to.
    sudo groupadd docker
fi

# Add the user to the docker group
echo "Adding user '$USER_TO_ADD' to the 'docker' group..."
# usermod modifies a user account.
#   -a : append (add to existing groups; without -a it would REPLACE them)
#   -G docker : the supplementary group to add. Membership lets the user talk
#               to the docker daemon socket, so `docker` works without sudo.
sudo usermod -aG docker "$USER_TO_ADD"

# Notify the user to log out and back in
echo "User '$USER_TO_ADD' has been added to the 'docker' group."
echo "You may need to log out and log back in for the changes to take effect."
