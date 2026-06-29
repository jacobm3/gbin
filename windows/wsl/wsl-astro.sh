#!/bin/bash -x
# The "-x" in the shebang above makes bash PRINT each command before running it,
# so you can watch progress and see exactly where things fail. Keep it for setup
# scripts like this one.

# ============================================================================
# wsl-astro.sh — provision a fresh Ubuntu 22 WSL for Astro/VS Code/Docker dev
# ============================================================================
#
# WHAT THIS DOES
#   One-shot bootstrap for an Astronomer (Apache Airflow) development box running
#   inside WSL2. It enables passwordless sudo, installs common devops tools and
#   the HashiCorp packages (terraform/vault), replaces any Ubuntu docker with
#   the official Docker CE, and installs the Astronomer CLI.
#
# HOW TO RUN (inside the WSL Ubuntu shell, as a normal sudo-capable user):
#   bash ~/gbin/windows/wsl/wsl-astro.sh
#   Then REBOOT WSL (see the loud reminder at the end) so the iptables-legacy
#   switch takes effect and Docker networking works.
#
# PREREQUISITES: a fresh Ubuntu 22.04 WSL2 distro, internet access, and a user
#   in the "sudo" group. Run once on a new machine.
#
# Note: this enables passwordless sudo and pulls install scripts over the
#   network — fine for a throwaway dev VM, not for a hardened host.
# ============================================================================

# This script is intended to run in a fresh Ubuntu 22 WSL environment
# and add the necessary packages to have a nice Astro/VS Code/Docker-CE
# development experience.

# Allow passwordless sudo
# Append a sudoers rule so anyone in the "sudo" group can run sudo without
# being prompted for a password. "tee -a" appends as root. (Convenient for an
# unattended script; weakens security on a real machine.)
echo '%sudo  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

# Tell the package installer not to ask questions because this is a script
# DEBIAN_FRONTEND=noninteractive stops apt from popping up config dialogs that
# would hang an unattended run.
export DEBIAN_FRONTEND=noninteractive

# Add standard devops packages
# Add HashiCorp's APT signing key so apt trusts their repo. (apt-key is the old
# way to do this; it's deprecated on newer Ubuntu but still works on 22.)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
# Add the HashiCorp APT repository. $(dpkg --print-architecture) fills in the
# CPU arch (e.g. amd64) and $(lsb_release -cs) the Ubuntu codename (e.g. jammy).
sudo apt-add-repository -y "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
# Refresh the package lists so the new repo is known.
sudo apt-get update
# Install the everyday CLI/devops tools plus terraform and vault. "-y" answers
# yes to prompts automatically.
sudo apt-get install -y nmap bzip2 netcat net-tools git htop sysstat iotop vim-nox python3-pip jq lm-sensors terraform vault zstd


# Remove Ubuntu docker pkgs, Install Docker CE
# Ubuntu ships its own older docker packages. Remove them first so they don't
# conflict with the official Docker CE we install next.
sudo apt-get remove -y docker docker-engine docker.io containerd runc
# Prerequisites for adding the Docker repo over HTTPS with a signing key.
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
# Folder Docker's signing key will live in.
sudo mkdir -p /etc/apt/keyrings
# Download Docker's signing key and convert it ("--dearmor") to the binary
# format apt expects, saving it into the keyrings folder.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# Write the Docker APT repo definition, pinned to that signing key, into
# sources.list.d. "> /dev/null" just hides tee's echo of the line.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Refresh package lists now that Docker's repo is added.
sudo apt-get update
# Install the Docker engine, CLI, containerd runtime, and compose plugin.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
# WSL2's kernel works better with the older "legacy" iptables backend; point
# iptables/ip6tables at it so Docker's networking rules apply correctly.
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
# Add your user to the "docker" group so you can run docker without sudo.
# Takes effect on next login/reboot.
sudo usermod -G docker -a $USER

# Install Astronomer CLI
# Pipe Astronomer's official install script straight into bash to install the
# "astro" command. "-s" passes args (none here) through to the script.
curl -sSL install.astronomer.io | sudo bash -s

# Print a loud reminder. The iptables-legacy switch only takes effect after a
# restart of the WSL distro, so Docker networking won't work until you reboot.
echo '#'
echo '#'
echo '#'
echo '# YOU MUST REBOOT FOR THE DOCKER-CE IPTABLES CHANGE TO TAKE EFFECT!!!'
echo '#'
echo '#'
echo '# sudo reboot'
echo '#'

