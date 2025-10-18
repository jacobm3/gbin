#!/bin/bash

sudo apt remove docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh 
rm get-docker.sh

# Get the currently logged-in user (interactive session user)
USER_TO_ADD=$(logname)

# Check if the group "docker" exists
if ! getent group docker > /dev/null; then
    echo "The group 'docker' does not exist. Creating it..."
    sudo groupadd docker
fi

# Add the user to the docker group
echo "Adding user '$USER_TO_ADD' to the 'docker' group..."
sudo usermod -aG docker "$USER_TO_ADD"

# Notify the user to log out and back in
echo "User '$USER_TO_ADD' has been added to the 'docker' group."
echo "You may need to log out and log back in for the changes to take effect."
